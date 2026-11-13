//
//  GureumTests.swift
//  OSX
//
//  Created by Jim Jeon on 16/09/2018.
//  Copyright © 2018 youknowone.org. All rights reserved.
//

import Hangul
import InputMethodKit
import XCTest

@testable import GureumCore

private var lastNotification: NSUserNotification!

extension NSUserNotificationCenter {
  func deliver(_ notification: NSUserNotification) {
    lastNotification = notification
  }
}

class GureumTests: XCTestCase {
  static let domainName = "org.youknowone.Gureum.test"
  lazy var moderate: VirtualApp = ModerateApp()
  // lazy var xcode: VirtualApp = XcodeApp()
  lazy var terminal: VirtualApp! = nil
  // lazy var terminal: VirtualApp = TerminalApp()
  // lazy var greedy: VirtualApp = GreedyApp()
  lazy var apps: [VirtualApp] = [moderate]

  override class func setUp() {
    Configuration.shared = Configuration(suiteName: "org.youknowone.Gureum.test")!
    super.setUp()
  }

  override class func tearDown() {
    super.tearDown()
  }

  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.

    Configuration.shared.removePersistentDomain(forName: GureumTests.domainName)
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }

  func testPreferencePane() {
    let path = Bundle.main.path(forResource: "Preferences", ofType: "prefPane")
    let bundle = NSPrefPaneBundle(path: path)!
    let loaded = bundle.instantiatePrefPaneObject()
    XCTAssertTrue(loaded)
  }

  func testPreferencesHostAppliesMinimumWindowSizeAndRetainsChildController() throws {
    let storyboard = NSStoryboard(name: "Configuration", bundle: .main)
    let controller = try XCTUnwrap(storyboard.instantiateInitialController() as? NSWindowController)
    let window = try XCTUnwrap(controller.window)
    defer { window.close() }

    XCTAssertEqual(window.contentMinSize, NSSize(width: 600, height: 560))
    let host = try XCTUnwrap(window.contentViewController)
    _ = host.view
    XCTAssertEqual(host.children.count, 1)
    let child = try XCTUnwrap(host.children.first)
    XCTAssertTrue(child.parent === host)
    XCTAssertTrue(child.view.superview === host.view)
  }

  func testNotifyUpdate() {
    let data = """
      {
          "version": "1.10.0",
          "description": "Mojave 대응을 포함한 대형 업데이트",
          "url": "https://github.com/gureum/gureum/releases/tag/1.10.0"
      }
      """.data(using: .utf8)
    let update = try! JSONDecoder().decode(UpdateManager.UpdateInfo.self, from: data!)

    let versionInfo = UpdateManager.VersionInfo(update: update, experimental: true)
    UpdateManager.notifyUpdate(info: versionInfo)
    XCTAssertEqual(
      "최신 버전: 1.10.0 현재 버전: \(Bundle.main.version ?? "-")\nMojave 대응을 포함한 대형 업데이트",
      lastNotification.informativeText)
    XCTAssertEqual(
      ["url": "https://github.com/gureum/gureum/releases/tag/1.10.0"],
      lastNotification.userInfo as! [String: String])
  }

  func testLayoutChange() {
    Configuration.shared.inputModeExchangeKey = Configuration.Shortcut(.space, .shift)
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        "org.youknowone.inputmethod.Gureum.qwerty", forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputFlags(.capsLock)

      app.inputText(" ", key: .space, modifiers: .shift)
      app.inputText(" ", key: .space, modifiers: .shift)
      XCTAssertEqual("", app.client.string, "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testLayoutChangeCommit() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        "org.youknowone.inputmethod.Gureum.han2", forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiG)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      app.inputFlags(.capsLock)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testCapsLockLanguageSwitchCapableInfoPlist() {
    let infoDictionary = Bundle.main.infoDictionary ?? [:]
    XCTAssertEqual(infoDictionary["TICapsLockLanguageSwitchCapable"] as? Bool, true)

    let componentInputModeDict = infoDictionary["ComponentInputModeDict"] as? [String: Any]
    let inputModes = componentInputModeDict?["tsInputModeListKey"] as? [String: [String: Any]]
    let missingCapableInputModes = inputModes?
      .filter { $0.key.hasPrefix("org.youknowone.inputmethod.Gureum.") }
      .compactMap { inputMode, properties in
        (properties["TICapsLockLanguageSwitchCapable"] as? Bool) == true ? nil : inputMode
      }
      .sorted()

    XCTAssertEqual(missingCapableInputModes, [])
  }

  func testSearchEmoticonTable() {
    let bundle = Bundle(for: HGKeyboard.self)
    let path: String? = bundle.path(forResource: "emoji", ofType: "txt", inDirectory: "hanja")
    let table = HGHanjaTable(contentOfFile: path!)!
    // 현재 5글자 이상만 가능
    let list: HGHanjaList = table.hanjas(byPrefixSearching: "hushed") ?? HGHanjaList()
    XCTAssert(list.count > 0)
  }

  func testCommandkeyAndControlkey() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.qwerty.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiA, modifiers: .command)
      app.inputKey(.ansiA, modifiers: .control)
      XCTAssertEqual("", app.client.string, "")
      XCTAssertEqual("", app.client.markedString(), "")
    }
  }

  func testCapslockRoman() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.qwerty.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiM)
      app.inputKey(.ansiR)
      app.inputKey(.ansi2)
      XCTAssertEqual("mr2", app.client.string, "buffer: \(app.client.string), app: \(app)")
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.qwerty.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiM, modifiers: .capsLock)
      app.inputKey(.ansiR, modifiers: .capsLock)
      app.inputKey(.ansi2, modifiers: .capsLock)
      XCTAssertEqual("MR2", app.client.string, "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testHanjaSyllable() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiM)
      app.inputKey(.ansiF)
      app.inputKey(.ansiS)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "韓: 나라 이름 한"))
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "韓: 나라 이름 한"))
      XCTAssertEqual("韓", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testHanjaWord() {
    for app in apps {
      if app == terminal {
        continue  // 터미널은 한자 모드 진입이 불가능
      }
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      // hanja search mode
      app.inputText("\n", key: .return, modifiers: .option)
      app.inputKey(.ansiI)
      app.inputKey(.ansiB)
      app.inputKey(.ansiW)
      XCTAssertEqual("물", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("물 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputKey(.ansiN)
      app.inputKey(.ansiB)
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("水", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")

      // 연달아 다음 한자 입력에 들어간다
      app.inputText(" ", key: .space)
      XCTAssertEqual("水 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputKey(.ansiI)
      XCTAssertEqual("水 ㅁ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("ㅁ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputKey(.ansiB)
      app.inputKey(.ansiW)
      XCTAssertEqual("水 물", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("水 물 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputKey(.ansiN)
      app.inputKey(.ansiB)
      XCTAssertEqual("水 물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("水 물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("水 水", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testHanjaBlank() {
    for app in apps {
      if app == terminal {
        continue  // 터미널은 한자 모드 진입이 불가능
      }
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      // hanja search mode
      app.inputText("\n", key: .return, modifiers: .option)
      app.inputText(" ", key: .space)
      app.inputKey(.ansiA)
      app.inputKey(.ansiN)
      app.inputKey(.ansiF)
      XCTAssertEqual(" 물", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual(" 물 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputKey(.ansiT)
      app.inputKey(.ansiN)
      app.inputText(" ", key: .space)
      XCTAssertEqual(" 물 수 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수 ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual(" 물 수 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수 ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual(" 水", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testHanjaSelection() {
    for app in apps {
      if app == terminal {
        continue  // 터미널은 한자 모드 진입이 불가능
      }
      app.client.string = "물 수"
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue,
        forTag: kTextServiceInputModePropertyTag, client: app.client)
      app.client.setSelectedRange(NSMakeRange(0, 3))
      XCTAssertEqual("물 수", app.client.selectedString(), "")
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("水", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testHanjaEscapeSyllable() {
    for app in apps {
      if app == terminal {
        continue  // 터미널은 한자 모드 진입이 불가능
      }
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiG)
      app.inputKey(.ansiK)
      app.inputKey(.ansiS)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "韓: 나라 이름 한"))
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      // Escape from Hanja mode
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testHanjaEscapeWord() {
    for app in apps {
      if app == terminal {
        continue  // 터미널은 한자 모드 진입이 불가능
      }
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      // hanja search mode
      app.inputText("\n", key: .return, modifiers: .option)
      app.inputKey(.ansiA)
      app.inputKey(.ansiN)
      app.inputKey(.ansiF)
      XCTAssertEqual("물", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("물 ", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 ", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.inputKey(.ansiT)
      app.inputKey(.ansiN)
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
      // Escape from Hanja mode
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string), app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string), app: \(app)")
    }
  }

  func testHanjaEscapeSelection() {
    for app in apps {
      if app == terminal {
        continue  // 터미널은 한자 모드 진입이 불가능
      }
      app.client.string = "물 수"
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.client.setSelectedRange(NSMakeRange(0, 3))
      XCTAssertEqual("물 수", app.client.selectedString(), "")
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "水: 물 수, 고를 수"))
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("물 수", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      // Escape from Hanja mode
      app.inputText("\n", key: .return, modifiers: .option)
      XCTAssertEqual("물 수", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testBackQuoteHan2() {
    Configuration.shared.hangulWonCurrencySymbolForBackQuote = true
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiGrave)
      XCTAssertEqual("₩", app.client.string, "buffer: \(app.client.string) app: \(app)")

      app.inputKey(.ansiGrave, modifiers: .shift)
      XCTAssertEqual("₩~", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testBackQuoteOnComposing() {
    Configuration.shared.hangulWonCurrencySymbolForBackQuote = true
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiR)
      app.inputKey(.ansiK)
      XCTAssertEqual("가", app.client.string, "buffer: \(app.client.string) app: \(app)")

      app.inputKey(.ansiGrave)
      XCTAssertEqual("가₩", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testBackQuoteQwerty() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.qwerty.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiGrave)
      XCTAssertEqual("`", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testBackQuoteHan3Final() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputText("`", key: .ansiGrave)
      XCTAssertEqual("*", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testBackQuoteHan3Classic() {
    // 세벌식 옛글에서 역따옴표는 종성으로 매핑되어 있어 커밋 없이 조합만 진행된다.
    Configuration.shared.hangulWonCurrencySymbolForBackQuote = true
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3Classic.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiGrave)
      XCTAssertEqual("\u{11F9}", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "\u{11F9}", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testDvorak() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        "org.youknowone.inputmethod.Gureum.dvorak", forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiJ)
      app.inputKey(.ansiD)
      app.inputKey(.ansiP)
      app.inputKey(.ansiP)
      app.inputKey(.ansiS)
      XCTAssertEqual("hello", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func test3Number() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        "org.youknowone.inputmethod.Gureum.han3final", forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiK, modifiers: .shift)
      XCTAssertEqual("2", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testBlock() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        "org.youknowone.inputmethod.Gureum.qwerty", forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiM)
      app.inputKey(.ansiF)
      app.inputKey(.ansiS)
      app.inputKey(.ansiK)
      app.inputKey(.ansiG)
      app.inputKey(.ansiW)
      XCTAssertEqual("mfskgw", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText(" ", key: .space)

      app.inputText("", key: .leftArrow)
      app.inputText("", key: .leftArrow)
      app.inputText("", key: .leftArrow)
      app.inputText("", key: .leftArrow)
      app.inputText("", key: .leftArrow)
      app.inputText("", key: .leftArrow)
    }
  }

  func testSequentialAutoReorderIsDisabledByDefault() {
    XCTAssertFalse(Configuration.shared.hangulAutoReorder)
  }

  func testSequentialSebeolsikFinalKeepsVowelBeforeInitialSeparateWhenReorderIsDisabled() {
    let previousAutoReorder = Configuration.shared.hangulAutoReorder
    Configuration.shared.hangulAutoReorder = false
    defer { Configuration.shared.hangulAutoReorder = previousAutoReorder }

    for app in apps {
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKeys("fk")

      XCTAssertEqual("ㅏㄱ", app.client.string)
      XCTAssertEqual("ㄱ", app.client.markedString())
    }
  }

  func testSequentialSebeolsikFinalCombinesInitialBeforeVowelWhenReorderIsDisabled() {
    let previousAutoReorder = Configuration.shared.hangulAutoReorder
    Configuration.shared.hangulAutoReorder = false
    defer { Configuration.shared.hangulAutoReorder = previousAutoReorder }

    for app in apps {
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKeys("kf")

      XCTAssertEqual("가", app.client.string)
      XCTAssertEqual("가", app.client.markedString())
    }
  }

  func testSequentialSebeolsikFinalCombinesVowelBeforeInitialWhenReorderIsEnabled() {
    let previousAutoReorder = Configuration.shared.hangulAutoReorder
    Configuration.shared.hangulAutoReorder = true
    defer { Configuration.shared.hangulAutoReorder = previousAutoReorder }

    for app in apps {
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKeys("fk")

      XCTAssertEqual("가", app.client.string)
      XCTAssertEqual("가", app.client.markedString())
    }
  }

  func testSequentialSebeolsikFinalCombinesInitialBeforeVowelWhenReorderIsEnabled() {
    let previousAutoReorder = Configuration.shared.hangulAutoReorder
    Configuration.shared.hangulAutoReorder = true
    defer { Configuration.shared.hangulAutoReorder = previousAutoReorder }

    for app in apps {
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKeys("kf")

      XCTAssertEqual("가", app.client.string)
      XCTAssertEqual("가", app.client.markedString())
    }
  }

  func test3final() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        "org.youknowone.inputmethod.Gureum.han3final", forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiM)
      app.inputKey(.ansiF)
      app.inputKey(.ansiS)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiK)
      XCTAssertEqual("한ㄱ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㄱ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiG)
      XCTAssertEqual("한그", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("그", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiW)
      XCTAssertEqual("한글", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("글", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("한글 ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiM)
      XCTAssertEqual("한글 ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㅎ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiF)
      app.inputKey(.ansiS)
      XCTAssertEqual("한글 한", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiK)
      XCTAssertEqual("한글 한ㄱ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㄱ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiG)
      app.inputKey(.ansiW)
      XCTAssertEqual("한글 한글", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("글", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText("\n", key: .return)
      if app != terminal {
        XCTAssertEqual("한글 한글\n", app.client.string, "buffer: \(app.client.string) app: \(app)")
      }
    }
  }

  func testColemak() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.colemak.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiH)
      app.inputKey(.ansiK)
      app.inputKey(.ansiU)
      app.inputKey(.ansiU)
      app.inputKey(.ansiSemicolon)
      app.inputKey(.ansiSlash, modifiers: .shift)
      XCTAssertEqual("hello?", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func test2() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiG)
      app.inputKey(.ansiK)
      app.inputKey(.ansiS)
      XCTAssertEqual("한", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiR)
      XCTAssertEqual("한ㄱ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㄱ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiM)
      app.inputKey(.ansiF)
      XCTAssertEqual("한글", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("글", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("한글 ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")

      app.inputKey(.ansiG)
      XCTAssertEqual("한글 ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㅎ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiK)
      app.inputKey(.ansiS)
      XCTAssertEqual("한글 한", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("한", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiR)
      XCTAssertEqual("한글 한ㄱ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㄱ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiM)
      app.inputKey(.ansiF)
      XCTAssertEqual("한글 한글", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("글", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText("\n", key: .return)
      if app != terminal {
        XCTAssertEqual("한글 한글\n", app.client.string, "buffer: \(app.client.string) app: \(app)")
      }
    }
  }

  func testCapslockHangul() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiM)
      app.inputKey(.ansiR)
      app.inputKey(.ansi2)
      XCTAssertEqual("했", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("했", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")

      app.inputText(" ", key: .space)

      app.client.string = ""
      app.inputKey(.ansiM, modifiers: .capsLock)
      app.inputKey(.ansiR, modifiers: .capsLock)
      app.inputKey(.ansi2, modifiers: .capsLock)
      XCTAssertEqual("했", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("했", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testRomanEmoticon() {
    for app in apps {
      if app == terminal {
        continue
      }
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.qwerty.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      let composer = app.controller.receiver.composer
      let emoticonComposer = composer.searchComposer
      emoticonComposer.delegate = composer.delegate
      composer.delegate = emoticonComposer

      app.inputKey(.ansiS)
      app.inputKey(.ansiL)
      app.inputKey(.ansiE)
      app.inputKey(.ansiE)
      app.inputKey(.ansiP)
      app.inputKey(.ansiY)
      XCTAssertEqual("sleepy", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "sleepy", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("sleepy ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "sleepy ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiF)
      app.inputKey(.ansiA)
      app.inputKey(.ansiC)
      app.inputKey(.ansiE)
      XCTAssertEqual("sleepy face", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "sleepy face", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "😪: sleepy face"))
      XCTAssertEqual("sleepy face", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "sleepy face", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "😪: sleepy face"))
      XCTAssertEqual("😪", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")

      app.client.string = ""
      app.inputKey(.ansiH)
      app.inputKey(.ansiU)
      app.inputKey(.ansiS)
      app.inputKey(.ansiH)
      app.inputKey(.ansiE)
      app.inputKey(.ansiD)
      XCTAssertEqual("hushed", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "hushed", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText(" ", key: .space)
      XCTAssertEqual("hushed ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "hushed ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiF)
      app.inputKey(.ansiA)
      app.inputKey(.ansiC)
      app.inputKey(.ansiE)
      XCTAssertEqual("hushed face", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "hushed face", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelectionChanged(NSAttributedString(string: "😯: hushed face"))
      XCTAssertEqual("hushed face", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual(
        "hushed face", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.controller.candidateSelected(NSAttributedString(string: "😯:, hushed face"))
      XCTAssertEqual("😯", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testHan3UnicodeArea() {
    for app in apps {
      // 두벌식 ㅑㄴ
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiI)
      app.inputKey(.ansiS)
      XCTAssertEqual("ㅑㄴ", app.client.string, "buffer: \(app.client.string) app: \(app)")

      let han2 = app.client.string
      app.inputText(" ", key: .space)

      // 세벌식 ㅑㄴ
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3FinalNoShift.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansi6)
      app.inputKey(.ansiS)
      XCTAssertEqual(han2, app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testViModeEscape() {
    XCTAssertFalse(Configuration.shared.romanModeByEscapeKey)
    Configuration.shared.romanModeByEscapeKey = true
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3FinalNoShift.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiM)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")

      let processed = app.inputKey(.escape)
      XCTAssertFalse(processed)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("qwerty"))
    }
  }

  func testViModeCtrlAndLeftBracket() {
    XCTAssertFalse(Configuration.shared.romanModeByEscapeKey)
    Configuration.shared.romanModeByEscapeKey = true
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3FinalNoShift.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiM)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")

      let processed = app.inputKey(.ansiLeftBracket, modifiers: [.control])
      XCTAssertFalse(processed)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("qwerty"))

      app.inputKey(.ansiLeftBracket, modifiers: [.control, .shift])
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertTrue(app.controller.receiver.composer.inputMode.hasSuffix("qwerty"))
    }
  }

  func testHanClassic() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han3Classic.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)

      app.inputKey(.ansiM)
      XCTAssertEqual("ㅎ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiF)
      XCTAssertEqual("하", app.client.string, "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiF)
      XCTAssertEqual("ᄒᆞ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      app.inputKey(.ansiS)
      XCTAssertEqual("ᄒᆞᆫ", app.client.string, "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testHanDelete() {
    for app in apps {
      app.client.string = ""
      app.controller.setValue(
        GureumInputSource.han2.rawValue, forTag: kTextServiceInputModePropertyTag,
        client: app.client)
      app.inputKey(.ansiD)
      XCTAssertEqual("ㅇ", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("ㅇ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
      app.inputText("", key: .delete)
      XCTAssertEqual("", app.client.string, "buffer: \(app.client.string) app: \(app)")
      XCTAssertEqual("", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    }
  }

  func testSearchPool() {
    for (pool, key, test) in [
      (SearchSourceConst.emojiKorean, "사과", "사과"),
      (SearchSourceConst.hanjaReversed, "물 수", "水"),
    ] {
      let workItem = DispatchWorkItem {}
      let candidates = pool.collect(key, workItem: workItem)
      let c = candidates[0]
      XCTAssertTrue(c.candidate.value == test || c.candidate.description.contains(test))
    }
  }

  func testSearchPoolWithoutDuplicate() {
    for (pool, key, test) in [
      (SearchSourceConst.koreanSingle, "구", "九")
    ] {
      let workItem = DispatchWorkItem {}
      let candidates = pool.collect(key, workItem: workItem)
      XCTAssertEqual(1, candidates.filter { $0.candidate.value == test }.count)
    }
  }

  //    func testSelection() {
  //        for app in apps {
  //            app.client.string = "한"
  //            app.controller.setValue(GureumInputSourceIdentifier.han2.rawValue, forTag: kTextServiceInputModePropertyTag, client: app.client)
  //            _ = app.inputKey(kVK_ANSI_D)
  //            XCTAssertEqual("한ㅇ", app.client.string, "buffer: \(app.client.string) app: \(app)")
  //            XCTAssertEqual("ㅇ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
  //            app.client.setSelectedRange(NSRange(location: 0, length: 0))
  //            _ = app.inputKey(kVK_ANSI_R)
  //            XCTAssertEqual("ㄱ한ㅇ", app.client.string, "buffer: \(app.client.string) app: \(app)")
  //            XCTAssertEqual("ㄱ", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
  //        }
  //    }
}

class InputMethodIdentityTests: XCTestCase {
  private let sourceSuffixes: [(GureumInputSource, String)] = [
    (.system, "system"), (.qwerty, "qwerty"), (.dvorak, "dvorak"), (.colemak, "colemak"),
    (.han2, "han2"), (.han2Classic, "han2classic"), (.han3Final, "han3final"),
    (.han390, "han390"), (.han3NoShift, "han3noshift"), (.han3Classic, "han3classic"),
    (.han3Layout2, "han3layout2"), (.hanAhnmatae, "hanahnmatae"), (.hanRoman, "hanroman"),
    (.han3FinalNoShift, "han3finalnoshift"), (.han32011, "han3-2011"), (.han32012, "han3-2012"),
  ]

  private func identity(infoDictionary: [String: Any] = [:]) throws -> InputMethodIdentity {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
    let contents = directory.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    addTeardownBlock { try FileManager.default.removeItem(at: directory) }
    let data = try PropertyListSerialization.data(
      fromPropertyList: infoDictionary, format: .xml, options: 0)
    try data.write(to: contents.appendingPathComponent("Info.plist"))
    return InputMethodIdentity(bundle: try XCTUnwrap(Bundle(url: directory)))
  }

  private func labIdentity() throws -> InputMethodIdentity {
    try identity(infoDictionary: [
      "GureumInputSourcePrefix": "io.github.kathar0s.inputmethod.GureumChordLab",
      "GureumDefaultsSuiteName": "io.github.kathar0s.GureumChordLab",
      "GureumChordLab": true,
    ])
  }

  func testMissingBundleMetadataPreservesUpstreamIdentity() throws {
    let identity = try identity()

    XCTAssertEqual(identity.inputSourcePrefix, "org.youknowone.inputmethod.Gureum")
    XCTAssertEqual(identity.defaultsSuiteName, "org.youknowone.Gureum")
    XCTAssertFalse(identity.isChordLab)
  }

  func testLabBundleMetadataSelectsLabIdentity() throws {
    let identity = try labIdentity()

    XCTAssertEqual(identity.inputSourcePrefix, "io.github.kathar0s.inputmethod.GureumChordLab")
    XCTAssertEqual(identity.defaultsSuiteName, "io.github.kathar0s.GureumChordLab")
    XCTAssertTrue(identity.isChordLab)
  }

  func testUpstreamInputSourceIdentifiersRetainTheirExistingValues() throws {
    let identity = try identity()
    XCTAssertEqual(sourceSuffixes.count, GureumInputSource.allCases.count)

    for (source, suffix) in sourceSuffixes {
      XCTAssertEqual(
        source.identifier(for: identity), "org.youknowone.inputmethod.Gureum.\(suffix)")
    }
  }

  func testAllInputSourcesRoundTripUnderUpstreamAndLabIdentities() throws {
    for identity in try [identity(), labIdentity()] {
      for source in GureumInputSource.allCases {
        let identifier = source.identifier(for: identity)

        XCTAssertEqual(GureumInputSource(rawValue: identifier, identity: identity), source)
      }
    }
  }

  func testInputSourceRawValuesUseTheCurrentBundleIdentity() {
    for (source, suffix) in sourceSuffixes {
      XCTAssertEqual(source.rawValue, InputMethodIdentity.current.identifier(for: suffix))
      XCTAssertEqual(GureumInputSource(rawValue: source.rawValue), source)
    }
  }

  func testInputSourcesRejectIdentifiersFromTheOtherProduct() throws {
    let upstream = try identity()
    let lab = try labIdentity()

    for source in GureumInputSource.allCases {
      XCTAssertNil(
        GureumInputSource(rawValue: source.identifier(for: lab), identity: upstream))
      XCTAssertNil(
        GureumInputSource(rawValue: source.identifier(for: upstream), identity: lab))
    }
  }

  func testInputSourcesRejectUnknownSuffixes() throws {
    for identity in try [identity(), labIdentity()] {
      XCTAssertNil(
        GureumInputSource(rawValue: identity.identifier(for: "unknown"), identity: identity))
    }
  }

  func testLabAndUpstreamSettingsUseIndependentDefaultsSuites() throws {
    let upstreamIdentity = try identity()
    let labIdentity = try labIdentity()
    XCTAssertNotEqual(upstreamIdentity.defaultsSuiteName, labIdentity.defaultsSuiteName)

    let testSuffix = ".test.\(UUID().uuidString)"
    let upstreamSuite = upstreamIdentity.defaultsSuiteName + testSuffix
    let labSuite = labIdentity.defaultsSuiteName + testSuffix
    let upstream = try XCTUnwrap(Configuration(suiteName: upstreamSuite))
    let lab = try XCTUnwrap(Configuration(suiteName: labSuite))
    defer {
      upstream.removePersistentDomain(forName: upstreamSuite)
      lab.removePersistentDomain(forName: labSuite)
    }

    upstream.hangulAutoReorder = false
    lab.hangulAutoReorder = true

    XCTAssertFalse(upstream.hangulAutoReorder)
    XCTAssertTrue(lab.hangulAutoReorder)
  }

  func testUpstreamRecognizedEventsDoNotRequestKeyUp() throws {
    let app = ModerateApp()
    let mask = app.controller.receiver.recognizedEvents(app.client, identity: try identity())

    XCTAssertTrue(mask.contains(.keyDown))
    XCTAssertFalse(mask.contains(.keyUp))
  }

  func testLabRecognizedEventsRequestKeyUpOnlyInDebugBuilds() throws {
    let app = ModerateApp()
    let mask = app.controller.receiver.recognizedEvents(app.client, identity: try labIdentity())

    XCTAssertTrue(mask.contains(.keyDown))
    #if DEBUG
      XCTAssertTrue(mask.contains(.keyUp))
    #else
      XCTAssertFalse(mask.contains(.keyUp))
    #endif
  }

  func testLabRecognizedEventsOnlyDifferFromUpstreamInDebugBuilds() throws {
    let app = ModerateApp()
    let receiver = app.controller.receiver!
    let upstream = receiver.recognizedEvents(app.client, identity: try identity())
    let lab = receiver.recognizedEvents(app.client, identity: try labIdentity())

    #if DEBUG
      XCTAssertEqual(lab.subtracting(upstream), .keyUp)
    #else
      XCTAssertEqual(lab, upstream)
    #endif
    XCTAssertEqual(upstream.subtracting(lab), [])
  }
}

private final class FakePhysicalKeyEventSource: PhysicalKeyEventSourceProtocol {
  var status: PhysicalKeySourceStatus = .healthy
  var permissionGranted = true
  var secureInputEnabled = false
  var refreshAction: (() -> Void)?
  private(set) var startCallCount = 0
  private(set) var stopCallCount = 0
  private var leases: Set<UUID> = []
  var activeLeaseCount: Int { leases.count }
  private var observers: [UUID: (PhysicalKeySourceEvent) -> Void] = [:]

  func acquireLease(_ token: UUID) {
    if leases.isEmpty { startCallCount += 1 }
    leases.insert(token)
  }
  func releaseLease(_ token: UUID) {
    guard leases.remove(token) != nil else { return }
    if leases.isEmpty { stopCallCount += 1 }
  }
  func refresh() { refreshAction?() }
  func addObserver(_ observer: @escaping (PhysicalKeySourceEvent) -> Void) -> UUID {
    let token = UUID()
    observers[token] = observer
    return token
  }
  func removeObserver(_ token: UUID) { observers.removeValue(forKey: token) }
  func emit(_ event: PhysicalKeySourceEvent) {
    for observer in Array(observers.values) { observer(event) }
  }
}

private final class ChordCoordinatorFixture {
  final class State {
    var now: TimeInterval = 0
    var enabled = true
    var replayed: [ChordStroke] = []
    var disabled: [ChordFlushReason] = []
    var outcome = ChordTerminalOutcome.composerReplay
  }

  let source = FakePhysicalKeyEventSource()
  let state = State()
  let coordinator: ChordInputCoordinator

  init(
    enabled: Bool = true, watchdog: TimeInterval = 2, maxOrphans: Int = 32, maxStrokes: Int = 64,
    acceptsRelease: @escaping (Int) -> Bool = { _ in true }
  ) {
    let state = state
    state.enabled = enabled
    coordinator = ChordInputCoordinator(
      source: source, clock: { state.now }, isEnabled: { state.enabled },
      acceptsRelease: acceptsRelease, watchdog: watchdog,
      orphanLifetime: 0.25, maxOrphans: maxOrphans, maxStrokes: maxStrokes,
      onDisabled: { state.disabled.append($0) },
      replay: {
        state.replayed.append($0)
        return state.outcome
      })
    coordinator.activate()
  }

  @discardableResult func press(
    _ keyCode: Int, at timestamp: TimeInterval = 0, isRepeat: Bool = false
  ) -> Bool {
    coordinator.consume(
      keyCode: keyCode, text: "key\(keyCode)", modifiers: 0, timestamp: timestamp,
      isRepeat: isRepeat)
  }

  func release(_ keyCode: Int, at timestamp: TimeInterval = 0.1) {
    source.emit(.keyUp(keyCode: keyCode, timestamp: timestamp))
  }
}

class ChordInputCoordinatorTests: XCTestCase {
  func testLeaseStopsOnLastDeactivationAndRestartsOnActivation() {
    let fixture = ChordCoordinatorFixture()
    XCTAssertEqual(fixture.source.activeLeaseCount, 1)
    XCTAssertEqual(fixture.source.startCallCount, 1)

    fixture.coordinator.deactivate()
    XCTAssertEqual(fixture.source.activeLeaseCount, 0)
    XCTAssertEqual(fixture.source.stopCallCount, 1)
    fixture.coordinator.activate()
    XCTAssertEqual(fixture.source.activeLeaseCount, 1)
    XCTAssertEqual(fixture.source.startCallCount, 2)
  }

  func testFatalWatchdogReleasesTheSourceLease() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.coordinator.checkTimeout(now: 2)

    XCTAssertEqual(fixture.source.activeLeaseCount, 0)
    XCTAssertEqual(fixture.source.stopCallCount, 1)
    XCTAssertEqual(fixture.coordinator.disabledReason, .watchdog)
  }

  func testTrailingUnconsumedShortcutReleaseIsIgnoredAfterBoundary() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.coordinator.flushBoundary(.shortcut, ignoringReleaseOf: 2, timestamp: 0.01)
    fixture.release(1, at: 0.02)
    fixture.release(2, at: 0.03)
    fixture.coordinator.checkTimeout(now: 0.4)

    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertEqual(fixture.source.activeLeaseCount, 1)
    XCTAssertTrue(fixture.press(3, at: 0.5))
    fixture.release(3, at: 0.6)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 3])
  }

  func testSourceEventsAfterDeactivationDoNotBufferOrReplay() {
    let fixture = ChordCoordinatorFixture()
    fixture.coordinator.deactivate()
    fixture.release(1)
    fixture.source.emit(.heartbeat(timestamp: 5))

    XCTAssertEqual(fixture.source.activeLeaseCount, 0)
    XCTAssertTrue(fixture.state.replayed.isEmpty)
    XCTAssertEqual(fixture.coordinator.bufferedStrokeCount, 0)
    XCTAssertEqual(fixture.coordinator.terminalCount, 0)
  }

  func testIneligibleReleaseNeverBecomesAnExpiringOrphan() {
    let fixture = ChordCoordinatorFixture(acceptsRelease: { $0 != KeyCode.space.rawValue })
    fixture.release(KeyCode.space.rawValue)

    fixture.coordinator.checkTimeout(now: 0.25)

    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
    XCTAssertTrue(fixture.press(KeyCode.ansiK.rawValue, at: 0.3))
    fixture.release(KeyCode.ansiK.rawValue, at: 0.4)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [KeyCode.ansiK.rawValue])
  }

  func testReactivationFlushesThePreviousGroupBeforeAcceptingNewInput() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)

    fixture.coordinator.activate()

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.recentTerminations.map(\.reason), [.clientChanged])
    XCTAssertEqual(fixture.coordinator.outstandingStrokeCount, 0)
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertTrue(fixture.press(2, at: 0.2))
    fixture.release(2, at: 0.3)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2])
    XCTAssertEqual(fixture.coordinator.terminalCount, fixture.coordinator.consumedStrokeCount)
  }

  func testDisabledModeNeverStartsThePhysicalEventSource() {
    let fixture = ChordCoordinatorFixture(enabled: false)

    XCTAssertEqual(fixture.source.startCallCount, 0)
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertFalse(fixture.coordinator.isActive)
    XCTAssertFalse(fixture.press(1))
  }

  func testReactivationAfterOptOutDoesNotRestartThePhysicalEventSource() {
    let fixture = ChordCoordinatorFixture()
    XCTAssertEqual(fixture.source.startCallCount, 1)
    fixture.coordinator.deactivate()
    fixture.state.enabled = false

    fixture.coordinator.activate()

    XCTAssertEqual(fixture.source.startCallCount, 1)
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertFalse(fixture.coordinator.isActive)
  }

  func testDisabledModePassesThroughWithoutConsuming() {
    let fixture = ChordCoordinatorFixture()
    fixture.state.enabled = false

    XCTAssertFalse(fixture.press(1))
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertFalse(fixture.coordinator.isActive)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
  }

  func testUnhealthySourcePassesThroughWithoutConsuming() {
    let fixture = ChordCoordinatorFixture()
    fixture.source.status = .unavailable

    XCTAssertFalse(fixture.press(1))
    XCTAssertEqual(fixture.coordinator.disabledReason, .tapDisabled)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
  }

  func testDisablingModeFlushesBeforePassingThroughTheNextDown() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.state.enabled = false

    XCTAssertFalse(fixture.press(2, at: 0.01))

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertFalse(fixture.coordinator.isActive)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 1)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
  }

  func testPermissionDeniedPassesThroughWithoutConsuming() {
    let fixture = ChordCoordinatorFixture()
    fixture.source.permissionGranted = false

    XCTAssertFalse(fixture.press(1))
    XCTAssertEqual(fixture.coordinator.disabledReason, .permissionLost)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
  }

  func testPermissionRevocationFlushesBufferedStrokeExactlyOnce() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.source.permissionGranted = false
    fixture.source.emit(.statusChanged(.permissionDenied))
    fixture.release(1)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .permissionLost)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
    XCTAssertEqual(fixture.coordinator.outstandingStrokeCount, 0)
  }

  func testPermissionLossDuringRefreshFlushesBeforeRejectingNextDown() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    let source = fixture.source
    source.refreshAction = { [weak source] in source?.permissionGranted = false }

    XCTAssertFalse(fixture.press(2, at: 0.01))

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .permissionLost)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 1)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
  }

  func testSecureInputFlushesAndDisablesBuffering() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.source.secureInputEnabled = true
    fixture.coordinator.checkTimeout(now: 0.1)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .secureInput)
    XCTAssertFalse(fixture.press(2))
  }

  func testTapDisableFlushesAndDisablesBuffering() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.source.emit(.statusChanged(.tapDisabled))

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .tapDisabled)
    XCTAssertFalse(fixture.press(2))
  }

  func testSourceStopFlushesAndDisablesBuffering() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.source.emit(.statusChanged(.stopped))

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertFalse(fixture.coordinator.isActive)
  }

  func testKeyReleaseAfterDownCompletesOneStroke() {
    let fixture = ChordCoordinatorFixture()
    XCTAssertTrue(fixture.press(1))
    XCTAssertEqual(fixture.coordinator.bufferedStrokeCount, 1)
    XCTAssertTrue(fixture.state.replayed.isEmpty)

    fixture.release(1)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.bufferedStrokeCount, 0)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
  }

  func testKeyReleaseArrivingBeforeImkDownMatchesByTimestamp() {
    let fixture = ChordCoordinatorFixture()
    fixture.release(1, at: 0.1)

    XCTAssertTrue(fixture.press(1, at: 0.05))

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
    XCTAssertNil(fixture.coordinator.disabledReason)
  }

  func testOverlappingKeysWaitForFinalReleaseAndPreservePressOrder() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(3)
    fixture.press(1, at: 0.01)
    fixture.release(3, at: 0.02)
    XCTAssertTrue(fixture.state.replayed.isEmpty)

    fixture.release(1, at: 0.03)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [3, 1])
    XCTAssertEqual(fixture.coordinator.terminalCount, 2)
  }

  func testReverseReleaseOrderPreservesOriginalPressOrder() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(3)
    fixture.press(1, at: 0.01)
    fixture.release(1, at: 0.02)
    fixture.release(3, at: 0.03)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [3, 1])
  }

  func testRollingOverlapStaysInOneGroupUntilHeldSetIsEmpty() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.press(2, at: 0.01)
    fixture.release(1, at: 0.02)
    fixture.press(3, at: 0.03)
    fixture.release(2, at: 0.04)
    XCTAssertTrue(fixture.state.replayed.isEmpty)

    fixture.release(3, at: 0.05)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2, 3])
  }

  func testBrokenOverlapChainCompletesBeforeNextGroup() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.release(1, at: 0.01)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])

    fixture.press(2, at: 0.02)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    fixture.release(2, at: 0.03)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2])
  }

  func testRepressAfterReleaseAddsDistinctStrokeWhileAnotherKeyIsHeld() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.press(2, at: 0.01)
    fixture.release(1, at: 0.02)
    fixture.press(1, at: 0.03)
    fixture.release(2, at: 0.04)
    fixture.release(1, at: 0.05)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2, 1])
    XCTAssertEqual(fixture.state.replayed.map(\.id), [1, 2, 3])
  }

  func testAutoRepeatIsAccountedForWithoutDuplicatingReplay() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.press(1, at: 0.01, isRepeat: true)
    fixture.release(1, at: 0.02)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 2)
    XCTAssertEqual(fixture.coordinator.terminalCount, 2)
    XCTAssertEqual(
      fixture.coordinator.recentTerminations.map(\.outcome), [.repeatSuppression, .composerReplay])
  }

  func testRepeatWithoutHeldKeyPassesThroughWithoutConsumption() {
    let fixture = ChordCoordinatorFixture()

    XCTAssertFalse(fixture.press(1, isRepeat: true))
    XCTAssertEqual(fixture.coordinator.disabledReason, .unmatchedEvent)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
  }

  func testDuplicateNonRepeatDownFlushesBothStrokesAndDisables() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.press(1, at: 0.01)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .unmatchedEvent)
    XCTAssertEqual(fixture.coordinator.terminalCount, 2)
  }

  func testGroupOverflowFlushesEveryConsumedStroke() {
    let fixture = ChordCoordinatorFixture(maxStrokes: 2)
    fixture.press(1)
    fixture.press(2, at: 0.01)
    fixture.press(3, at: 0.02)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2, 3])
    XCTAssertEqual(fixture.coordinator.disabledReason, .groupOverflow)
    XCTAssertEqual(fixture.coordinator.terminalCount, fixture.coordinator.consumedStrokeCount)
    XCTAssertEqual(fixture.coordinator.outstandingStrokeCount, 0)
  }

  func testOrphanOverflowDisablesWithoutConsumingInput() {
    let fixture = ChordCoordinatorFixture(maxOrphans: 1)
    fixture.release(1)
    fixture.release(2)

    XCTAssertEqual(fixture.coordinator.disabledReason, .orphanOverflow)
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
    XCTAssertTrue(fixture.state.replayed.isEmpty)
  }

  func testExpiredOrphanIsDroppedAndTheNextChordStillWorks() {
    let fixture = ChordCoordinatorFixture()
    fixture.release(1)
    fixture.coordinator.checkTimeout(now: 0.249)
    XCTAssertNil(fixture.coordinator.disabledReason)

    fixture.coordinator.checkTimeout(now: 0.25)

    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertEqual(fixture.coordinator.expiredOrphanCount, 1)
    XCTAssertTrue(fixture.press(2, at: 0.3))
    fixture.release(2, at: 0.4)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [2])
  }

  func testMissingReleaseWatchdogFlushesAtInclusiveDeadline() {
    let fixture = ChordCoordinatorFixture(watchdog: 2)
    fixture.press(1)
    fixture.coordinator.checkTimeout(now: 1.999)
    XCTAssertTrue(fixture.state.replayed.isEmpty)

    fixture.source.emit(.heartbeat(timestamp: 2))

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .watchdog)
    XCTAssertEqual(fixture.coordinator.recentTerminations.map(\.outcome), [.safetyFlush])
  }

  func testDeactivationFlushesAndPreventsFurtherConsumption() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.coordinator.deactivate()

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertNil(fixture.coordinator.disabledReason)
    XCTAssertFalse(fixture.coordinator.isActive)
    XCTAssertFalse(fixture.press(2))
  }

  func testActivatingAnotherClientFlushesOnlyTheOriginalClient() {
    let original = ChordCoordinatorFixture()
    original.press(1)

    let next = ChordCoordinatorFixture()

    XCTAssertEqual(original.state.replayed.map(\.keyCode), [1])
    XCTAssertNil(original.coordinator.disabledReason)
    XCTAssertFalse(original.coordinator.isActive)
    XCTAssertTrue(next.state.replayed.isEmpty)
    XCTAssertTrue(next.press(2))
    next.release(2)
    XCTAssertEqual(next.state.replayed.map(\.keyCode), [2])
  }

  func testOrdinaryBoundariesFlushAndAllowTheNextChord() {
    for reason: ChordFlushReason in [
      .layoutChanged, .mouse, .command, .shortcut, .candidate, .nonMappable,
    ] {
      let fixture = ChordCoordinatorFixture()
      fixture.press(3)
      fixture.press(1, at: 0.01)
      fixture.coordinator.flushBoundary(reason)

      XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [3, 1], reason.rawValue)
      XCTAssertNil(fixture.coordinator.disabledReason)
      XCTAssertTrue(fixture.coordinator.isActive)
      XCTAssertEqual(fixture.coordinator.terminalCount, fixture.coordinator.consumedStrokeCount)
      XCTAssertEqual(fixture.coordinator.outstandingStrokeCount, 0)
      fixture.release(3, at: 0.02)
      fixture.release(1, at: 0.03)
      XCTAssertTrue(fixture.press(2, at: 0.04))
      fixture.release(2, at: 0.05)
      XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [3, 1, 2])
      XCTAssertNil(fixture.coordinator.disabledReason)
    }
  }

  func testComposerReplayRecordsComposerOutcome() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.release(1)

    XCTAssertEqual(fixture.coordinator.recentTerminations.map(\.outcome), [.composerReplay])
  }

  func testLiteralFallbackRecordsLiteralOutcomeExactlyOnce() {
    let fixture = ChordCoordinatorFixture()
    fixture.state.outcome = .literalFallback
    fixture.press(1)
    fixture.release(1)

    XCTAssertEqual(fixture.coordinator.recentTerminations.map(\.outcome), [.literalFallback])
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
    XCTAssertEqual(fixture.coordinator.outstandingStrokeCount, 0)
  }

  func testFinalReleaseBeforeWatchdogTerminatesStrokeOnlyOnce() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.release(1, at: 2)
    fixture.coordinator.checkTimeout(now: 2)

    XCTAssertEqual(fixture.state.replayed.count, 1)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
    XCTAssertNil(fixture.coordinator.disabledReason)
  }

  func testWatchdogBeforeFinalReleaseTerminatesStrokeOnlyOnce() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.coordinator.checkTimeout(now: 2)
    fixture.release(1, at: 2)

    XCTAssertEqual(fixture.state.replayed.count, 1)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
    XCTAssertEqual(fixture.coordinator.disabledReason, .watchdog)
  }

  func testReleaseTimestampBeforeDownTriggersSafetyFlush() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1, at: 0.2)
    fixture.release(1, at: 0.1)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.disabledReason, .timestampMismatch)
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
  }

  func testDownTimestampBeforePreviousCompletionTriggersSafetyFlush() {
    let fixture = ChordCoordinatorFixture()
    fixture.press(1)
    fixture.release(1, at: 0.1)
    fixture.press(2, at: 0.05)

    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1, 2])
    XCTAssertEqual(fixture.coordinator.disabledReason, .timestampMismatch)
    XCTAssertEqual(fixture.coordinator.terminalCount, 2)
  }

  func testStaleOrphanDoesNotReleaseANewerPressOfTheSameKey() {
    let fixture = ChordCoordinatorFixture()
    fixture.release(1, at: 0.1)
    fixture.press(1, at: 0.2)

    XCTAssertTrue(fixture.state.replayed.isEmpty)
    XCTAssertEqual(fixture.coordinator.bufferedStrokeCount, 1)

    fixture.coordinator.checkTimeout(now: 0.25)

    XCTAssertTrue(fixture.state.replayed.isEmpty)
    XCTAssertEqual(fixture.coordinator.bufferedStrokeCount, 1)
    XCTAssertNil(fixture.coordinator.disabledReason)
    fixture.release(1, at: 0.3)
    XCTAssertEqual(fixture.state.replayed.map(\.keyCode), [1])
    XCTAssertEqual(fixture.coordinator.terminalCount, 1)
  }

  func testInvalidEventDoesNotConsumeOrBufferInput() {
    let fixture = ChordCoordinatorFixture()

    XCTAssertFalse(
      fixture.coordinator.consume(
        keyCode: 1, text: "", modifiers: 0, timestamp: 0, isRepeat: false))
    XCTAssertFalse(fixture.press(1, at: .nan))
    XCTAssertFalse(fixture.press(1, at: -1))
    XCTAssertEqual(fixture.coordinator.consumedStrokeCount, 0)
    XCTAssertEqual(fixture.coordinator.bufferedStrokeCount, 0)
  }
}

