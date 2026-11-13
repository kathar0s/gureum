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

private final class PreferencesMenuCell: NSPopUpButtonCell {
  override func titleRect(forBounds rect: NSRect) -> NSRect {
    var title = super.titleRect(forBounds: rect)
    title.size.width = max(0, title.width - 24)
    return title
  }
}

private final class PreferencesMenuIndicator: NSImageView {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

#if !USE_PREFPANE
  import GureumCore
#endif

@objc(PreferenceViewController)
final class PreferenceViewController: NSViewController {
  @IBOutlet private var debugButton: NSButton!
  /// 옵션 키 동작.
  @IBOutlet private var optionKeyBehaviorButton: NSPopUpButton!

  /// 한글 입력기일 때 역따옴표(`)로 원화 기호(₩) 입력.
  @IBOutlet private var hangulWonCurrencySymbolForBackQuoteButton: NSButton!
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
  private var disclosureBodies: [NSButton: NSView] = [:]
  private var sectionPicker: NSSegmentedControl!
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
    if InputMethodIdentity.current.isChordLab {
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

  /// The nib owns the existing setting controls and actions; this form gives them a
  /// consistent native presentation without changing the stored preferences.
  private func buildSettingsForm() {
    for subview in view.subviews { subview.removeFromSuperview() }
    NSLayoutConstraint.deactivate(view.constraints)
    view.setFrameSize(NSSize(width: 620, height: 600))

    sectionPicker = NSSegmentedControl(
      labels: ["입력", "단축키", "고급"], trackingMode: .selectOne,
      target: self, action: #selector(selectSettingsSection(_:)))
    sectionPicker.segmentStyle = .rounded
    sectionPicker.selectedSegment = 0
    sectionPicker.setAccessibilityLabel("설정 카테고리")
    sectionPicker.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(sectionPicker)

    let optionControl = NSSegmentedControl(
      labels: ["특수 문자", "로마자"], trackingMode: .selectOne,
      target: self, action: #selector(optionSegmentChanged(_:)))
    optionControl.selectedSegment = optionKeyBehaviorButton.indexOfSelectedItem
    optionControl.segmentStyle = .rounded
    optionControl.setAccessibilityLabel("Option 키 동작")

    let layoutMenu = NSPopUpButton(frame: .zero, pullsDown: false)
    layoutMenu.addItems(withTitles: inputSources.map(\.localizedName))
    if let index = inputSources.firstIndex(where: {
      $0.identifier == configuration.overridingKeyboardName
    }) {
      layoutMenu.selectItem(at: index)
    }
    layoutMenu.target = self
    layoutMenu.action = #selector(layoutMenuChanged(_:))
    styleMenu(layoutMenu, label: "로마자 키보드 레이아웃")
    styleMenu(rightToggleKeyButton, label: "오른쪽 전환 키")

    var inputSections: [NSView] = [
      section(
        "한글 조합",
        rows: [
          settingRow(
            "모아치기", detail: "입력 순서가 바뀐 낱자를 자동으로 조합합니다.",
            control: settingSwitch(hangulAutoReorderButton, label: "모아치기 · 자동 순서 교정")),
          settingRow(
            "세벌식 정석 조합", detail: "세벌식의 정석 결합 규칙을 적용합니다.",
            control: settingSwitch(hangulForceStrictCombinationRuleButton, label: "세벌식 정석 조합")),
          settingRow(
            "역따옴표로 원화 기호 입력", detail: "한글 입력 중 ` 키를 누르면 ₩를 입력합니다.",
            control: settingSwitch(
              hangulWonCurrencySymbolForBackQuoteButton, label: "역따옴표로 원화 기호 입력")),
        ]),
      section(
        "로마자 입력",
        rows: [
          settingRow("키보드 레이아웃", control: layoutMenu, controlWidth: 224),
          settingRow("Option 키 동작", control: optionControl, controlWidth: 224),
        ]),
      helperText("키보드 레이아웃은 로마자 입력과 한글 입력 중 로마자 단축키에 함께 적용됩니다."),
    ]
    #if !USE_PREFPANE
      if InputMethodIdentity.current.isChordLab {
        let toggle = NSSwitch()
        toggle.target = self
        toggle.action = #selector(physicalChordModeChanged(_:))
        toggle.setAccessibilityLabel("실험용 물리적 키 묶기")
        physicalChordSwitch = toggle
        let permission = NSButton(
          title: "입력 모니터링 허용…", target: self, action: #selector(requestPhysicalChordPermission(_:)))
        physicalChordPermissionButton = permission
        inputSections.append(
          section(
            "실험 · 물리적 키 묶기",
            rows: [
              settingRow("물리적 키 묶기", detail: "활성 Lab 세벌식에서만 모아 누른 순서대로 전달합니다.", control: toggle),
              settingRow("키 해제 관찰 권한", detail: "버튼을 누를 때만 시스템 권한을 요청합니다.", control: permission),
            ]))
        let status = helperText("")
        physicalChordStatus = status
        inputSections.append(status)
        NotificationCenter.default.removeObserver(
          self, name: PhysicalKeyEventSource.statusDidChange, object: nil)
        NotificationCenter.default.addObserver(
          self, selector: #selector(physicalChordSourceChanged(_:)),
          name: PhysicalKeyEventSource.statusDidChange, object: nil)
        refreshPhysicalChordControls()
      }
    #endif
    let inputPage = page(inputSections)

    let shortcutsPage = page([
      section(
        "입력 전환",
        rows: [
          settingRow(
            "한글 ↔ 로마자",
            control: shortcutControl(inputModeExchangeShortcutView, label: "한글과 로마자 전환 단축키"),
            controlWidth: 176),
          settingRow(
            "한자 및 이모지",
            control: shortcutControl(inputModeSearchShortcutView, label: "한자 및 이모지 단축키"),
            controlWidth: 176),
          settingRow(
            "로마자로 전환", control: shortcutControl(inputModeEnglishShortcutView, label: "로마자로 전환 단축키"),
            controlWidth: 176),
          settingRow(
            "한글로 전환", control: shortcutControl(inputModeKoreanShortcutView, label: "한글로 전환 단축키"),
            controlWidth: 176),
          settingRow("오른쪽 전환 키", control: rightToggleKeyButton, controlWidth: 224),
        ]),
      disclosure(
        "시스템 전환 설정 안내",
        content: verticalStack(
          [
            helperText("오른쪽 키로 전환하려면 시스템 설정의 입력 모니터링에서 구름 입력기를 허용하세요."),
            settingsLink("입력 모니터링 열기", action: #selector(openInputMonitoringPreference(sender:))),
            helperText("Caps Lock 전환은 키보드의 입력 소스 설정에서 켤 수 있습니다."),
            settingsLink(
              "입력 소스 설정 열기", action: #selector(openKeyboardInputSourcesPreference(sender:))),
            helperText(
              "시스템 입력 소스 단축키도 사용할 수 있습니다. Shift가 포함된 조합을 등록할 때는 Fn 키를 함께 누르세요. 예: Fn + Shift + Space."
            ),
            settingsLink("키보드 단축키 열기", action: #selector(openKeyboardShortcutsPreference(sender:))),
          ], spacing: 8)),
    ])

    var advancedSections = [
      section(
        "앱 호환성",
        rows: [
          settingRow(
            "두벌식 종성 결합", detail: "초성 조합 중에도 겹받침을 허용합니다. MS Windows 호환 옵션입니다.",
            control: settingSwitch(hangulNonChoseongCombinationButton, label: "두벌식 종성 결합")),
          settingRow(
            "조합 상태 유지", detail: "모든 글자를 조합 중인 글자로 처리합니다. JDK 기반 앱 호환 옵션입니다.",
            control: settingSwitch(hangulDeferredSymbolCommitButton, label: "모든 글자의 조합 상태 유지")),
        ]),
      section(
        "편집",
        rows: [
          settingRow(
            "Esc로 로마자 전환", detail: "vi 스타일로 Esc를 누르면 로마자 입력으로 전환합니다.",
            control: settingSwitch(romanModeByEscapeKeyButton, label: "Esc로 로마자 전환"))
        ]),
      section(
        "업데이트",
        rows: [
          settingRow("업데이트 알림", control: settingSwitch(updateNotificationButton, label: "업데이트 알림")),
          settingRow(
            "실험 버전 알림",
            control: settingSwitch(updateNotificationExperimentalButton, label: "실험 버전 업데이트 알림")),
        ]),
    ]
    if InputMethodIdentity.current.isChordLab {
      advancedSections.append(helperText("Lab 빌드에서는 구름의 자동 업데이트 알림을 사용하지 않습니다."))
    }
    #if DEBUG
      debugButton.title = "앱을 의도적으로 종료"
      debugButton.isHidden = false
      advancedSections.append(
        disclosure(
          "개발자 도구",
          content: verticalStack(
            [
              helperText("오류 처리 검증을 위해 앱을 즉시 종료합니다."), debugButton,
            ], spacing: 8)))
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
    NSLayoutConstraint.activate([
      sectionPicker.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
      sectionPicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      sectionPicker.widthAnchor.constraint(equalToConstant: 300),
      sectionPicker.heightAnchor.constraint(equalToConstant: 28),
      pageContainer.topAnchor.constraint(equalTo: sectionPicker.bottomAnchor, constant: 24),
      pageContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
      pageContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
      pageContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
    ])
  }

  #if !USE_PREFPANE
    override func viewWillAppear() {
      super.viewWillAppear()
      if InputMethodIdentity.current.isChordLab { refreshPhysicalChordControls() }
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
      let permission = source.permissionGranted ? "권한 허용됨" : "권한 미허용"
      let state = configuration.physicalChordingEnabled ? source.statusText : "물리적 묶기 꺼짐"
      physicalChordStatus?.stringValue = "\(permission) · \(state) 권한 변경 후 입력기를 다시 선택하세요."
    }
  #endif

  private func page(_ sections: [NSView]) -> NSScrollView {
    let scroll = NSScrollView()
    scroll.borderType = .noBorder
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    let document = PreferencesDocumentView()
    document.translatesAutoresizingMaskIntoConstraints = false
    scroll.documentView = document
    let stack = verticalStack(sections, spacing: 24)
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

  private func section(_ title: String, rows: [NSView]) -> NSView {
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 13, weight: .semibold)
    label.textColor = .secondaryLabelColor
    let box = NSBox()
    box.boxType = .custom
    box.titlePosition = .noTitle
    box.cornerRadius = 10
    box.borderWidth = 0
    box.fillColor = .controlBackgroundColor
    box.contentViewMargins = .zero
    var arranged: [NSView] = []
    for (index, row) in rows.enumerated() {
      if index > 0 {
        let separator = NSBox()
        separator.boxType = .separator
        arranged.append(separator)
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
    return verticalStack([label, box], spacing: 10)
  }

  private func settingRow(
    _ title: String, detail: String? = nil, control: NSView, controlWidth: CGFloat? = nil
  ) -> NSView {
    let row = NSView()
    let label = NSTextField(wrappingLabelWithString: title)
    label.font = .systemFont(ofSize: 13)
    var labels: [NSView] = [label]
    if let detail = detail { labels.append(helperText(detail)) }
    let text = verticalStack(labels, spacing: 4)
    text.translatesAutoresizingMaskIntoConstraints = false
    control.removeFromSuperview()
    NSLayoutConstraint.deactivate(
      control.constraints.filter {
        $0.firstAttribute == .width || $0.firstAttribute == .height
      })
    control.translatesAutoresizingMaskIntoConstraints = false
    control.isHidden = false
    row.addSubview(text)
    row.addSubview(control)
    NSLayoutConstraint.activate([
      row.heightAnchor.constraint(greaterThanOrEqualToConstant: detail == nil ? 48 : 64),
      text.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
      text.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
      text.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12),
      text.trailingAnchor.constraint(equalTo: control.leadingAnchor, constant: -16),
      control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
      control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
    ])
    if let controlWidth = controlWidth {
      control.widthAnchor.constraint(equalToConstant: controlWidth).isActive = true
      control.heightAnchor.constraint(equalToConstant: 30).isActive = true
    }
    return row
  }

  private func settingSwitch(_ backing: NSButton, label: String) -> NSSwitch {
    let control = NSSwitch()
    control.state = backing.state
    control.isEnabled = backing.isEnabled
    control.target = self
    control.action = #selector(settingSwitchChanged(_:))
    control.setAccessibilityLabel(label)
    switchBindings[control] = backing
    return control
  }

  private func styleMenu(_ menu: NSPopUpButton, label: String) {
    let nativeMenu = menu.menu
    let selectedIndex = menu.indexOfSelectedItem
    let target = menu.target
    let action = menu.action
    let cell = PreferencesMenuCell(textCell: menu.title, pullsDown: false)
    cell.arrowPosition = .noArrow
    menu.cell = cell
    menu.menu = nativeMenu
    menu.selectItem(at: selectedIndex)
    menu.target = target
    menu.action = action
    menu.isBordered = false
    menu.controlSize = .large
    menu.font = .systemFont(ofSize: 13)
    menu.alignment = .right
    menu.cell?.lineBreakMode = .byTruncatingMiddle
    menu.setAccessibilityElement(true)
    menu.setAccessibilityRole(.popUpButton)
    menu.setAccessibilityLabel(label)
    let indicator = PreferencesMenuIndicator()
    indicator.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)
    indicator.contentTintColor = .secondaryLabelColor
    indicator.setAccessibilityElement(false)
    indicator.translatesAutoresizingMaskIntoConstraints = false
    menu.addSubview(indicator)
    NSLayoutConstraint.activate([
      indicator.widthAnchor.constraint(equalToConstant: 12),
      indicator.heightAnchor.constraint(equalToConstant: 12),
      indicator.trailingAnchor.constraint(equalTo: menu.trailingAnchor, constant: -4),
      indicator.centerYAnchor.constraint(equalTo: menu.centerYAnchor),
    ])
  }

  private func shortcutControl(_ control: MASShortcutView, label: String) -> NSView {
    control.setAccessibilityLabel(label)
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

  private func settingsLink(_ title: String, action: Selector) -> NSButton {
    let button = NSButton(title: title, target: self, action: action)
    button.bezelStyle = .inline
    button.contentTintColor = .controlAccentColor
    button.alignment = .left
    return button
  }

  private func disclosure(_ title: String, content: NSView) -> NSView {
    let button = NSButton(title: title, target: self, action: #selector(toggleDisclosure(_:)))
    button.bezelStyle = .inline
    button.alignment = .left
    button.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
    button.imagePosition = .imageLeading
    button.setButtonType(.onOff)
    button.setAccessibilityExpanded(false)
    content.isHidden = true
    disclosureBodies[button] = content
    return verticalStack([button, content], spacing: 12)
  }

  @objc private func selectSettingsSection(_ sender: NSSegmentedControl) {
    for (index, page) in preferencePages.enumerated() {
      page.isHidden = index != sender.selectedSegment
    }
  }

  @objc private func settingSwitchChanged(_ sender: NSSwitch) {
    guard let backing = switchBindings[sender], let action = backing.action else { return }
    backing.state = sender.state
    NSApp.sendAction(action, to: backing.target, from: backing)
    for (control, button) in switchBindings { control.isEnabled = button.isEnabled }
  }

  @objc private func optionSegmentChanged(_ sender: NSSegmentedControl) {
    optionKeyBehaviorButton.selectItem(at: sender.selectedSegment)
    optionKeyBehaviorValueChanged(optionKeyBehaviorButton)
  }

  @objc private func layoutMenuChanged(_ sender: NSPopUpButton) {
    guard inputSources.indices.contains(sender.indexOfSelectedItem) else { return }
    configuration.overridingKeyboardName = inputSources[sender.indexOfSelectedItem].identifier
  }

  @objc private func toggleDisclosure(_ sender: NSButton) {
    let expanded = sender.state == .on
    disclosureBodies[sender]?.isHidden = !expanded
    sender.image = NSImage(
      systemSymbolName: expanded ? "chevron.down" : "chevron.right", accessibilityDescription: nil)
    sender.setAccessibilityExpanded(expanded)
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
