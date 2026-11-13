import Foundation

enum ChordTerminalOutcome: Equatable {
  case composerReplay, literalFallback, repeatSuppression, safetyFlush
}

struct ChordTermination: Equatable {
  let strokeID: UInt64
  let outcome: ChordTerminalOutcome
  let reason: ChordFlushReason
}

/// All entry points run serially on the main run loop, including the passive source callbacks.
final class ChordInputCoordinator {
  private static weak var activeCoordinator: ChordInputCoordinator?
  private let source: PhysicalKeyEventSourceProtocol
  private let clock: () -> TimeInterval
  private let isEnabled: () -> Bool
  private let acceptsRelease: (Int) -> Bool
  private let replay: (ChordStroke) -> ChordTerminalOutcome
  private let onDisabled: (ChordFlushReason) -> Void
  private let watchdog: TimeInterval
  private let orphanLifetime: TimeInterval
  private let maxOrphans: Int
  private let maxStrokes: Int
  private var observer: UUID?
  private let leaseToken = UUID()
  private var hasLease = false
  private var ignoredReleaseKeys: Set<Int> = []
  private var engine = ChordGroupingEngine()
  private var orphans: [(keyCode: Int, timestamp: TimeInterval, arrivedAt: TimeInterval)] = []
  private var outstanding: Set<UInt64> = []
  private var groupStartedAt: TimeInterval?
  private var lastCompletedAt: TimeInterval?
  private var lastKeyDownAt: TimeInterval?
  private var replayGroups: [StrokeGroup] = []
  private var isReplaying = false
  private(set) var isActive = false
  private(set) var disabledReason: ChordFlushReason?
  private(set) var endedReason: ChordFlushReason?
  private(set) var consumedStrokeCount: UInt64 = 0
  private(set) var terminalCount: UInt64 = 0
  private(set) var expiredOrphanCount: UInt64 = 0
  private(set) var recentTerminations: [ChordTermination] = []

  var bufferedStrokeCount: Int { engine.strokes.count }
  var outstandingStrokeCount: Int { outstanding.count }

  init(
    source: PhysicalKeyEventSourceProtocol, clock: @escaping () -> TimeInterval,
    isEnabled: @escaping () -> Bool, acceptsRelease: @escaping (Int) -> Bool = { _ in true },
    watchdog: TimeInterval = 2,
    orphanLifetime: TimeInterval = 0.25, maxOrphans: Int = 32, maxStrokes: Int = 64,
    onDisabled: @escaping (ChordFlushReason) -> Void = { _ in },
    replay: @escaping (ChordStroke) -> ChordTerminalOutcome
  ) {
    self.source = source
    self.clock = clock
    self.isEnabled = isEnabled
    self.acceptsRelease = acceptsRelease
    self.watchdog = watchdog
    self.orphanLifetime = orphanLifetime
    self.maxOrphans = maxOrphans
    self.maxStrokes = maxStrokes
    self.onDisabled = onDisabled
    self.replay = replay
    observer = source.addObserver { [weak self] event in self?.receive(event) }
  }

  deinit {
    let source = source
    let token = leaseToken
    let observer = observer
    let leased = hasLease
    let cleanup = {
      if let observer = observer { source.removeObserver(observer) }
      if leased { source.releaseLease(token) }
    }
    if Thread.isMainThread { cleanup() } else { DispatchQueue.main.async(execute: cleanup) }
  }

  func activate() {
    precondition(Thread.isMainThread)
    if isActive { endSession(.clientChanged) }
    if let previous = Self.activeCoordinator, previous !== self {
      previous.endSession(.clientChanged)
    }
    Self.activeCoordinator = self
    isActive = true
    disabledReason = nil
    endedReason = nil
    orphans.removeAll()
    ignoredReleaseKeys.removeAll()
    lastCompletedAt = nil
    lastKeyDownAt = nil
    if isEnabled() {
      hasLease = true
      source.acquireLease(leaseToken)
      _ = safetyCheck()
    } else {
      endSession(.modeDisabled)
    }
  }