private final class ChordHandleTestController: InputController {
  var testClient: MockInputClient
  private var handlingEvent = false

  init(client: MockInputClient) {
    testClient = client
    super.init()
    receiver = InputReceiver(
      server: InputMethodServer.shared.server, delegate: client, client: client, controller: self)
  }

  override func client() -> (IMKTextInput & NSObjectProtocol)! {
    if handlingEvent { return testClient }
    return super.client() ?? testClient
  }

  override func handle(_ event: NSEvent, client sender: Any) -> Bool {
    handlingEvent = true
    defer { handlingEvent = false }
    return super.handle(event, client: sender)
  }

  override func selectionRange() -> NSRange { client().selectedRange() }

  override func updateComposition() {
    let target = client() as! MockInputClient
    let composed = receiver.composedString(target)
    target.setMarkedText(
      composed, selectedRange: NSRange(location: 0, length: composed.count),
      replacementRange: target.markedRange())
  }

  override func cancelComposition() {
    receiver.cancelCompositionEvent()
    let target = client() as! MockInputClient
    target.setMarkedText(
      "", selectedRange: NSRange(location: 0, length: 0), replacementRange: target.markedRange())
  }
}

private final class ChordHandleFixture {
  let source = FakePhysicalKeyEventSource()
  let state = ChordCoordinatorFixture.State()
  let client = MockInputClient()
  let controller: ChordHandleTestController

