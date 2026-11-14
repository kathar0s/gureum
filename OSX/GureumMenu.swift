//
//  GureumMenu.swift
//  OSX
//
//  Created by KMLee on 2018. 8. 24..
//  Copyright © 2018 youknowone.org. All rights reserved.
//

import Cocoa
import Foundation
import GureumCore

let preferencesWindow: NSWindowController =
  NSStoryboard(name: "Configuration", bundle: Bundle.main).instantiateInitialController()
  as! NSWindowController

/// The destinations this product can actually support. Fork products never inherit upstream services.
struct GureumMenuCapabilities {
  let displayName: String
  let websiteURL: URL?
  let helpURL: URL?
  let issuesURL: URL?
  let sourceURL: URL?
  let donationURL: URL?
  let supportsUpdates: Bool

  static func current(
    bundle: Bundle = .main, identity: InputMethodIdentity = .current
  ) -> GureumMenuCapabilities {
    let displayName =
      ["CFBundleDisplayName", "CFBundleName"]
      .compactMap { bundle.object(forInfoDictionaryKey: $0) as? String }
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty }
      ?? "구름 입력기"
    if identity.usesForkServices {
      return GureumMenuCapabilities(
        displayName: displayName, websiteURL: nil, helpURL: nil,
        issuesURL: URL(string: "https://github.com/kathar0s/gureum/issues"),
        sourceURL: URL(string: "https://github.com/kathar0s/gureum"), donationURL: nil,
        supportsUpdates: false)
    }
    return GureumMenuCapabilities(
      displayName: displayName, websiteURL: URL(string: "http://gureum.io"),
      helpURL: URL(string: "http://dan.gureum.io"),
      issuesURL: URL(string: "http://meok.gureum.io"),
      sourceURL: URL(string: "http://ssi.gureum.io"),
      donationURL: URL(string: "http://donation.gureum.io"), supportsUpdates: true)
  }
}

struct GureumMenuBuilder {
  let capabilities: GureumMenuCapabilities
  let includeDeveloperTools: Bool

  init(
    capabilities: GureumMenuCapabilities,
    includeDeveloperTools: Bool = GureumMenuBuilder.isDebugBuild
  ) {
    self.capabilities = capabilities
    self.includeDeveloperTools = includeDeveloperTools
  }

  static var isDebugBuild: Bool {
    #if DEBUG
      true
    #else
      false
    #endif
  }

