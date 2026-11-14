//
//  PreferenceViewController.swift
//  Preferences
//
//  Created by Jeong YunWon on 2017. 11. 29..
//  Copyright © 2017 youknowone.org. All rights reserved.
//

import Cocoa
import Foundation
import MASShortcut

private final class PreferencesDocumentView: NSView {
  override var isFlipped: Bool { true }
}

private final class KoreanShortcutCell: MASShortcutViewButtonCell {
  private static let koreanResources: Bundle? = {
    for owner in [
      Bundle.main, Bundle(for: MASShortcutView.self), Bundle(for: PreferenceViewController.self),
    ] {
      let resources =
        owner.url(forResource: "MASShortcut_MASShortcut", withExtension: "bundle")
        ?? owner.bundleURL.deletingLastPathComponent().appendingPathComponent(
          "MASShortcut_MASShortcut.bundle")
      if let bundle = Bundle(url: resources),
        let path = bundle.path(forResource: "ko", ofType: "lproj")
      {
        return Bundle(path: path)
      }
    }
    return nil
  }()

  override var title: String? {
    get { super.title }
    set {
      guard let value = newValue else {
        super.title = nil
        return
      }
      let fallback = value == "Record Shortcut" ? "단축키 입력" : value
      super.title =
        Self.koreanResources?.localizedString(forKey: value, value: fallback, table: nil)
        ?? fallback
    }
  }
}

@objc(GureumShortcutView)
private final class GureumShortcutView: MASShortcutView {
  override class func shortcutCellClass() -> AnyClass { KoreanShortcutCell.self }
}

#if !USE_PREFPANE
  import GureumCore
#endif

@objc(PreferenceViewController)
final class PreferenceViewController: NSViewController, NSTextFieldDelegate {
  @IBOutlet private var debugButton: NSButton!
  /// 옵션 키 동작.
  @IBOutlet private var optionKeyBehaviorButton: NSPopUpButton!

  /// 한글 입력기일 때 역따옴표(`)로 원화 기호(₩) 입력.
  @IBOutlet private var hangulWonCurrencySymbolForBackQuoteButton: NSButton!
  private var hangulBackQuoteOutputCharacterField: NSTextField!
  private var hangulShiftBackQuoteOutputCharacterField: NSTextField!
  private var hangulSpecialCharacterHelp: NSTextField!
  private var editedSpecialCharacterFields: Set<ObjectIdentifier> = []
  /// 완성되지 않은 낱자 자동 교정 (모아치기).
  @IBOutlet private var hangulAutoReorderButton: NSButton!
  /// 두벌식 초성 조합 중에도 종성 결합 허용 (MS윈도 호환).
  @IBOutlet private var hangulNonChoseongCombinationButton: NSButton!
  /// 모든 글자를 조합중인 글자로 취급 (JDK 호환).
  @IBOutlet private var hangulDeferredSymbolCommitButton: NSButton!
  /// 세벌식 정석 강요.
  @IBOutlet private var hangulForceStrictCombinationRuleButton: NSButton!
  /// Esc 키로 로마자 자판으로 전환 (vi 모드).
  @IBOutlet private var romanModeByEscapeKeyButton: NSButton!
  /// 우측 키로 언어 전환
  @IBOutlet private var rightToggleKeyButton: NSPopUpButton!

  /// 입력기 바꾸기 단축키.
  @IBOutlet private var inputModeExchangeShortcutView: MASShortcutView!
  /// 한자 및 이모지 검색 단축키.
  @IBOutlet private var inputModeSearchShortcutView: MASShortcutView!
  /// 로마자로 바꾸기 단축키.
  @IBOutlet private var inputModeEnglishShortcutView: MASShortcutView!
  /// 한글로 바꾸기 단축키.
  @IBOutlet private var inputModeKoreanShortcutView: MASShortcutView!

  /// 업데이트 알림 받기
  @IBOutlet private var updateNotificationButton: NSButton!
  /// 실험버전 업데이트 알림 받기
  @IBOutlet private var updateNotificationExperimentalButton: NSButton!

  private let configuration = Configuration()
  private let pane: GureumPreferencePane! = nil
  private let shortcutValidator = GureumShortcutValidator()
  private let backgroundQueue = DispatchQueue.global(qos: .background)
  private var preferencePages: [NSView] = []
  private var switchBindings: [NSSwitch: NSButton] = [:]
  private var preferenceKeyViews: [[NSView]] = []
  private var buildingKeyViews: [NSView] = []
  private var sectionPicker: NSSegmentedControl!
  private let sectionTitles = ["입력", "단축키", "고급"]
  private static let hangulSpecialCharacterHelpText =
    "한글 입력 중 사용할 문자 한 개를 입력하세요. 비우면 현재 자판의 기본 문자를 사용합니다."
  private static let hangulSpecialCharacterErrorText = "한 글자만 입력하세요. 예: ₩ · @ …"
  #if !USE_PREFPANE
    private var physicalChordSwitch: NSSwitch?
    private var physicalChordStatus: NSTextField?
    private var physicalChordPermissionButton: NSButton?
  #endif