  init(enabled: Bool = true, layout: GureumInputSource = .han3Final) {
    controller = ChordHandleTestController(client: client)
    state.enabled = enabled
    let source = source
    let state = state
    controller.chordEnvironment = ChordControllerEnvironment(
      isLab: { true }, isEnabled: { state.enabled }, sourceFactory: { source }, clock: { state.now }
    )
    controller.setValue(layout.rawValue, forTag: kTextServiceInputModePropertyTag, client: client)
  }

  func activate() { controller.activatePhysicalInput(client: client) }

  @discardableResult func down(
    _ key: KeyCode, text: String, at timestamp: TimeInterval = 0,
    modifiers: NSEvent.ModifierFlags = []
  ) -> Bool {
    let event = NSEvent.keyEvent(
      with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: timestamp,
      windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text,
      isARepeat: false, keyCode: UInt16(key.rawValue))!
    return controller.handle(event, client: controller.testClient)
  }

  func release(_ key: KeyCode, at timestamp: TimeInterval = 0.1) {
    source.emit(.keyUp(keyCode: key.rawValue, timestamp: timestamp))
  }
}

class IsolatedChordConfigurationTests: XCTestCase {
  private let configurationSuite = "org.youknowone.Gureum.test.chord.\(UUID().uuidString)"
  private var previousConfiguration: Configuration!

