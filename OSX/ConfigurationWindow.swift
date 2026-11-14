//
//  ConfigurationWindow.swift
//  OSX
//
//  Created by Jeong YunWon on 2019/11/03.
//  Copyright © 2019 youknowone.org. All rights reserved.
//

import Cocoa
import Foundation

final class ConfiguraionWindowController: NSWindowController, NSToolbarDelegate {
  private static let settingsToolbarIdentifier = NSToolbar.Identifier("BaramSettingsToolbar")
  private static let settingsSectionsIdentifier = NSToolbarItem.Identifier("BaramSettingsSections")

  override func windowDidLoad() {
    super.windowDidLoad()
    guard let window = window else { return }
    window.contentMinSize = NSSize(width: 500, height: 300)
    window.contentMaxSize = NSSize(width: 500, height: 680)
    window.autorecalculatesKeyViewLoop = true
    window.title = "설정"
    configureToolbar(for: window)
    DispatchQueue.main.async { [weak self] in self?.selectSettingsSection(at: 0, animate: false) }
  }

  private var preferenceController: PreferenceViewController? {
    guard let host = window?.contentViewController as? PreferencePaneViewController else {
      return nil
    }
    _ = host.view
    return host.preferenceViewController
  }

  private func configureToolbar(for window: NSWindow) {
    let toolbar = NSToolbar(identifier: Self.settingsToolbarIdentifier)
    toolbar.delegate = self
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    toolbar.displayMode = .iconAndLabel
    if #available(macOS 11, *) {
      toolbar.centeredItemIdentifier = Self.settingsSectionsIdentifier
      window.toolbarStyle = .preference
    }
    window.toolbar = toolbar
  }

  @objc private func settingsSectionChanged(_ sender: NSToolbarItemGroup) {
    selectSettingsSection(at: sender.selectedIndex, animate: true)
  }

  private func selectSettingsSection(at index: Int, animate: Bool) {
    guard let window = window, let controller = preferenceController,
      controller.settingsSectionTitles.indices.contains(index)
    else { return }
    controller.selectSettingsSection(at: index)
    window.title = "\(controller.settingsSectionTitles[index]) 설정"
    let contentSize = NSSize(width: 500, height: controller.preferredContentHeight(for: index))
    let currentTop = window.frame.maxY
    let contentRect = NSRect(origin: .zero, size: contentSize)
    var frame = window.frameRect(forContentRect: contentRect)
    frame.origin.x = window.frame.origin.x
    frame.origin.y = currentTop - frame.height
    let shouldAnimate = animate && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    window.setFrame(frame, display: true, animate: shouldAnimate)
  }

  func toolbar(
    _: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar _: Bool
  ) -> NSToolbarItem? {
    guard itemIdentifier == Self.settingsSectionsIdentifier,
      let titles = preferenceController?.settingsSectionTitles
    else { return nil }
    let symbolNames = ["keyboard", "command", "gearshape"]
    let images = symbolNames.compactMap {
      NSImage(systemSymbolName: $0, accessibilityDescription: nil)
    }
    guard images.count == titles.count else { return nil }
    let group = NSToolbarItemGroup(
      itemIdentifier: itemIdentifier, images: images, selectionMode: .selectOne,
      labels: titles, target: self, action: #selector(settingsSectionChanged(_:)))
    group.selectedIndex = 0
    group.visibilityPriority = .user
    return group
  }

  func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    [Self.settingsSectionsIdentifier]
  }

  func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    [Self.settingsSectionsIdentifier]
  }

  func toolbarSelectableItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    [Self.settingsSectionsIdentifier]
  }
}

final class PreferencePaneViewController: NSViewController {
  private(set) var preferenceViewController: PreferenceViewController?
  private let isAtLeast1015 = ProcessInfo().isOperatingSystemAtLeast(
    OperatingSystemVersion(majorVersion: 10, minorVersion: 15, patchVersion: 0))

  func viewForFailure() -> NSView {
    let rect = NSRect(x: 0, y: 0, width: 200, height: 100)
    let label = NSTextView(frame: rect)
    label.isEditable = false
    label.string = "환경설정 GUI 읽기에 실패했습니다. 버그 리포트를 남겨주세요.\n\nhttps://github.com/gureum/gureum/issues"
    let view = NSView(frame: rect)
    view.addSubview(label)
    return view
  }

  func viewFromPrefPane() -> NSView {
    let path = Bundle.main.path(forResource: "Preferences", ofType: "prefPane")
    let bundle = NSPrefPaneBundle(path: path)!
    guard bundle.bundle != nil, bundle.bundle.principalClass != nil else {
      return viewForFailure()
    }
    if isAtLeast1015 {
      let pane = NSPreferencePane(bundle: bundle.bundle)
      return pane.loadMainView()
    } else {
      let loaded = bundle.instantiatePrefPaneObject()
      assert(loaded)
      let pane = bundle.prefPaneObject()!
      return pane.mainView
    }
  }

  func viewFromNib() -> NSView {
    var topLevelObjects: NSArray?
    let succeed = Bundle.main.loadNibNamed(
      "Preferences", owner: self, topLevelObjects: &topLevelObjects)
    guard let nibObjects = topLevelObjects, succeed else {
      NSLog("Preferences nib loading failed.")
      return viewForFailure()
    }
    guard
      let vc = nibObjects.filter({
        ($0 as! NSObject).className == "PreferenceViewController"
      }).first as? PreferenceViewController
    else {
      NSLog("Preferences lookup failed.")
      return viewForFailure()
    }
    addChild(vc)
    preferenceViewController = vc
    let content = vc.view
    let host = NSView(frame: content.frame)
    content.translatesAutoresizingMaskIntoConstraints = false
    host.addSubview(content)
    NSLayoutConstraint.activate([
      content.leadingAnchor.constraint(equalTo: host.leadingAnchor),
      content.trailingAnchor.constraint(equalTo: host.trailingAnchor),
      content.topAnchor.constraint(equalTo: host.topAnchor),
      content.bottomAnchor.constraint(equalTo: host.bottomAnchor),
    ])
    return host
  }

  override func loadView() {
    #if USE_PREFPANE
      view = viewFromPrefPane()
    #else
      view = viewFromNib()
    #endif
  }
}