  private lazy var inputSources: [(identifier: String, localizedName: String)] = {
    let abcIdentifier = "com.apple.keylayout.ABC"

    guard
      let rawSources = TISInputSource.sources(
        withProperties: [
          kTISPropertyInputSourceType!: kTISTypeKeyboardLayout!,
          kTISPropertyInputSourceIsASCIICapable!: true,
        ], includeAllInstalled: true)
    else {
      return []
    }

    let unsortedSources = rawSources.map {
      (identifier: $0.identifier, localizedName: $0.localizedName, enabled: $0.enabled)
    }
    let sortedSources = unsortedSources.sorted {
      if $0.identifier == abcIdentifier {
        return true
      } else if $1.identifier == abcIdentifier {
        return false
      }
      if $0.enabled != $1.enabled {
        return $0.enabled
      }
      return $0.localizedName < $1.localizedName
    }
    let sources = sortedSources.map { (identifier: $0.identifier, localizedName: $0.localizedName) }
    return sources
  }()

  override func viewDidLoad() {
    hangulWonCurrencySymbolForBackQuoteButton.state = isOn(
      configuration.hangulWonCurrencySymbolForBackQuote)
    romanModeByEscapeKeyButton.state = isOn(configuration.romanModeByEscapeKey)
    hangulAutoReorderButton.state = isOn(configuration.hangulAutoReorder)
    hangulNonChoseongCombinationButton.state = isOn(configuration.hangulNonChoseongCombination)
    hangulDeferredSymbolCommitButton.state = isOn(configuration.hangulDeferredSymbolCommit)
    hangulForceStrictCombinationRuleButton.state = isOn(
      configuration.hangulForceStrictCombinationRule)
    switch configuration.rightToggleKey {
    case kHIDUsage_KeyboardRightGUI:
      rightToggleKeyButton.selectItem(at: 1)
    case kHIDUsage_KeyboardRightAlt:
      rightToggleKeyButton.selectItem(at: 2)
    case kHIDUsage_KeyboardRightControl:
      rightToggleKeyButton.selectItem(at: 3)
    default:
      rightToggleKeyButton.selectItem(at: 0)
    }
    if (0..<optionKeyBehaviorButton.numberOfItems).contains(configuration.optionKeyBehavior) {
      optionKeyBehaviorButton.selectItem(at: configuration.optionKeyBehavior)
    }

    inputModeExchangeShortcutView.shortcutValidator = shortcutValidator
    inputModeSearchShortcutView.shortcutValidator = shortcutValidator
    inputModeEnglishShortcutView.shortcutValidator = shortcutValidator
    inputModeKoreanShortcutView.shortcutValidator = shortcutValidator

    loadShortcutValues()
    setupShortcutViewValueChangeEvents()

    updateNotificationButton.state = isOn(configuration.updateNotification)
    if Bundle.main.isExperimental {
      updateNotificationExperimentalButton.state = .on
      updateNotificationExperimentalButton.isEnabled = false
    } else {
      updateNotificationExperimentalButton.state = isOn(
        configuration.updateNotificationExperimental)
    }
    if InputMethodIdentity.current.usesForkServices {
      updateNotificationButton.state = .off
      updateNotificationButton.isEnabled = false
      updateNotificationExperimentalButton.state = .off
      updateNotificationExperimentalButton.isEnabled = false
    }

    #if DEBUG
      debugButton.isHidden = false
    #endif
    buildSettingsForm()
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    updateKeyViewLoop()
  }