  override func setUp() {
    super.setUp()
    previousConfiguration = Configuration.shared
    Configuration.shared = Configuration(suiteName: configurationSuite)!
  }

  override func tearDown() {
    Configuration.shared.removePersistentDomain(forName: configurationSuite)
    Configuration.shared = previousConfiguration
    previousConfiguration = nil
    super.tearDown()
  }
}

class ChordInputControllerTests: IsolatedChordConfigurationTests {
  func testEligibleHandleDefersComposerAndClientUntilRelease() {
    let fixture = ChordHandleFixture()
    fixture.activate()

    XCTAssertTrue(fixture.down(.ansiK, text: "k"))
    XCTAssertEqual(fixture.client.string, "")
    XCTAssertEqual(fixture.controller.receiver.composer.composedString, "")

    fixture.release(.ansiK)

    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertEqual(fixture.controller.chordCoordinator?.terminalCount, 1)
    XCTAssertEqual(fixture.controller.chordCoordinator?.outstandingStrokeCount, 0)
  }

  func testActivationCapturesReleaseArrivingBeforeFirstImkDown() {
    let fixture = ChordHandleFixture()
    fixture.activate()
    XCTAssertEqual(fixture.source.activeLeaseCount, 1)
    fixture.release(.ansiK, at: 0.1)

    XCTAssertTrue(fixture.down(.ansiK, text: "k", at: 0.05))

    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertEqual(fixture.controller.chordCoordinator?.terminalCount, 1)
    XCTAssertNil(fixture.controller.chordCoordinator?.disabledReason)
  }