  func deactivate() { endSession(.deactivated) }

  func endSession(_ reason: ChordFlushReason) {
    precondition(Thread.isMainThread)
    isActive = false
    endedReason = reason
    if Self.activeCoordinator === self { Self.activeCoordinator = nil }
    releaseLease()
    flushBoundary(reason)
    if !isActive { ignoredReleaseKeys.removeAll() }
  }

  private func releaseLease() {
    guard hasLease else { return }
    hasLease = false
    source.releaseLease(leaseToken)
  }

  /// Called only for an eligible IMK key-down, before any receiver/composer call.
  @discardableResult func consume(
    keyCode: Int, text: String, modifiers: UInt, timestamp: TimeInterval, isRepeat: Bool
  ) -> Bool {
    precondition(Thread.isMainThread)
    guard safetyCheck() else { return false }
    discardExpiredOrphans(now: clock())
    guard timestamp.isFinite, timestamp >= 0 else {
      disableSession(.timestampMismatch)
      return false
    }
    guard !text.isEmpty else {
      flushBoundary(.nonMappable)
      return false
    }
    if isRepeat, engine.heldTimestamp(for: keyCode) == nil {
      if ignoredReleaseKeys.contains(keyCode) { return false }
      disableSession(.unmatchedEvent)
      return false
    }
    consumedStrokeCount += 1
    let stroke = ChordStroke(
      id: consumedStrokeCount, keyCode: keyCode, text: text,
      modifiers: modifiers, timestamp: timestamp)
    outstanding.insert(stroke.id)
    if isRepeat {
      terminate(stroke.id, outcome: .repeatSuppression, reason: .allReleased)
      return true
    }
    if engine.isEmpty { groupStartedAt = clock() }
    let result = engine.press(stroke)
    if result == .duplicateWhileHeld {
      disableSession(.unmatchedEvent)
    } else if engine.strokes.count > maxStrokes {
      disableSession(.groupOverflow)
    } else if timestamp < (lastKeyDownAt ?? timestamp) || timestamp < (lastCompletedAt ?? timestamp)
    {
      disableSession(.timestampMismatch)
    } else {
      lastKeyDownAt = timestamp
      if let index = orphans.firstIndex(where: {
        $0.keyCode == keyCode && $0.timestamp >= timestamp
      }) {
        let release = orphans.remove(at: index)
        if let group = engine.release(keyCode: keyCode, timestamp: release.timestamp) {
          finish(group)
        }
      }
    }
    return true
  }

  func receive(_ event: PhysicalKeySourceEvent) {
    precondition(Thread.isMainThread)
    guard isActive, disabledReason == nil else { return }
    switch event {
    case .statusChanged(let status):
      switch status {
      case .healthy: break
      case .permissionDenied: disableSession(.permissionLost)
      case .secureInput: disableSession(.secureInput)
      case .stopped: endSession(.modeDisabled)
      case .tapDisabled, .unavailable: disableSession(.tapDisabled)
      }
    case .heartbeat(let timestamp): checkTimeout(now: timestamp)
    case .keyUp(let keyCode, let timestamp):
      guard acceptsRelease(keyCode) else { return }
      guard safetyCheck() else { return }
      discardExpiredOrphans(now: clock())
      guard timestamp.isFinite, timestamp >= 0 else {
        disableSession(.timestampMismatch)
        return
      }
      if ignoredReleaseKeys.remove(keyCode) != nil {
        if let downAt = engine.heldTimestamp(for: keyCode), timestamp >= downAt {
          // A newer captured press owns this release; the boundary's old press is already terminal.
        } else {
          return
        }
      }
      if let downAt = engine.heldTimestamp(for: keyCode) {
        guard timestamp >= downAt else {
          disableSession(.timestampMismatch)
          return
        }
        if let group = engine.release(keyCode: keyCode, timestamp: timestamp) { finish(group) }
      } else {
        orphans.append((keyCode, timestamp, clock()))
        if orphans.count > maxOrphans { disableSession(.orphanOverflow) }
      }
    }
  }