  /// The nib owns the existing setting controls and actions; this form gives them a
  /// consistent native presentation without changing the stored preferences.
  private func buildSettingsForm() {
    for subview in view.subviews { subview.removeFromSuperview() }
    NSLayoutConstraint.deactivate(view.constraints)
    view.setFrameSize(NSSize(width: 500, height: 440))
    preferenceKeyViews.removeAll()
    buildingKeyViews.removeAll()

    sectionPicker = NSSegmentedControl(
      labels: sectionTitles, trackingMode: .selectOne,
      target: self, action: #selector(selectSettingsSection(_:)))
    sectionPicker.segmentStyle = .automatic
    sectionPicker.controlSize = .regular
    sectionPicker.selectedSegment = 0
    sectionPicker.setAccessibilityLabel("설정 카테고리")
    sectionPicker.translatesAutoresizingMaskIntoConstraints = false
    #if USE_PREFPANE
      view.addSubview(sectionPicker)
    #else
      sectionPicker.isHidden = true
    #endif

    let layoutMenu = NSPopUpButton(frame: .zero, pullsDown: false)
    layoutMenu.addItems(withTitles: inputSources.map(\.localizedName))
    if let index = inputSources.firstIndex(where: {
      $0.identifier == configuration.overridingKeyboardName
    }) {
      layoutMenu.selectItem(at: index)
    }
    layoutMenu.target = self
    layoutMenu.action = #selector(layoutMenuChanged(_:))
    styleMenu(layoutMenu, label: "키보드 레이아웃")
    styleMenu(rightToggleKeyButton, label: "오른쪽 전환 키")
    styleMenu(optionKeyBehaviorButton, label: "Option 키 동작")
    hangulBackQuoteOutputCharacterField = specialCharacterField(
      value: configuration.hangulBackQuoteOutputCharacter, label: "` 키 문자")
    hangulShiftBackQuoteOutputCharacterField = specialCharacterField(
      value: configuration.hangulShiftBackQuoteOutputCharacter, label: "Shift+` 키 문자")
    hangulSpecialCharacterHelp = helperText(Self.hangulSpecialCharacterHelpText)

    let inputSections: [NSView] = [
      section(
        "한글 조합",
        rows: [
          settingRow(
            "모아치기",
            control: settingSwitch(hangulAutoReorderButton, label: "모아치기")),
          settingRow(
            "세벌식 정석 조합",
            control: settingSwitch(hangulForceStrictCombinationRuleButton, label: "세벌식 정석 조합")),
        ],
        explanation: helperText(
          "모아치기는 순서가 바뀐 낱자를 자동으로 조합합니다. 정석 조합은 세벌식 최종·390에서 이중모음과 겹받침을 해당 자판 규칙으로 제한합니다.")),
      section(
        "특수문자 키",
        rows: [
          settingRow("` 키 문자", control: hangulBackQuoteOutputCharacterField),
          settingRow("Shift+` 키 문자", control: hangulShiftBackQuoteOutputCharacterField),
        ], explanation: hangulSpecialCharacterHelp),
      section(
        "로마자 입력",
        rows: [
          settingRow("키보드 레이아웃", control: layoutMenu),
          settingRow("Option 키 동작", control: optionKeyBehaviorButton),
        ], explanation: helperText("선택한 레이아웃은 로마자 입력과 한글 입력 중 로마자 단축키에 함께 적용됩니다.")),
    ]
    let inputPage = page(inputSections)

    let shortcutsPage = page([
      section(
        "입력 전환",
        rows: [
          settingRow(
            "한글 ↔ 로마자",
            control: shortcutControl(inputModeExchangeShortcutView, label: "한글 ↔ 로마자")),
          settingRow(
            "한자 및 이모지",
            control: shortcutControl(inputModeSearchShortcutView, label: "한자 및 이모지")),
          settingRow(
            "로마자로 전환", control: shortcutControl(inputModeEnglishShortcutView, label: "로마자로 전환")),
          settingRow(
            "한글로 전환", control: shortcutControl(inputModeKoreanShortcutView, label: "한글로 전환")),
        ]),
      section(
        "오른쪽 키 전환",
        rows: [
          settingRow("오른쪽 전환 키", control: rightToggleKeyButton),
          settingRow(
            "입력 모니터링",
            control: settingsButton(
              for: "입력 모니터링", action: #selector(openInputMonitoringPreference(sender:)))),
        ], explanation: helperText("오른쪽 키로 전환하려면 입력 모니터링 허용이 필요합니다.")),
      section(
        "시스템 단축키",
        rows: [
          settingRow(
            "키보드",
            control: settingsButton(
              for: "키보드", action: #selector(openKeyboardShortcutsPreference(sender:))))
        ], explanation: helperText("Caps Lock 전환은 키보드 설정에서 켭니다. Shift 조합을 등록할 때는 Fn 키도 함께 누르세요.")),
    ])

    var advancedSections = [
      section(
        "앱 호환성",
        rows: [
          settingRow(
            "두벌식 종성 결합",
            control: settingSwitch(hangulNonChoseongCombinationButton, label: "두벌식 종성 결합")),
          settingRow(
            "조합 상태 유지",
            control: settingSwitch(hangulDeferredSymbolCommitButton, label: "조합 상태 유지")),
        ], explanation: helperText("특정 앱에서 조합이 어긋날 때만 켜세요. 종성 결합은 Windows 방식, 조합 상태 유지는 JDK 앱용입니다.")
      ),
      section(
        "편집",
        rows: [
          settingRow(
            "Esc로 로마자 전환",
            control: settingSwitch(romanModeByEscapeKeyButton, label: "Esc로 로마자 전환"))
        ]),
      section(
        "업데이트",
        rows: [
          settingRow("업데이트 알림", control: settingSwitch(updateNotificationButton, label: "업데이트 알림")),
          settingRow(
            "실험 버전 알림",
            control: settingSwitch(updateNotificationExperimentalButton, label: "실험 버전 알림")),
        ],
        explanation: InputMethodIdentity.current.usesForkServices
          ? helperText("이 제품에서는 구름의 자동 업데이트 알림을 사용하지 않습니다.") : nil),
    ]
    #if !USE_PREFPANE
      if InputMethodIdentity.current.supportsPhysicalChording {
        let toggle = NSSwitch()
        toggle.controlSize = .mini
        toggle.target = self
        toggle.action = #selector(physicalChordModeChanged(_:))
        toggle.setAccessibilityLabel("물리적 키 묶기")
        toggle.setAccessibilityHelp(
          "지원 세벌식의 모아 누른 키를 배열 기준 초성, 중성, 종성으로 정렬합니다. 경계 및 안전 복구에서는 입력 순서를 유지합니다.")
        physicalChordSwitch = toggle
        let permission = NSButton(
          title: "입력 모니터링 허용…", target: self, action: #selector(requestPhysicalChordPermission(_:)))
        permission.controlSize = .small
        physicalChordPermissionButton = permission
        let status = helperText("")
        physicalChordStatus = status
        advancedSections.append(
          section(
            "실험 · 물리적 키 묶기",
            rows: [
              settingRow("물리적 키 묶기", control: toggle),
              settingRow("키 해제 관찰 권한", control: permission),
            ], explanation: status))
        NotificationCenter.default.removeObserver(
          self, name: PhysicalKeyEventSource.statusDidChange, object: nil)
        NotificationCenter.default.addObserver(
          self, selector: #selector(physicalChordSourceChanged(_:)),
          name: PhysicalKeyEventSource.statusDidChange, object: nil)
        refreshPhysicalChordControls()
      }
    #endif
    #if DEBUG
      debugButton.title = "종료…"
      debugButton.isBordered = true
      debugButton.controlSize = .regular
      debugButton.setAccessibilityLabel("오류 처리 검증을 위해 앱 종료")
      debugButton.isHidden = false
      advancedSections.append(
        section(
          "개발자", rows: [settingRow("오류 처리 검증", control: debugButton)],
          explanation: helperText("오류 처리 검증을 위해 앱을 즉시 종료합니다.")))
    #endif
    let advancedPage = page(advancedSections)
    preferencePages = [inputPage, shortcutsPage, advancedPage]
    let pageContainer = NSView()
    pageContainer.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(pageContainer)
    for (index, page) in preferencePages.enumerated() {
      page.translatesAutoresizingMaskIntoConstraints = false
      page.isHidden = index != 0
      pageContainer.addSubview(page)
      NSLayoutConstraint.activate([
        page.leadingAnchor.constraint(equalTo: pageContainer.leadingAnchor),
        page.trailingAnchor.constraint(equalTo: pageContainer.trailingAnchor),
        page.topAnchor.constraint(equalTo: pageContainer.topAnchor),
        page.bottomAnchor.constraint(equalTo: pageContainer.bottomAnchor),
      ])
    }
    var layoutConstraints = [
      pageContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      pageContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      pageContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
    ]
    #if USE_PREFPANE
      layoutConstraints.append(contentsOf: [
        sectionPicker.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
        sectionPicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        pageContainer.topAnchor.constraint(equalTo: sectionPicker.bottomAnchor, constant: 16),
      ])
    #else
      layoutConstraints.append(
        pageContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 16))
    #endif
    NSLayoutConstraint.activate(layoutConstraints)
  }

  #if !USE_PREFPANE
    override func viewWillAppear() {
      super.viewWillAppear()
      if InputMethodIdentity.current.supportsPhysicalChording { refreshPhysicalChordControls() }
    }

    @objc private func physicalChordModeChanged(_ sender: NSSwitch) {
      configuration.physicalChordingEnabled = sender.state == .on
      PhysicalKeyEventSource.shared.setEnabled(sender.state == .on)
      refreshPhysicalChordControls()
    }

    @objc private func requestPhysicalChordPermission(_: NSButton) {
      let source = PhysicalKeyEventSource.shared
      if source.requestPermissionFromUserAction(), configuration.physicalChordingEnabled {
        source.setEnabled(true)
      }
      refreshPhysicalChordControls()
    }

    @objc private func physicalChordSourceChanged(_: Notification) {
      refreshPhysicalChordControls()
    }

    private func refreshPhysicalChordControls() {
      let source = PhysicalKeyEventSource.shared
      source.refresh()
      physicalChordSwitch?.state = isOn(configuration.physicalChordingEnabled)
      physicalChordPermissionButton?.isEnabled = !source.permissionGranted
      let state = configuration.physicalChordingEnabled ? source.statusText : "물리적 묶기 꺼짐"
      physicalChordPermissionButton?.title = source.permissionGranted ? "허용됨" : "허용…"
      physicalChordStatus?.stringValue = "실험 · 지원 배열의 초성→중성→종성 정렬. 안전 복구는 입력 순서.\n\(state)"
    }
  #endif

  private func page(_ sections: [NSView]) -> NSScrollView {
    preferenceKeyViews.append(buildingKeyViews)
    buildingKeyViews.removeAll()
    let scroll = NSScrollView()
    scroll.borderType = .noBorder
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    let document = PreferencesDocumentView()
    document.translatesAutoresizingMaskIntoConstraints = false
    scroll.documentView = document
    let stack = verticalStack(sections, spacing: 20)
    stack.translatesAutoresizingMaskIntoConstraints = false
    document.addSubview(stack)
    NSLayoutConstraint.activate([
      document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
      stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
      stack.topAnchor.constraint(equalTo: document.topAnchor),
      stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -12),
    ])
    return scroll
  }

  private func section(_ title: String, rows: [NSView], explanation: NSTextField? = nil) -> NSView {
    let label = NSTextField(labelWithString: title)
    label.font = .boldSystemFont(ofSize: 13)
    label.textColor = .labelColor
    let box = NSBox()
    box.boxType = .primary
    box.titlePosition = .noTitle
    box.contentViewMargins = .zero
    var arranged: [NSView] = []
    for (index, row) in rows.enumerated() {
      if index > 0 {
        let separator = NSBox()
        separator.boxType = .separator
        let inset = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        inset.addSubview(separator)
        NSLayoutConstraint.activate([
          inset.heightAnchor.constraint(equalToConstant: 1),
          separator.leadingAnchor.constraint(equalTo: inset.leadingAnchor, constant: 10),
          separator.trailingAnchor.constraint(equalTo: inset.trailingAnchor, constant: -10),
          separator.topAnchor.constraint(equalTo: inset.topAnchor),
          separator.bottomAnchor.constraint(equalTo: inset.bottomAnchor),
        ])
        arranged.append(inset)
      }
      arranged.append(row)
    }
    let rowsStack = verticalStack(arranged, spacing: 0)
    rowsStack.translatesAutoresizingMaskIntoConstraints = false
    box.contentView!.addSubview(rowsStack)
    NSLayoutConstraint.activate([
      rowsStack.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor),
      rowsStack.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor),
      rowsStack.topAnchor.constraint(equalTo: box.contentView!.topAnchor),
      rowsStack.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor),
    ])
    let labelInset = NSView()
    label.translatesAutoresizingMaskIntoConstraints = false
    labelInset.addSubview(label)
    var sectionViews = [labelInset, box]
    if let explanation = explanation {
      let explanationInset = NSView()
      explanation.translatesAutoresizingMaskIntoConstraints = false
      explanationInset.addSubview(explanation)
      NSLayoutConstraint.activate([
        explanation.leadingAnchor.constraint(equalTo: explanationInset.leadingAnchor, constant: 10),
        explanation.trailingAnchor.constraint(
          equalTo: explanationInset.trailingAnchor, constant: -10),
        explanation.topAnchor.constraint(equalTo: explanationInset.topAnchor),
        explanation.bottomAnchor.constraint(equalTo: explanationInset.bottomAnchor),
      ])
      sectionViews.append(explanationInset)
    }
    let group = verticalStack(sectionViews, spacing: 6)
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: labelInset.leadingAnchor, constant: 10),
      label.trailingAnchor.constraint(equalTo: labelInset.trailingAnchor, constant: -10),
      label.topAnchor.constraint(equalTo: labelInset.topAnchor),
      label.bottomAnchor.constraint(equalTo: labelInset.bottomAnchor),
    ])
    group.setCustomSpacing(8, after: labelInset)
    return group
  }

  private func settingRow(_ title: String, control: NSView) -> NSView {
    let row = NSView()
    let label = NSTextField(wrappingLabelWithString: title)
    label.font = .systemFont(ofSize: 13)
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    label.translatesAutoresizingMaskIntoConstraints = false
    control.removeFromSuperview()
    NSLayoutConstraint.deactivate(
      control.constraints.filter {
        $0.firstAttribute == .width || $0.firstAttribute == .height
      })
    control.translatesAutoresizingMaskIntoConstraints = false
    control.isHidden = false
    row.addSubview(label)
    row.addSubview(control)
    NSLayoutConstraint.activate([
      row.heightAnchor.constraint(greaterThanOrEqualToConstant: 34),
      label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
      label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
      label.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: 6),
      label.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -6),
      label.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -12),
      control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
      control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
      control.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: 6),
      control.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -6),
    ])
    if control is NSPopUpButton {
      control.widthAnchor.constraint(lessThanOrEqualToConstant: 220).isActive = true
    } else if let textField = control as? NSTextField, textField.isEditable {
      textField.widthAnchor.constraint(equalToConstant: 72).isActive = true
    } else if control is MASShortcutView {
      control.widthAnchor.constraint(equalToConstant: 120).isActive = true
      control.heightAnchor.constraint(
        equalToConstant: control.intrinsicContentSize.height
      ).isActive = true
    }
    buildingKeyViews.append(control)
    return row
  }

  private func settingSwitch(_ backing: NSButton, label: String) -> NSSwitch {
    let control = NSSwitch()
    control.controlSize = .mini
    control.state = backing.state
    control.isEnabled = backing.isEnabled
    control.target = self
    control.action = #selector(settingSwitchChanged(_:))
    control.setAccessibilityLabel(label)
    switchBindings[control] = backing
    return control
  }

  private func styleMenu(_ menu: NSPopUpButton, label: String) {
    menu.isBordered = false
    menu.controlSize = .small
    menu.alignment = .right
    menu.cell?.lineBreakMode = .byTruncatingMiddle
    menu.setAccessibilityLabel(label)
  }

  private func specialCharacterField(value: String, label: String) -> NSTextField {
    let field = NSTextField(string: value)
    field.controlSize = .small
    field.font = .systemFont(ofSize: 13, weight: .medium)
    field.alignment = .center
    field.placeholderString = "기본"
    field.delegate = self
    field.setAccessibilityLabel(label)
    field.setAccessibilityHelp(Self.hangulSpecialCharacterHelpText)
    return field
  }

  private func shortcutControl(_ control: MASShortcutView, label: String) -> NSView {
    // MASShortcut's default cell leaves the clear glyph optically too far right on modern macOS.
    // Its textured native style applies the library's Big Sur-and-later alignment correction.
    control.style = .texturedRect
    control.setAccessibilityLabel(label)
    control.setAcceptsFirstResponder(true)
    return control
  }

  private func helperText(_ value: String) -> NSTextField {
    let label = NSTextField(wrappingLabelWithString: value)
    label.font = .systemFont(ofSize: 11)
    label.textColor = .secondaryLabelColor
    return label
  }

  private func verticalStack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
    let stack = NSStackView(views: views)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.distribution = .fill
    stack.detachesHiddenViews = true
    stack.spacing = spacing
    for view in views {
      view.translatesAutoresizingMaskIntoConstraints = false
      view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    return stack
  }

  private func settingsButton(for title: String, action: Selector) -> NSButton {
    let button = NSButton(title: "열기…", target: self, action: action)
    button.controlSize = .small
    button.setAccessibilityLabel("\(title) 열기")
    return button
  }

  private func updateKeyViewLoop() {
    guard let window = view.window,
      preferenceKeyViews.indices.contains(sectionPicker.selectedSegment)
    else { return }
    window.autorecalculatesKeyViewLoop = true
    window.recalculateKeyViewLoop()
    let pageControls = preferenceKeyViews[sectionPicker.selectedSegment]
    let controls = sectionPicker.isHidden ? pageControls : [sectionPicker!] + pageControls
    guard !controls.isEmpty else { return }
    for (index, control) in controls.enumerated() {
      control.nextKeyView = controls[(index + 1) % controls.count]
    }
    window.initialFirstResponder = controls[0]
  }

  @objc private func selectSettingsSection(_ sender: NSSegmentedControl) {
    selectSettingsSection(at: sender.selectedSegment)
  }

  func selectSettingsSection(at index: Int) {
    guard preferencePages.indices.contains(index) else { return }
    sectionPicker.selectedSegment = index
    for (index, page) in preferencePages.enumerated() {
      page.isHidden = index != sectionPicker.selectedSegment
    }
    updateKeyViewLoop()
  }

  var settingsSectionTitles: [String] { sectionTitles }

  func preferredContentHeight(for index: Int) -> CGFloat {
    guard preferencePages.indices.contains(index),
      let scroll = preferencePages[index] as? NSScrollView,
      let document = scroll.documentView
    else { return 340 }
    view.layoutSubtreeIfNeeded()
    document.layoutSubtreeIfNeeded()
    return min(max(300, document.fittingSize.height + 32), 680)
  }

  @objc private func settingSwitchChanged(_ sender: NSSwitch) {
    guard let backing = switchBindings[sender], let action = backing.action else { return }
    backing.state = sender.state
    NSApp.sendAction(action, to: backing.target, from: backing)
    for (control, button) in switchBindings { control.isEnabled = button.isEnabled }
  }

  @objc private func layoutMenuChanged(_ sender: NSPopUpButton) {
    guard inputSources.indices.contains(sender.indexOfSelectedItem) else { return }
    configuration.overridingKeyboardName = inputSources[sender.indexOfSelectedItem].identifier
  }

  func controlTextDidChange(_ notification: Notification) {
    guard let field = notification.object as? NSTextField else { return }
    guard
      field === hangulBackQuoteOutputCharacterField
        || field === hangulShiftBackQuoteOutputCharacterField
    else { return }
    editedSpecialCharacterFields.insert(ObjectIdentifier(field))
    if let editor = field.currentEditor() as? NSTextView, editor.hasMarkedText() { return }
    updateSpecialCharacterSetting(for: field)
  }

  func controlTextDidEndEditing(_ notification: Notification) {
    guard let field = notification.object as? NSTextField else { return }
    guard editedSpecialCharacterFields.remove(ObjectIdentifier(field)) != nil else { return }
    updateSpecialCharacterSetting(for: field)
  }

  private func updateSpecialCharacterSetting(for field: NSTextField) {
    if field === hangulBackQuoteOutputCharacterField {
      updateSpecialCharacterField(
        field, save: { configuration.hangulBackQuoteOutputCharacter = $0 })
    } else if field === hangulShiftBackQuoteOutputCharacterField {
      updateSpecialCharacterField(
        field, save: { configuration.hangulShiftBackQuoteOutputCharacter = $0 })
    } else {
      return
    }
    let hasError =
      hangulBackQuoteOutputCharacterField.textColor == .systemRed
      || hangulShiftBackQuoteOutputCharacterField.textColor == .systemRed
    hangulSpecialCharacterHelp.stringValue =
      hasError
      ? Self.hangulSpecialCharacterErrorText : Self.hangulSpecialCharacterHelpText
    hangulSpecialCharacterHelp.textColor = hasError ? .systemRed : .secondaryLabelColor
  }

  private func updateSpecialCharacterField(
    _ field: NSTextField, save: (String) -> Void
  ) {
    let value = field.stringValue
    let isValid = Configuration.isValidHangulSpecialCharacter(value)
    field.textColor = isValid ? .labelColor : .systemRed
    field.toolTip = isValid ? nil : Self.hangulSpecialCharacterErrorText
    if isValid { save(value) }
  }

  private func runAppleScript(_ script: String) {
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
      let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(
        &error
      )
      print("pref event descriptor: \(output.stringValue ?? "nil")")
    }
  }

  // MARK: IBAction

  @IBAction private func debug(sender _: NSControl) {
    print("killing myself")
    let x = [0]
    _ = x[1]
  }

  @IBAction private func openKeyboardShortcutsPreference(sender _: NSControl) {
    if #available(OSX 13, *) {
      runAppleScript(
        """
            do shell script "open -b com.apple.systempreferences /System/Library/PreferencePanes/Keyboard.prefPane"
        """)
    } else {
      runAppleScript(
        """
            tell application "System Preferences"
                activate
                reveal anchor "ShortcutsTab" of pane id "com.apple.preference.keyboard"
            end tell
        """)
    }
  }

  @IBAction private func openKeyboardInputSourcesPreference(sender _: NSControl) {
    if #available(OSX 13, *) {
      runAppleScript(
        """
            do shell script "open -b com.apple.systempreferences /System/Library/PreferencePanes/Keyboard.prefPane"
        """)
    } else {
      runAppleScript(
        """
            tell application "System Preferences"
                activate
                reveal anchor "InputSources" of pane id "com.apple.preference.keyboard"
            end tell
        """)
    }
  }

  @IBAction private func openInputMonitoringPreference(sender _: NSControl) {
    if #available(OSX 13, *) {
      runAppleScript(
        """
            do shell script "open x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        """)
    } else {
      runAppleScript(
        """
            tell application "System Preferences"
                activate
                reveal anchor "Privacy" of pane id "com.apple.preference.security"
            end tell
        """)
    }
  }

  @IBAction private func updateCheck(sender _: NSControl) {
    updateCheck()
  }

  @IBAction private func optionKeyBehaviorValueChanged(_ sender: NSPopUpButton) {
    configuration.optionKeyBehavior = sender.indexOfSelectedItem
  }

  @IBAction private func romanModeByEscapeKeyValueChanged(_ sender: NSButton) {
    configuration.romanModeByEscapeKey = sender.state == .on
  }

  @IBAction private func hangulWonCurrencySymbolForBackQuoteValueChanged(_ sender: NSButton) {
    configuration.hangulWonCurrencySymbolForBackQuote = sender.state == .on
  }

  @IBAction private func hangulAutoReorderValueChanged(_ sender: NSButton) {
    configuration.hangulAutoReorder = sender.state == .on
  }

  @IBAction private func hangulNonChoseongCombinationValueChanged(_ sender: NSButton) {
    configuration.hangulNonChoseongCombination = sender.state == .on
  }

  @IBAction private func hangulDeferredSymbolCommitValueChanged(_ sender: NSButton) {
    configuration.hangulDeferredSymbolCommit = sender.state == .on
  }

  @IBAction private func hangulForceStrictCombinationRuleValueChanged(_ sender: NSButton) {
    configuration.hangulForceStrictCombinationRule = sender.state == .on
  }

  @IBAction private func rightToggleKeyValueChanged(_ sender: NSPopUpButton) {
    configuration.rightToggleKey = {
      switch sender.indexOfSelectedItem {
      case 1:
        return kHIDUsage_KeyboardRightGUI
      case 2:
        return kHIDUsage_KeyboardRightAlt
      case 3:
        return kHIDUsage_KeyboardRightControl
      default:
        return 0
      }
    }()
  }

  @IBAction private func updateNotificationValueChanged(_ sender: NSButton) {
    configuration.updateNotification = sender.state == .on
    if !Bundle.main.isExperimental {
      updateNotificationExperimentalButton.isEnabled = sender.state == .on
    }
    backgroundQueue.async {
      self.updateCheck()
    }
  }

  @IBAction private func updateNotificationExperimentalValueChanged(_ sender: NSButton) {
    configuration.updateNotificationExperimental = sender.state == .on
    backgroundQueue.async {
      self.updateCheck()
    }
  }
}

