// Render only the preferences view, without desktop capture or input-method activation.
import Cocoa
import ImageIO
import PreferencePanes
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
  ("minimum", .aqua, NSSize(width: 600, height: 560)),
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
    sectionVariants.append(("long-layout-focus", .aqua, NSSize(width: 600, height: 560)))
  }
  if section == "shortcuts" || section == "advanced" {
    sectionVariants.append(("expanded", .aqua, originalSize))
  }
  for (name, appearance, size) in sectionVariants {
    let menu = descendants(of: content).compactMap { $0 as? NSPopUpButton }.first
    let selectedIndex = menu?.indexOfSelectedItem
    if name == "long-layout-focus", let menu = menu {
      menu.addItem(withTitle: "아주 긴 이름의 사용자 지정 로마자 키보드 레이아웃")
      menu.selectItem(at: menu.numberOfItems - 1)
      precondition(
        window.makeFirstResponder(menu), "Native layout menu must accept keyboard focus.")
      precondition(
        menu.accessibilityRole() == .popUpButton,
        "Layout picker must keep its native accessibility role.")
    }
    if name == "expanded" {
      let title = section == "shortcuts" ? "시스템 전환 설정 안내" : "개발자 도구"
      if let button = descendants(of: content).compactMap({ $0 as? NSButton }).first(where: {
        $0.title == title
      }) {
        button.performClick(nil)
      }
    }
    window.appearance = NSAppearance(named: appearance)
    window.setContentSize(size)
    content.frame = NSRect(origin: .zero, size: size)
    content.layoutSubtreeIfNeeded()
    app.updateWindows()
    window.display()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    content.displayIfNeeded()
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
    context.setFillColor(
      appearance == .darkAqua ? CGColor(gray: 0.13, alpha: 1) : CGColor(gray: 0.96, alpha: 1))
    context.fill(bounds)
    context.scaleBy(x: 2, y: 2)
    content.layer?.render(in: context)
    let target = outputURL.appendingPathComponent("preferences-\(section)-\(name).png")
    guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        target as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { exit(1) }
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
