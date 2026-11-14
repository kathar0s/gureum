import AppKit
import Carbon
import CoreGraphics

public enum PhysicalKeySourceStatus: Equatable {
  case stopped, permissionDenied, secureInput, healthy, tapDisabled, unavailable
}

enum PhysicalKeySourceEvent {
  case keyUp(keyCode: Int, timestamp: TimeInterval)
  case statusChanged(PhysicalKeySourceStatus)
  case heartbeat(timestamp: TimeInterval)
}

protocol PhysicalKeyEventSourceProtocol: AnyObject {
  var status: PhysicalKeySourceStatus { get }
  var permissionGranted: Bool { get }
  var secureInputEnabled: Bool { get }
  func acquireLease(_ token: UUID)
  func releaseLease(_ token: UUID)
  func refresh()
  func addObserver(_ observer: @escaping (PhysicalKeySourceEvent) -> Void) -> UUID
  func removeObserver(_ token: UUID)
}

/// A passive key-release observer. IMK is the only source of authoritative key-down strokes.
public final class PhysicalKeyEventSource: PhysicalKeyEventSourceProtocol {
  public static let shared = PhysicalKeyEventSource()
  public static let statusDidChange = Notification.Name("GureumPhysicalKeySourceStatusDidChange")
  public private(set) var status: PhysicalKeySourceStatus = .stopped
  public private(set) var sessionWarning: String?
  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var timer: Timer?
  private var observers: [UUID: (PhysicalKeySourceEvent) -> Void] = [:]
  private var generation: UInt64 = 0
  private var leases: Set<UUID> = []

  public var activeLeaseCount: Int { leases.count }

  private init() {}

  public var permissionGranted: Bool { CGPreflightListenEventAccess() }
  public var secureInputEnabled: Bool { IsSecureEventInputEnabled() }

  public var statusText: String {
    if let sessionWarning = sessionWarning { return sessionWarning }
    switch status {
    case .stopped: return "대기 · 지원 세벌식 입력이 활성화될 때만 관찰합니다."
    case .permissionDenied: return "입력 모니터링 허용이 필요합니다."
    case .secureInput: return "보안 입력 중 · 일반 입력을 사용합니다."
    case .healthy: return "키 해제 수신 준비됨 · 누른 순서대로 전달합니다."
    case .tapDisabled, .unavailable: return "수신 중지 · 일반 입력을 사용합니다. 입력기를 다시 선택하세요."
    }
  }

  /// Call only from the explicit permission button; neither startup nor install invokes this.
  @discardableResult public func requestPermissionFromUserAction() -> Bool {
    precondition(Thread.isMainThread)
    guard InputMethodIdentity.current.supportsPhysicalChording else { return false }
    let granted = CGRequestListenEventAccess()
    refresh()
    return granted
  }

  public func setEnabled(_ enabled: Bool) {
    precondition(Thread.isMainThread)
    sessionWarning = nil
    if enabled { refresh() } else { stop(status: .stopped) }
  }

  public func reportSessionWarning(_ warning: String?) {
    sessionWarning = warning
    NotificationCenter.default.post(name: Self.statusDidChange, object: self)
  }

  func acquireLease(_ token: UUID) {
    precondition(Thread.isMainThread)
    guard InputMethodIdentity.current.supportsPhysicalChording,
      Configuration.shared.physicalChordingEnabled
    else {
      stop(status: .stopped)
      return
    }
    leases.insert(token)
    start()
  }

  func releaseLease(_ token: UUID) {
    precondition(Thread.isMainThread)
    leases.remove(token)
    if leases.isEmpty {
      tearDown()
      if status == .healthy { changeStatus(.stopped) }
    }
  }

  private func start() {
    precondition(Thread.isMainThread)
    guard InputMethodIdentity.current.supportsPhysicalChording else { return }
    guard !leases.isEmpty, Configuration.shared.physicalChordingEnabled else {
      stop(status: .stopped)
      return
    }
    guard permissionGranted else {
      stop(status: .permissionDenied)
      return
    }
    guard !secureInputEnabled else {
      stop(status: .secureInput)
      return
    }
    if let tap = tap, CGEvent.tapIsEnabled(tap: tap) { return }
    tearDown()
    let mask = CGEventMask(1) << CGEventType.keyUp.rawValue
    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
        eventsOfInterest: mask,
        callback: { _, type, event, context in
          if let context = context {
            let source = Unmanaged<PhysicalKeyEventSource>.fromOpaque(context).takeUnretainedValue()
            source.received(type: type, event: event)
          }
          // Listen-only taps cannot consume or alter events. Always return the original event.
          return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
    else {
      changeStatus(.unavailable)
      return
    }
    self.tap = tap
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    runLoopSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    changeStatus(.healthy)
    timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      self.refresh()
      self.emit(.heartbeat(timestamp: ProcessInfo.processInfo.systemUptime))
    }
    RunLoop.main.add(timer!, forMode: .common)
  }

  public func refresh() {
    precondition(Thread.isMainThread)
    guard !leases.isEmpty, Configuration.shared.physicalChordingEnabled else {
      stop(status: .stopped)
      return
    }
    guard permissionGranted else {
      stop(status: .permissionDenied)
      return
    }
    guard !secureInputEnabled else {
      stop(status: .secureInput)
      return
    }
    if let tap = tap, !CGEvent.tapIsEnabled(tap: tap) { stop(status: .tapDisabled) }
  }

  func addObserver(_ observer: @escaping (PhysicalKeySourceEvent) -> Void) -> UUID {
    let token = UUID()
    observers[token] = observer
    return token
  }

  func removeObserver(_ token: UUID) { observers.removeValue(forKey: token) }

  private func received(type: CGEventType, event: CGEvent) {
    precondition(Thread.isMainThread)
    let observedGeneration = generation
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      DispatchQueue.main.async { [weak self] in
        guard let self = self, self.generation == observedGeneration else { return }
        self.stop(status: .tapDisabled)
      }
    } else if type == .keyUp {
      let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
      // CGEvent uses boot-relative nanoseconds; NSEvent supplies seconds on the same clock.
      let timestamp = TimeInterval(event.timestamp) / 1_000_000_000
      // Return from the passive callback before any IMK/client IPC or composition can run.
      DispatchQueue.main.async { [weak self] in
        guard let self = self, self.generation == observedGeneration else { return }
        self.refresh()
        guard self.status == .healthy else { return }
        self.emit(.keyUp(keyCode: keyCode, timestamp: timestamp))
      }
    }
  }

  private func emit(_ event: PhysicalKeySourceEvent) {
    for observer in Array(observers.values) { observer(event) }
  }

  private func changeStatus(_ newStatus: PhysicalKeySourceStatus) {
    guard status != newStatus else { return }
    status = newStatus
    emit(.statusChanged(newStatus))
    NotificationCenter.default.post(name: Self.statusDidChange, object: self)
  }

  private func stop(status: PhysicalKeySourceStatus) {
    tearDown()
    changeStatus(status)
  }

  private func tearDown() {
    generation &+= 1
    timer?.invalidate()
    timer = nil
    if let source = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
    }
    runLoopSource = nil
    if let tap = tap { CFMachPortInvalidate(tap) }
    tap = nil
  }
}