  func checkTimeout(now: TimeInterval) {
    precondition(Thread.isMainThread)
    guard now.isFinite else {
      disableSession(.timestampMismatch)
      return
    }
    guard safetyCheck() else { return }
    if let start = groupStartedAt, now - start >= watchdog {
      disableSession(.watchdog)
    } else {
      discardExpiredOrphans(now: now)
    }
  }

  private func discardExpiredOrphans(now: TimeInterval) {
    let previousCount = orphans.count
    orphans.removeAll { now - $0.arrivedAt >= orphanLifetime }
    expiredOrphanCount += UInt64(previousCount - orphans.count)
  }

  /// Ordinary editing boundaries finish pending strokes without poisoning the active session.
  func flushBoundary(
    _ reason: ChordFlushReason, ignoringReleaseOf keyCode: Int? = nil,
    timestamp: TimeInterval? = nil
  ) {
    precondition(Thread.isMainThread)
    ignoredReleaseKeys.formUnion(engine.heldKeys.keys)
    if let keyCode = keyCode, acceptsRelease(keyCode) { ignoredReleaseKeys.insert(keyCode) }
    orphans.removeAll()
    let group = engine.flush(reason: reason, at: timestamp ?? clock())
    groupStartedAt = nil
    lastCompletedAt = nil
    lastKeyDownAt = nil
    if let group = group { finish(group) }
  }

  /// Only lost safety guarantees fail-close the session. A new activation is required to retry.
  func disableSession(_ reason: ChordFlushReason) {
    precondition(Thread.isMainThread)
    guard disabledReason == nil else { return }
    disabledReason = reason
    releaseLease()
    onDisabled(reason)
    flushBoundary(reason)
    if disabledReason != nil { ignoredReleaseKeys.removeAll() }
  }

  private func safetyCheck() -> Bool {
    guard isActive, disabledReason == nil else { return false }
    source.refresh()
    guard disabledReason == nil else { return false }
    if !isEnabled() {
      endSession(.modeDisabled)
      return false
    }
    if !source.permissionGranted {
      disableSession(.permissionLost)
      return false
    }
    if source.secureInputEnabled {
      disableSession(.secureInput)
      return false
    }
    if source.status != .healthy {
      disableSession(.tapDisabled)
      return false
    }
    return true
  }

  private func finish(_ group: StrokeGroup) {
    groupStartedAt = nil
    if group.reason == .allReleased {
      lastCompletedAt = max(lastCompletedAt ?? group.completedAt, group.completedAt)
    }
    replayGroups.append(group)
    guard !isReplaying else { return }
    isReplaying = true
    defer { isReplaying = false }
    while !replayGroups.isEmpty {
      let next = replayGroups.removeFirst()
      for stroke in next.strokes {
        guard outstanding.remove(stroke.id) != nil else { continue }
        let outcome = replay(stroke)
        let terminal =
          next.reason != .allReleased && outcome == .composerReplay
          ? ChordTerminalOutcome.safetyFlush : outcome
        recordTermination(stroke.id, outcome: terminal, reason: next.reason)
      }
    }
  }

  private func terminate(_ id: UInt64, outcome: ChordTerminalOutcome, reason: ChordFlushReason) {
    guard outstanding.remove(id) != nil else { return }
    recordTermination(id, outcome: outcome, reason: reason)
  }

  private func recordTermination(
    _ id: UInt64, outcome: ChordTerminalOutcome, reason: ChordFlushReason
  ) {
    terminalCount += 1
    recentTerminations.append(ChordTermination(strokeID: id, outcome: outcome, reason: reason))
    if recentTerminations.count > 128 { recentTerminations.removeFirst() }
  }
}