  func testModeOffHandlesSequentialInputImmediatelyWithoutSourceLease() {
    let fixture = ChordHandleFixture(enabled: false)
    fixture.activate()

    XCTAssertTrue(fixture.down(.ansiK, text: "k"))

    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertEqual(fixture.source.startCallCount, 0)
    XCTAssertNil(fixture.controller.chordCoordinator)
  }

  func testIneligibleLayoutDoesNotAcquireSourceLease() {
    let fixture = ChordHandleFixture(layout: .han2)
    fixture.activate()

    XCTAssertTrue(fixture.down(.ansiR, text: "r"))

    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertEqual(fixture.source.startCallCount, 0)
    XCTAssertNil(fixture.controller.chordCoordinator)
  }

  func testPermissionDeniedUsesBaselineCompositionImmediately() {
    let fixture = ChordHandleFixture()
    fixture.source.permissionGranted = false
    fixture.activate()

    XCTAssertTrue(fixture.down(.ansiK, text: "k"))

    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertEqual(fixture.source.activeLeaseCount, 0)
    XCTAssertEqual(fixture.controller.chordCoordinator?.disabledReason, .permissionLost)
    XCTAssertEqual(fixture.controller.chordCoordinator?.consumedStrokeCount, 0)
  }

  func testCommandBoundaryFlushesAndTheNextChordStillDefers() {
    let fixture = ChordHandleFixture()
    fixture.activate()
    fixture.down(.ansiK, text: "k")

    XCTAssertFalse(fixture.down(.ansiA, text: "a", at: 0.01, modifiers: .command))
    fixture.release(.ansiK, at: 0.02)
    fixture.release(.ansiA, at: 0.03)
    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertNil(fixture.controller.chordCoordinator?.disabledReason)

    XCTAssertTrue(fixture.down(.ansiF, text: "f", at: 0.04))
    XCTAssertEqual(fixture.client.string, "ㄱ")
    fixture.release(.ansiF, at: 0.05)
    XCTAssertEqual(fixture.client.string, "ㄱㅏ")
  }

