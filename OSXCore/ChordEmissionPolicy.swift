import AppKit
import Foundation
import Hangul

func effectiveHangulKeyboardIdentifier(_ identifier: String, strictCombinationRule: Bool) -> String
{
  strictCombinationRule && (identifier == "3f" || identifier == "39")
    ? identifier + "s" : identifier
}

struct ChordLayoutMapping: Equatable {
  let identifier: String
  let keyboardType: String
  let asciiToScalar: [UInt32: UInt32]
}

protocol ChordLayoutMappingProviding {
  func mapping(for keyboardIdentifier: String) -> ChordLayoutMapping?
}

/// Reads the same bundled keyboard XML as libhangul, including cached missing/invalid resources.
final class ChordLayoutMappingRepository: ChordLayoutMappingProviding {
  static let shared = ChordLayoutMappingRepository()
  private enum Entry {
    case found(ChordLayoutMapping)
    case missing
  }
  private let resourceURL: (String) -> URL?
  private let lock = NSLock()
  private var cache: [String: Entry] = [:]

  init(bundle: Bundle = Bundle(for: HGInputContext.self)) {
    resourceURL = { identifier in
      bundle.url(
        forResource: "hangul-keyboard-\(identifier)", withExtension: "xml",
        subdirectory: "keyboards")
    }
  }

  init(keyboardDirectoryURL: URL) {
    resourceURL = { identifier in
      keyboardDirectoryURL.appendingPathComponent("hangul-keyboard-\(identifier).xml")
    }
  }

  func mapping(for keyboardIdentifier: String) -> ChordLayoutMapping? {
    guard !keyboardIdentifier.isEmpty,
      keyboardIdentifier.utf8.allSatisfy({
        (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45
      })
    else { return nil }
    lock.lock()
    defer { lock.unlock() }
    if let entry = cache[keyboardIdentifier] {
      if case .found(let mapping) = entry { return mapping }
      return nil
    }
    guard let url = resourceURL(keyboardIdentifier), url.isFileURL,
      let data = try? Data(contentsOf: url)
    else {
      cache[keyboardIdentifier] = .missing
      return nil
    }
    let delegate = KeyboardMappingXMLParser()
    let parser = XMLParser(data: data)
    parser.shouldResolveExternalEntities = false
    parser.externalEntityResolvingPolicy = .never
    parser.delegate = delegate
    guard parser.parse(), let mapping = delegate.mapping,
      mapping.identifier == keyboardIdentifier
    else {
      cache[keyboardIdentifier] = .missing
      return nil
    }
    cache[keyboardIdentifier] = .found(mapping)
    return mapping
  }
}

private final class KeyboardMappingXMLParser: NSObject, XMLParserDelegate {
  private var identifier: String?
  private var keyboardType: String?
  private var values: [UInt32: UInt32] = [:]
  private var depth = 0
  private var inMapZero = false
  private var sawMapZero = false
  private var invalid = false

  var mapping: ChordLayoutMapping? {
    guard !invalid, sawMapZero, let identifier = identifier, let keyboardType = keyboardType else {
      return nil
    }
    return ChordLayoutMapping(
      identifier: identifier, keyboardType: keyboardType, asciiToScalar: values)
  }

  func parser(
    _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
    qualifiedName qName: String?, attributes: [String: String]
  ) {
    depth += 1
    if depth == 1 {
      guard elementName == "hangul-keyboard", let id = attributes["id"], !id.isEmpty,
        let type = attributes["type"], !type.isEmpty
      else {
        invalid = true
        parser.abortParsing()
        return
      }
      identifier = id
      keyboardType = type
    } else if depth == 2, elementName == "map" {
      inMapZero = attributes["id"] == "0"
      if inMapZero {
        guard !sawMapZero else {
          invalid = true
          parser.abortParsing()
          return
        }
        sawMapZero = true
      }
    } else if depth == 3, inMapZero, elementName == "item" {
      guard let key = Self.scalar(attributes["key"]), key < 128,
        let value = Self.scalar(attributes["value"]), UnicodeScalar(value) != nil,
        values[key] == nil
      else {
        invalid = true
        parser.abortParsing()
        return
      }
      values[key] = value
    }
  }

  func parser(
    _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if depth == 2, elementName == "map" { inMapZero = false }
    depth -= 1
  }

  private static func scalar(_ value: String?) -> UInt32? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
    if value.lowercased().hasPrefix("0x") { return UInt32(value.dropFirst(2), radix: 16) }
    return UInt32(value)
  }
}

struct ChordEmissionPolicy {
  private enum Role: Int { case initial, medial, finalConsonant }
  private let mappingProvider: ChordLayoutMappingProviding
  private let strictCombinationRule: Bool

  init(
    mappingProvider: ChordLayoutMappingProviding = ChordLayoutMappingRepository.shared,
    strictCombinationRule: Bool = false
  ) {
    self.mappingProvider = mappingProvider
    self.strictCombinationRule = strictCombinationRule
  }

  func order(group: StrokeGroup, keyboardIdentifier: String) -> [ChordStroke] {
    let original = group.strokes
    let identifier = effectiveHangulKeyboardIdentifier(
      keyboardIdentifier, strictCombinationRule: strictCombinationRule)
    guard group.reason == .allReleased, identifier != "3gs", identifier != "3gc",
      Set(original.map(\.id)).count == original.count,
      let mapping = mappingProvider.mapping(for: identifier), mapping.identifier == identifier,
      mapping.keyboardType == "jaso" || mapping.keyboardType == "jaso-yet"
    else { return original }
    var ranked: [(index: Int, role: Role, stroke: ChordStroke)] = []
    for (index, stroke) in original.enumerated() {
      guard let role = role(for: stroke, mapping: mapping) else { return original }
      ranked.append((index, role, stroke))
    }
    guard ranked.contains(where: { $0.role == .initial }),
      ranked.contains(where: { $0.role == .medial })
    else { return original }
    return ranked.sorted {
      $0.role.rawValue == $1.role.rawValue
        ? $0.index < $1.index : $0.role.rawValue < $1.role.rawValue
    }.map(\.stroke)
  }

  private func role(for stroke: ChordStroke, mapping: ChordLayoutMapping) -> Role? {
    let flags = NSEvent.ModifierFlags(rawValue: stroke.modifiers)
    guard flags.intersection([.command, .control, .option, .function]).isEmpty else { return nil }
    let keyMap = flags.contains(.shift) ? keyMapUpper : keyMapLower
    guard keyMap.indices.contains(stroke.keyCode), let character = keyMap[stroke.keyCode],
      character.unicodeScalars.count == 1, let ascii = character.unicodeScalars.first?.value,
      ascii < 128, let mapped = mapping.asciiToScalar[ascii]
    else { return nil }
    let scalar = hangul_vkeycode_to_keycode(mapped)
    if hangul_is_choseong(scalar) { return .initial }
    if hangul_is_jungseong(scalar) { return .medial }
    if hangul_is_jongseong(scalar) { return .finalConsonant }
    return nil
  }
}
