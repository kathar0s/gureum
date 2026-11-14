// Render only the preferences view, without desktop capture or input-method activation.
import Cocoa
import ImageIO
import PreferencePanes
import QuartzCore
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
  fputs("Usage: render_preferences.swift <Preferences.prefPane> <output-directory>\n", stderr)
  exit(2)
}

let bundlePath = CommandLine.arguments[1]
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
guard let bundle = Bundle(path: bundlePath), bundle.load() else {
  fputs("Could not load the preferences bundle.\n", stderr)
  exit(1)
}
let pane = NSPreferencePane(bundle: bundle)
var topLevelObjects: NSArray?
guard bundle.loadNibNamed("Preferences", owner: pane, topLevelObjects: &topLevelObjects),
  let controller = topLevelObjects?.first(where: { $0 is NSViewController }) as? NSViewController
else { exit(1) }
let content = controller.view
content.wantsLayer = true
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let originalSize = content.frame.size
let variants: [(String, NSAppearance.Name, NSSize)] = [
  ("light", .aqua, originalSize),
  ("dark", .darkAqua, originalSize),
  ("minimum", .aqua, NSSize(width: 500, height: 340)),
]
let window = NSWindow(
  contentRect: NSRect(origin: .zero, size: originalSize),
  styleMask: [.titled, .closable], backing: .buffered, defer: false)
window.contentView = content
window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
window.orderFront(nil)
let picker = content.subviews.compactMap { $0 as? NSSegmentedControl }.first
let sections = picker == nil ? ["original"] : ["input", "shortcuts", "advanced"]
func descendants(of view: NSView) -> [NSView] {
  view.subviews.flatMap { [$0] + descendants(of: $0) }
}
for control in descendants(of: content).compactMap({ $0 as? NSSwitch }) {
  precondition(!(control.accessibilityLabel() ?? "").isEmpty, "Every switch needs a spoken label.")
}
for (sectionIndex, section) in sections.enumerated() {
  if let picker = picker, let action = picker.action {
    picker.selectedSegment = sectionIndex
    NSApp.sendAction(action, to: picker.target, from: picker)
  }
  var sectionVariants = variants
  if section == "input" {
    sectionVariants.append(("long-layout-focus", .aqua, NSSize(width: 500, height: 440)))
  }
  if section == "shortcuts" { sectionVariants.append(("system-help", .aqua, originalSize)) }
  if section == "advanced" { sectionVariants.append(("developer", .aqua, originalSize)) }
  for (name, appearance, size) in sectionVariants {
    let menu = descendants(of: content).compactMap { $0 as? NSPopUpButton }.first
    let selectedIndex = menu?.indexOfSelectedItem
    if name == "long-layout-focus", let menu = menu {
      menu.addItem(withTitle: "아주 긴 이름의 사용자 지정 로마자 키보드 레이아웃")
      menu.selectItem(at: menu.numberOfItems - 1)
      precondition(
        window.makeFirstResponder(menu), "Native layout menu must accept keyboard focus.")
      precondition(
        menu.cell is NSPopUpButtonCell, "Layout picker must keep its stock native popup cell.")
    }
    window.appearance = NSAppearance(named: appearance)
    window.setContentSize(size)
    content.frame = NSRect(origin: .zero, size: size)
    content.layoutSubtreeIfNeeded()
    app.updateWindows()
    window.display()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    if let scroll = descendants(of: content).compactMap({ $0 as? NSScrollView }).first(where: {
      !$0.isHiddenOrHasHiddenAncestor
    }), let document = scroll.documentView {
      let bottom = max(0, document.bounds.height - scroll.contentView.bounds.height)
      scroll.contentView.scroll(
        to: NSPoint(x: 0, y: name == "system-help" || name == "developer" ? bottom : 0))
      scroll.reflectScrolledClipView(scroll.contentView)
      app.updateWindows()
      window.display()
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
      content.displayIfNeeded()
      CATransaction.flush()
    }
    content.displayIfNeeded()
    let visibleControls = descendants(of: content).filter {
      !$0.isHiddenOrHasHiddenAncestor
        && (($0 is NSControl && !($0 is NSTextField))
          || $0.responds(to: NSSelectorFromString("setShortcutValue:")))
    }
    for control in visibleControls {
      if let label = control.superview?.subviews.compactMap({ $0 as? NSTextField }).first {
        let delta = abs(control.frame.midY - label.frame.midY)
        precondition(delta <= 0.5, "Row labels and controls must share their vertical center.")
        print(
          "metric \(section) \(name): \(label.stringValue) \(control.frame.size) centerDelta=\(delta)"
        )
      }
    }
    if let picker = picker {
      var current: NSView? = picker
      var seen = Set<ObjectIdentifier>()
      while let next = current, seen.insert(ObjectIdentifier(next)).inserted {
        precondition(!next.isHiddenOrHasHiddenAncestor, "Keyboard loop must exclude hidden pages.")
        current = next.nextKeyView
      }
      precondition(current === picker, "Keyboard loop must return to category navigation.")
    }
    guard
      let context = CGContext(
        data: nil, width: Int(size.width * 2), height: Int(size.height * 2),
        bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else {
      fputs("Could not allocate the preferences render.\n", stderr)
      exit(1)
    }
    let bounds = CGRect(origin: .zero, size: NSSize(width: size.width * 2, height: size.height * 2))
    window.effectiveAppearance.performAsCurrentDrawingAppearance {
      context.setFillColor(NSColor.windowBackgroundColor.cgColor)
      context.fill(bounds)
    }
    context.scaleBy(x: 2, y: 2)
    content.layer?.render(in: context)
    let target = outputURL.appendingPathComponent("preferences-\(section)-\(name).png")
    guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        target as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { exit(1) }
    if let box = descendants(of: content).compactMap({ $0 as? NSBox }).first(where: {
      $0.boxType == .primary && !$0.isHiddenOrHasHiddenAncestor
        && $0.visibleRect.contains(NSPoint(x: $0.bounds.midX, y: $0.bounds.minY + 10))
    }) {
      let point = box.convert(
        NSPoint(x: box.bounds.midX, y: box.bounds.minY + 10), to: content)
      let pixels = NSBitmapImageRep(cgImage: image)
      let background = pixels.colorAt(x: 4, y: 4)!.usingColorSpace(.sRGB)!
      let group = pixels.colorAt(x: Int(point.x * 2), y: image.height - Int(point.y * 2))!
        .usingColorSpace(.sRGB)!
      let backgroundLevel =
        (background.redComponent + background.greenComponent + background.blueComponent) / 3
      let groupLevel = (group.redComponent + group.greenComponent + group.blueComponent) / 3
      print(
        "surface \(section) \(name): window=\(Int(backgroundLevel * 255)) group=\(Int(groupLevel * 255))"
      )
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { exit(1) }
    print(target.path)
    if name == "long-layout-focus", let menu = menu, let selectedIndex = selectedIndex {
      menu.removeItem(at: menu.numberOfItems - 1)
      menu.selectItem(at: selectedIndex)
      window.makeFirstResponder(nil)
    }
  }
}