// MARK: - 비공개 메소드

extension PreferenceViewController {
  fileprivate func isOn(_ value: Bool) -> NSButton.StateValue {
    return value ? .on : .off
  }

  fileprivate func loadShortcutValues() {
    if let key = configuration.inputModeExchangeKey {
      inputModeExchangeShortcutView.shortcutValue = MASShortcut(
        keyCode: key.0.rawValue, modifierFlags: key.1)
    } else {
      inputModeExchangeShortcutView.shortcutValue = nil
    }

    if let key = configuration.inputModeSearchKey {
      inputModeSearchShortcutView.shortcutValue = MASShortcut(
        keyCode: key.0.rawValue, modifierFlags: key.1)
    } else {
      inputModeSearchShortcutView.shortcutValue = nil
    }

    if let key = configuration.inputModeEnglishKey {
      inputModeEnglishShortcutView.shortcutValue = MASShortcut(
        keyCode: key.0.rawValue, modifierFlags: key.1)
    } else {
      inputModeEnglishShortcutView.shortcutValue = nil
    }

    if let key = configuration.inputModeKoreanKey {
      inputModeKoreanShortcutView.shortcutValue = MASShortcut(
        keyCode: key.0.rawValue, modifierFlags: key.1)
    } else {
      inputModeKoreanShortcutView.shortcutValue = nil
    }
  }