  func makeMenu() -> NSMenu {
    let menu = NSMenu(title: capabilities.displayName)
    menu.addItem(
      item(
        "설정…", action: #selector(InputController.showPreferencesWindow(_:)),
        identifier: "preferences", symbol: "gearshape"))
    if capabilities.supportsUpdates {
      menu.addItem(
        item(
          "업데이트 확인…", action: #selector(InputController.checkRecentVersion(_:)),
          identifier: "update", symbol: "arrow.clockwise"))
    }

    let support = NSMenu(title: "도움말 및 지원")
    if capabilities.websiteURL != nil {
      support.addItem(
        item(
          "웹사이트", action: #selector(InputController.openWebsite(_:)), identifier: "website"))
    }
    if capabilities.helpURL != nil {
      support.addItem(
        item(
          "사용 도움말", action: #selector(InputController.openWebsiteHelp(_:)), identifier: "help"))
    }
    if capabilities.issuesURL != nil {
      support.addItem(
        item(
          "문제 신고…", action: #selector(InputController.openWebsiteIssues(_:)), identifier: "issues"))
    }
    if capabilities.sourceURL != nil {
      support.addItem(
        item(
          "소스 코드", action: #selector(InputController.openWebsiteSource(_:)), identifier: "source"))
    }
    if capabilities.donationURL != nil {
      support.addItem(
        item(
          "후원하기", action: #selector(InputController.openWebsiteDonation(_:)), identifier: "donation"
        ))
    }
    if includeDeveloperTools, capabilities.supportsUpdates {
      if !support.items.isEmpty { support.addItem(.separator()) }
      let developer = NSMenu(title: "개발자")
      developer.addItem(
        item(
          "실험 버전 확인…", action: #selector(InputController.checkExperimentalVersion(_:)),
          identifier: "experimental-update"))
      support.addItem(submenuItem("개발자", submenu: developer, identifier: "developer"))
    }
    if !support.items.isEmpty {
      menu.addItem(.separator())
      menu.addItem(
        submenuItem(
          "도움말 및 지원", submenu: support, identifier: "support", symbol: "questionmark.circle"))
    }
    menu.addItem(.separator())
    menu.addItem(
      item(
        "\(capabilities.displayName)에 관하여",
        action: #selector(InputController.showStandardAboutPanel(_:)), identifier: "about",
        symbol: "info.circle"))
    return menu
  }

  private func item(
    _ title: String, action: Selector?, identifier: String, symbol: String? = nil
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    // InputMethodKit routes these actions through the active InputController responder.
    item.target = nil
    item.identifier = NSUserInterfaceItemIdentifier(identifier)
    if let symbol = symbol,
      let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    {
      image.isTemplate = true
      image.size = NSSize(width: 16, height: 16)
      item.image = image
    }
    return item
  }

  private func submenuItem(
    _ title: String, submenu: NSMenu, identifier: String, symbol: String? = nil
  ) -> NSMenuItem {
    let item = item(title, action: nil, identifier: identifier, symbol: symbol)
    item.submenu = submenu
    return item
  }
}

// 왜 App delegate가 아니라 여기 붙는건지 모르겠다
extension InputController {
  @IBAction func showStandardAboutPanel(_: Any) {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [
      .applicationName: GureumMenuCapabilities.current().displayName
    ])
    answers.logMenu(name: "about")
  }

  @IBAction func showPreferencesWindow(_: Any) {
    NSApp.activate(ignoringOtherApps: true)
    preferencesWindow.showWindow(nil)
  }

  private func checkVersion(mode: UpdateMode) {
    guard GureumMenuCapabilities.current().supportsUpdates else { return }
    var title = ""
    var version = ""
    switch mode {
    case .stable:
      title = "업데이트"
      version = "버전"
    case .experimental:
      title = "실험 버전"
      version = "실험 버전"
    }
    UpdateManager.shared.requestVersionInfo(mode: mode) { info in
      guard let info = info else {
        let alert = NSAlert()
        alert.messageText = "구름 입력기 \(title) 확인"
        alert.addButton(withTitle: "확인")
        alert.informativeText = "\(title) 정보에 접근할 수 없습니다. 인터넷에 연결되어 있지 않거나 구름 업데이트의 버그일 수 있습니다."
        alert.runModal()
        return
      }
      if info.update.version == info.current {
        let fmt = "현재 사용하고 있는 구름 입력기 \(info.current ?? "-") 는 최신 \(version)입니다."
        let alert = NSAlert()
        alert.messageText = "구름 입력기 \(title) 확인"
        alert.addButton(withTitle: "확인")
        alert.informativeText = fmt
        alert.runModal()
      } else {
        var message =
          "현재 사용하고 있는 구름 입력기는 \(info.current ?? "-") 이고 최신 \(version)은 \(info.update.version) 입니다. 업데이트는 로그아웃하거나 재부팅해야 적용됩니다."
        if !info.update.description.isEmpty {
          message += " 업데이트 요약은 '\(info.update.description)' 입니다."
        }
        if let url = URL(string: info.update.url) {
          NSWorkspace.shared.open(url)
        } else {
          message += " 현재 업데이트 링크를 찾을 수 없습니다. 버그 리포트를 부탁드립니다."
        }
        let alert = NSAlert()
        alert.messageText = "구름 입력기 \(title) 확인"
        alert.addButton(withTitle: "확인")
        alert.informativeText = message
        alert.runModal()
      }
    }
  }

  @IBAction func checkRecentVersion(_: Any) {
    answers.logMenu(name: "check-version")
    checkVersion(mode: .stable)
  }

  @IBAction func checkExperimentalVersion(_: Any) {
    answers.logMenu(name: "check-experimental")
    checkVersion(mode: .experimental)
  }

  @IBAction func openWebsite(_: Any) {
    openMenuURL(GureumMenuCapabilities.current().websiteURL, event: "website")
  }

  @IBAction func openWebsiteHelp(_: Any) {
    openMenuURL(GureumMenuCapabilities.current().helpURL, event: "website-help")
  }

  @IBAction func openWebsiteSource(_: Any) {
    openMenuURL(GureumMenuCapabilities.current().sourceURL, event: "website-source")
  }

  @IBAction func openWebsiteIssues(_: Any) {
    openMenuURL(GureumMenuCapabilities.current().issuesURL, event: "website-issues")
  }

  @IBAction func openWebsiteDonation(_: Any) {
    openMenuURL(GureumMenuCapabilities.current().donationURL, event: "website-donation")
  }

  private func openMenuURL(_ destination: URL?, event: String) {
    guard let url = destination else { return }
    NSWorkspace.shared.open(url)
    answers.logMenu(name: event)
  }
}