  func testClientRebindingCommitsOnlyToTheOriginalClient() {
    let fixture = ChordHandleFixture()
    fixture.activate()
    fixture.down(.ansiK, text: "k")
    let nextClient = MockInputClient()
    fixture.controller.testClient = nextClient

    fixture.controller.setValue(
      GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
      client: nextClient)

    XCTAssertEqual(fixture.client.string, "ㄱ")
    XCTAssertEqual(fixture.client.markedString(), "")
    XCTAssertEqual(nextClient.string, "")
    XCTAssertTrue(fixture.down(.ansiF, text: "f", at: 0.2))
    XCTAssertEqual(nextClient.string, "")
    fixture.release(.ansiF, at: 0.3)
    XCTAssertEqual(nextClient.string, "ㅏ")
    XCTAssertEqual(fixture.client.string, "ㄱ")
  }

  func testDeactivationReleasesLeaseAndReactivationRestartsIt() {
    let fixture = ChordHandleFixture()
    fixture.activate()
    XCTAssertEqual(fixture.source.activeLeaseCount, 1)

    fixture.controller.deactivatePhysicalInput()
    XCTAssertEqual(fixture.source.activeLeaseCount, 0)
    fixture.activate()
    XCTAssertEqual(fixture.source.activeLeaseCount, 1)
    XCTAssertEqual(fixture.source.startCallCount, 2)
  }
}

