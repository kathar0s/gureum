import Foundation

struct ChordStroke: Equatable {
  let id: UInt64
  let keyCode: Int
  let text: String
  let modifiers: UInt
  let timestamp: TimeInterval
}

enum ChordFlushReason: String, Equatable {
  case allReleased, deactivated, layoutChanged, clientChanged, mouse, command, nonMappable
  case shortcut, candidate, modeDisabled, permissionLost, secureInput, tapDisabled
  case watchdog, unmatchedEvent, orphanOverflow, groupOverflow, timestampMismatch
}

struct StrokeGroup: Equatable {
  let strokes: [ChordStroke]
  let reason: ChordFlushReason
  let completedAt: TimeInterval
}

enum ChordPressResult: Equatable {
  case recorded, duplicateWhileHeld
}

/// Physical grouping only. Layout interpretation and Hangul composition remain outside this type.
struct ChordGroupingEngine {
  private(set) var strokes: [ChordStroke] = []
  private var heldSince: [Int: TimeInterval] = [:]

  var isEmpty: Bool { strokes.isEmpty }
  var heldKeyCount: Int { heldSince.count }
  var heldKeys: [Int: TimeInterval] { heldSince }

  func heldTimestamp(for keyCode: Int) -> TimeInterval? { heldSince[keyCode] }

  mutating func press(_ stroke: ChordStroke) -> ChordPressResult {
    let duplicate = heldSince[stroke.keyCode] != nil
    strokes.append(stroke)
    heldSince[stroke.keyCode] = stroke.timestamp
    return duplicate ? .duplicateWhileHeld : .recorded
  }

  mutating func release(keyCode: Int, timestamp: TimeInterval) -> StrokeGroup? {
    guard heldSince.removeValue(forKey: keyCode) != nil else { return nil }
    return heldSince.isEmpty ? flush(reason: .allReleased, at: timestamp) : nil
  }

  mutating func flush(reason: ChordFlushReason, at timestamp: TimeInterval) -> StrokeGroup? {
    guard !strokes.isEmpty else { return nil }
    let group = StrokeGroup(strokes: strokes, reason: reason, completedAt: timestamp)
    strokes.removeAll(keepingCapacity: true)
    heldSince.removeAll(keepingCapacity: true)
    return group
  }
}