  fileprivate func setupShortcutViewValueChangeEvents() {
    func masShortcutToShortcut(_ mas: MASShortcut?) -> Configuration.Shortcut? {
      guard let mas = mas, let keyCode = KeyCode(rawValue: mas.keyCode) else { return nil }
      return (keyCode, mas.modifierFlags)
    }
    inputModeExchangeShortcutView.shortcutValueChange = { sender in
      self.configuration.inputModeExchangeKey = masShortcutToShortcut(sender.shortcutValue)
    }

    inputModeSearchShortcutView.shortcutValueChange = { sender in
      self.configuration.inputModeSearchKey = masShortcutToShortcut(sender.shortcutValue)
    }

    inputModeEnglishShortcutView.shortcutValueChange = { sender in
      self.configuration.inputModeEnglishKey = masShortcutToShortcut(sender.shortcutValue)
    }

    inputModeKoreanShortcutView.shortcutValueChange = { sender in
      self.configuration.inputModeKoreanKey = masShortcutToShortcut(sender.shortcutValue)
    }
  }

  fileprivate func updateCheck() {
    #if !USE_PREFPANE
      UpdateManager.shared.requestAutoUpdateVersionInfo { info in
        guard let info = info else {
          return
        }
        UpdateManager.notifyUpdate(info: info)
      }
    #endif
  }
}