class PhysicalStrokeReplayTests: IsolatedChordConfigurationTests {
  private func finalApp() -> ModerateApp {
    let app = ModerateApp()
    app.controller.setValue(
      GureumInputSource.han3Final.rawValue, forTag: kTextServiceInputModePropertyTag,
      client: app.client)
    return app
  }

  func testPhysicalChordingIsDisabledByDefault() throws {
    let suite = "org.youknowone.Gureum.test.physical.\(UUID().uuidString)"
    let configuration = try XCTUnwrap(Configuration(suiteName: suite))
    defer { configuration.removePersistentDomain(forName: suite) }

    XCTAssertFalse(configuration.physicalChordingEnabled)
  }

  func testAcceptedReplayUsesTheExistingHangulComposer() {
    let app = finalApp()
    app.inputKeys("k")
    let stroke = ChordStroke(
      id: 1, keyCode: KeyCode.ansiF.rawValue, text: "f", modifiers: 0, timestamp: 0)

    let outcome = app.controller.replayPhysicalStroke(stroke, client: app.client)

    XCTAssertEqual(outcome, .composerReplay)
    XCTAssertEqual(app.client.string, "가")
    XCTAssertEqual(app.client.markedString(), "가")
    XCTAssertFalse(app.controller.receiver.inputting)
  }

  func testDeclinedReplayCommitsCompositionBeforeInsertingLiteralExactlyOnce() {
    let app = finalApp()
    app.inputKeys("kf")
    let stroke = ChordStroke(
      id: 1, keyCode: KeyCode.return.rawValue, text: "\n", modifiers: 0, timestamp: 0)

    let outcome = app.controller.replayPhysicalStroke(stroke, client: app.client)

    XCTAssertEqual(outcome, .literalFallback)
    XCTAssertEqual(app.client.string, "가\n")
    XCTAssertEqual(app.client.markedString(), "")
    XCTAssertFalse(app.controller.receiver.inputting)
  }

  func testUnknownKeyReplayInsertsLiteralIntoTheSuppliedClient() {
    let app = finalApp()
    let owner = MockInputClient()
    let stroke = ChordStroke(id: 1, keyCode: -1, text: "?", modifiers: 0, timestamp: 0)

    let outcome = app.controller.replayPhysicalStroke(stroke, client: owner)

    XCTAssertEqual(outcome, .literalFallback)
    XCTAssertEqual(owner.string, "?")
    XCTAssertEqual(app.client.string, "")
  }
}

class Han3FinalNoShiftTests: XCTestCase {
  let app = ModerateApp()

  override class func setUp() {
    Configuration.shared = Configuration(suiteName: "org.youknowone.Gureum.test")!
    super.setUp()
  }

  override class func tearDown() {
    super.tearDown()
  }

  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.

    Configuration.shared.removePersistentDomain(forName: GureumTests.domainName)

    app.client.string = ""
    app.controller.setValue(
      GureumInputSource.han3FinalNoShift.rawValue, forTag: kTextServiceInputModePropertyTag,
      client: app.client)
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    app.inputKey(.space)
    app.client.string = ""
    super.tearDown()
  }

  func testSymbol() {
    app.inputKey(.ansiQuote, modifiers: .shift)
    XCTAssertEqual("\"", app.client.string, "buffer: \(app.client.string) app: \(app)")
    app.client.string = ""
  }

  func testModeKeyAsSymbol() {
    app.inputKey(.ansiLeftBracket)
    XCTAssertEqual("[", app.client.string, "buffer: \(app.client.string) app: \(app)")
    XCTAssertEqual("[", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
    app.inputKey(.ansiLeftBracket)
    XCTAssertEqual("[[", app.client.string, "buffer: \(app.client.string) app: \(app)")
    XCTAssertEqual("[", app.client.markedString(), "buffer: \(app.client.string) app: \(app)")
  }

  func testBufferedJung() {
    app.test(input: "fd", expecteds: ["ㅏ", "ㅏㅣ"], markeds: ["ㅏ", "ㅏㅣ"])
    app.test(input: "fds", expecteds: ["ㅏ", "ㅏㅣ", "ㅏㅣㄴ"], markeds: ["ㅏ", "ㅏㅣ", "ㅣㄴ"])
    app.test(input: "fde", expecteds: ["ㅏ", "ㅏㅣ", "ㅏㅣㅕ"], markeds: ["ㅏ", "ㅏㅣ", "ㅣㅕ"])
    app.test(input: "fdk", expecteds: ["ㅏ", "ㅏㅣ", "ㅏ기"], markeds: ["ㅏ", "ㅏㅣ", "기"])
    app.test(input: "fdk", expecteds: ["ㅏ", "ㅏㅣ", "ㅏ기"], markeds: ["ㅏ", "ㅏㅣ", "기"])
    app.test(input: "fdsk", expecteds: ["ㅏ", "ㅏㅣ", "ㅏㅣㄴ", "ㅏ긴"], markeds: ["ㅏ", "ㅏㅣ", "ㅣㄴ", "긴"])
    app.test(
      input: "fsdk", expecteds: ["ㅏ", "ㅏㄴ", "ㅏㄴㅣ", "ㅏㄴ기"], markeds: ["ㅏ", "ㅏㄴ", "ㅣ", "기"],
      removeds: ["ㅏㄴㅣ", "ㅏㄴ"])
  }

  func test까() {
    app.test(input: "jkf", expecteds: [nil, nil, "까"])
    app.test(input: "kjf", expecteds: [nil, nil, "까"])
    app.test(input: "fkj", expecteds: [nil, nil, "까"])
    app.test(input: "fjk", expecteds: [nil, nil, "까"])
    app.test(input: "fkji", expecteds: [nil, nil, "까", "까ㅁ"], removeds: ["까", ""])
    app.test(input: "fjki", expecteds: [nil, nil, "까", "까ㅁ"], removeds: ["까", ""])
    app.test(input: "jfk", expecteds: [nil, nil, "아ㄱ"], removeds: ["아"])
    app.test(input: "kfj", expecteds: [nil, nil, "가ㅇ"], removeds: ["가"])
    app.test(input: "sjkf", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "skjf", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "sfkj", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "sfjk", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "jksf", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "kjsf", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "fskj", expecteds: [nil, nil, nil, "깐"])
    app.test(input: "fsjk", expecteds: [nil, nil, nil, "깐"])
  }

  func testㄺ() {
    app.test(input: "2[", expecteds: ["ㅆ", "ㄺ"], markeds: ["ㅆ", "ㄺ"])
    app.test(input: "[2", expecteds: ["[", "ㄺ"], markeds: ["[", "ㄺ"])
  }

  func test괜() {
    app.test(input: "k/r", expecteds: [nil, nil, "괘"])
    app.test(input: "k/rs", expecteds: [nil, nil, nil, "괜"])
    app.test(input: "kr/s", expecteds: [nil, nil, nil, "괜"])
    app.test(input: "krs/", expecteds: [nil, nil, nil, "괜"])
    app.test(input: "k/sr", expecteds: [nil, nil, nil, "괜"])
    app.test(input: "ks/r", expecteds: [nil, nil, nil, "괜"])
    app.test(input: "ksr/", expecteds: [nil, nil, nil, "괜"])
  }

  func test뚫() {
    app.test(input: "iub[r", expecteds: [nil, nil, nil, "뚜[", "뚫"])
    app.test(input: "iu[br", expecteds: [nil, nil, nil, "뚜[", "뚫"])
    app.test(input: "iubr[", expecteds: [nil, nil, nil, "뚜ㅐ", "뚫"])
    app.test(input: "iubr[[", expecteds: [nil, nil, nil, "뚜ㅐ", "뚫", "뚫["], removeds: ["뚫", ""])
    app.test(input: "bb[r", expecteds: [nil, nil, "ㅜㅜ[", "ㅜㅜㅀ"], markeds: [nil, nil, "ㅜ[", "ㅜㅀ"])
  }

  func test많() {
    app.test(
      input: "if[s[", expecteds: [nil, nil, "맒", "많", "많["], markeds: [nil, nil, nil, nil, "["],
      removeds: ["많", ""])
    app.test(input: "ifs[", expecteds: [nil, nil, nil, "많"])
    app.test(input: "i[fs", expecteds: [nil, nil, nil, "많"])
    app.test(input: "i[sf", expecteds: [nil, nil, nil, "많"])
    app.test(input: "isf[", expecteds: [nil, nil, nil, "많"])
    app.test(input: "is[f", expecteds: [nil, nil, nil, "많"])
    app.test(
      input: "isf[f", expecteds: [nil, nil, nil, "많", "많ㅏ"], markeds: [nil, nil, nil, nil, "ㅏ"],
      removeds: ["많", ""])
    app.test(
      input: "is[ff", expecteds: [nil, nil, nil, "많", "많ㅏ"], markeds: [nil, nil, nil, nil, "ㅏ"],
      removeds: ["많", ""])
    app.test(
      input: "isff", expecteds: [nil, nil, "만", "만ㅏ"], markeds: [nil, nil, nil, "ㅏ"],
      removeds: ["만", ""])
    app.test(
      input: "isf[s", expecteds: [nil, nil, nil, "많", "많ㄴ"], markeds: [nil, nil, nil, nil, "ㄴ"],
      removeds: ["많", ""])
    app.test(
      input: "is[fs", expecteds: [nil, nil, nil, "많", "많ㄴ"], markeds: [nil, nil, nil, nil, "ㄴ"],
      removeds: ["많", ""])
    app.test(
      input: "ifss", expecteds: [nil, nil, "만", "만ㄴ"], markeds: [nil, nil, nil, "ㄴ"],
      removeds: ["만", ""])
  }

  func test삶() {
    app.test(input: "nf[f", expecteds: [nil, nil, "삶", "삶"])
    app.test(input: "n[ff", expecteds: [nil, nil, "삶", "삶"])
    app.test(input: "nff[", expecteds: [nil, "사", "사ㅏ", "삶"])
    app.test(input: "f[n", expecteds: [nil, "ㅏㄻ", "삶"])
    app.test(input: "[fn", expecteds: [nil, "ㅏㄻ", "삶"])
    app.test(input: "[nf", expecteds: [nil, "ㅅ[", "삶"])
    app.test(input: "n[[f", expecteds: [nil, "ㅅ[", "ㅅ[[", "ㅅ[ㅏㄻ"])
    app.test(
      input: "f[[nf", expecteds: [nil, "ㅏㄻ", "ㅏㄻ[", "ㅏㄻㅅ[", "ㅏㄻ삶"],
      markeds: [nil, nil, "ㅏㄻ[", "ㅅ[", "삶"])
  }

  func test얹() {
    app.test(input: "jt[e", expecteds: [nil, nil, "엀", "얹"])
    app.test(input: "te[j", expecteds: [nil, "ㅓㅕ", "ㅓㄵ", "얹"])
  }
}

extension VirtualApp {
  func test(
    input: String, expecteds: [String?], markeds: [String?]? = nil, removeds: [String?]? = nil
  ) {
    var results: [(Character, String)] = []

    func strokes() -> String {
      String(Array(results.map { $0.0 }))
    }

    XCTAssertEqual(client.string, "", "app.client.string is not cleared")
    for (i, keyChar) in input.enumerated() {
      let key = "\(keyChar)"
      results.append((keyChar, client.string))
      inputKeys(key)
      if let expected = expecteds[i] {
        XCTAssertEqual(
          expected, client.string,
          "strokes: \(strokes()) buffer: \(client.string) marked: \(client.markedString()) app: \(self)"
        )
      }
      if let markeds = markeds {
        if let marked = markeds[i] {
          XCTAssertEqual(
            marked, client.markedString(),
            "buffer: \(client.string) marked: \(client.markedString()) app: \(self)")
        }
      }
    }
    if var removeds = removeds {
      while let removed = removeds.first {
        removeds.remove(at: 0)
        inputDelete()
        XCTAssertEqual(
          removed, client.string,
          "buffer: \(client.string) marked: \(client.markedString()) app: \(self)")
      }
    } else {
      while let (keyChar, result) = results.popLast() {
        inputDelete()
        XCTAssertEqual(
          result, client.string,
          "strokes: \(strokes())<BS(\(keyChar))> buffer: \(client.string) marked: \(client.markedString()) app: \(self)"
        )
      }
    }

    inputKey(.space)
    client.string = ""

    inputKeys(input)
    let result = client.string
    inputKey(.ansiK)
    inputDelete()
    XCTAssertEqual(
      result, client.string,
      "input: \(input) 'k' and delete fails buffer: \(client.string) marked: \(client.markedString()) app: \(self)"
    )

    inputKey(.ansiF)
    inputDelete()
    XCTAssertEqual(
      result, client.string,
      "input: \(input) 'f' and delete fails buffer: \(client.string) marked: \(client.markedString()) app: \(self)"
    )

    inputKey(.ansiS)
    inputDelete()
    XCTAssertEqual(
      result, client.string,
      "input: \(input) 's' and delete fails buffer: \(client.string) marked: \(client.markedString()) app: \(self)"
    )

    inputKey(.space)
    client.string = ""
  }
}
