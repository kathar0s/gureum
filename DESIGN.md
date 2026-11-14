# Design

## Source of truth

Status: **Draft — product name and integrated wind/ㅂ concept confirmed; final geometry proposed for review.**
Date: 2026-11-14.  
Product: **바람 입력기 · Baram Input Method**. This document governs the future formal product; the installed experiment remains GureumChordLab until the identity migration is verified.

Surfaces: macOS input-menu symbols, app icon, preferences, installer/readme, release materials, and the eight-page brand sheet at `docs/brand/baram/sheet.html`. PDF and 1200×750 page PNGs are generated under `docs/brand/baram/brand-sheet/`. The earlier one-page SVG is an overview study only.

Evidence reviewed:

- `README.md:12–21`: lightweight, open-source macOS Korean input and multiple keyboard layouts.
- `OSXCore/HangulComposer.swift:128–155`: libhangul automatic reordering is an option; physical chord recognition is a separate, unproved capability.
- `Preferences/PreferenceViewController.swift:162–321`: revised Input / Shortcuts / Advanced navigation and native settings form.
- `Preferences/PreferenceViewController.swift:346–467`: semantic AppKit colors, 13 pt labels / 11 pt help, native switches and single-chevron popup presentation.
- `OSX/ConfigurationWindow.swift`: the window controller owns a fixed 500 pt content width, 340 pt minimum height, and automatic keyboard traversal.
- Reviewed G007 light/dark/minimum/long-value renders, including `/tmp/gureum-preferences-after/preferences-input-light.png` and `preferences-input-dark.png`. These temporary renders are evidence, not shipping brand assets.
- `COPYING:1–8` and `OSX/Icons/COPYING:1–4`: source and inherited icon rights differ. Existing cloud artwork is not the basis of the new mark.
- Historical Baram's own introduction: <https://baramim.blogspot.com/>. It also uses the wish meaning of 바람. Our implementation derives from Gureum; formal continuation of historical Baram is not established.
- User-confirmed name and meaning: wind moves clouds; the input method responds “나의 바람대로.” The user requested a brand sheet before final colors/icons are applied.
- Authoritative family conventions reviewed in `/Users/nexus/Obsidian/kathar0s/Resources/brand_assets/sionyul/README.md`, `sionyul/app-guide/README.md`, `mitten/README.md`, and the Sionyuel brand MOC/logo brief. Required sheet order: cover / story / logo / color / app screen / typography+icons / don't / application, eight pages at 1200×750 pt. Repository source is authoritative; Obsidian holds generated review copies.

Observed implementation and proposed brand decisions are distinguished below. No app identifiers, installed icons, or product defaults change through this document.

## Brand

Confirmed name: **바람 입력기**. English descriptor: **Baram Input Method**. Short name: **바람 / Baram**. User-confirmed official distribution domain: **baram.sionyuel.com**. Domain selection is a naming decision; deployment and DNS availability require their own verification.

Proposed personality: calm, precise, lightly poetic, dependable, responsive. A tool used all day should make the writing feel effortless and let the user's words lead.

Recommended line: **나의 바람대로, 한글이 흐르다.** Use it in brand/release material; ordinary settings should use direct instructions.

The user-confirmed concept is **바람획 ㅂ**: two parallel wind strokes become the letter's own uprights and lower counter, while a branch of the lower stroke exits to the right as a directional tail. Wind and letter are integrated in one silhouette. The distinct, elongated lower counter is the signature; at 16–32 px the intended first reading is ㅂ, and at 128–1024 px the entering strands and wind movement should become apparent. This is an intent pending user recognition review, not a measured claim. Geometry is original and centrally defined in `docs/brand/baram/mark.mjs`. Two compact studies—negative-space wind and interwoven flow—remain comparison material, not interchangeable marks.

Trust comes from clear settings, preserved typing habits, accurate release claims, source/license provenance, tested rollback, and honest distinction between automatic reorder and physical chording. Avoid performance claims without measurements, official-successor language without agreement, historical artwork reuse, weather illustrations, metallic keyboard/cloud skeuomorphism, and decorative gradients.

## Product goals

- Make Korean input reliable on current macOS, with special attention to Sebeolsik and changed keystroke order.
- Preserve the user's existing layout and shortcuts while making their options easy to understand.
- Make install, identification, trial, and rollback understandable on both Mac Studio and MacBook.
- Establish a consistent formal identity after the experimental gates pass.

Non-goals: changing the user's keyboard layout through branding; disguising a timing heuristic as physical chording; making everyday preferences a marketing canvas; implying historical Baram code or endorsement without evidence.

Success signals: settings are findable within one category; menu items remain identifiable at 16 pt; no ambiguous selected/disabled states; real-world typing and migration evidence support release claims.

## Personas and jobs

Primary: a Korean-speaking macOS user who types in Sebeolsik, develops or writes across editors, Terminal, browsers, and Electron apps, and expects the same composition across them.

Jobs: select a familiar layout, change a shortcut, enable automatic ordering, diagnose an application-specific issue, and return to writing. Secondary audiences use two-set layouts or need Hanja/emoji and Roman keyboard mapping.

## Information architecture

Observed and retained preferences structure:

- **입력**: Hangul composition, strict combinations, won/backquote, Roman layout, Option behavior.
- **단축키**: Hangul/Roman switch, Hanja/emoji, direct language shortcuts, plus always-visible Right-key Switching and System Shortcuts groups with native Open buttons.
- **고급**: application compatibility, Esc behavior, updates; a plain Developer group appears only in Debug.

Brand/readme hierarchy: name → one-line purpose → verified capabilities → installation → trial/rollback → provenance. Keep experimental status and ad-hoc/notarization facts near installation decisions.

### Input menu

The system owns the input-source list. The app contributes only a compact native menu:

```text
설정…
업데이트 확인…                 upstream updater capability only
────────────────
도움말 및 지원                 native submenu
    웹사이트 / 사용 도움말     only when valid destinations exist
    문제 신고… / 소스 코드
    후원하기                   upstream donation capability only
    개발자 → 실험 버전 확인…   Debug upstream builds only
────────────────
<bundle display name>에 관하여
```

Lab contributes Settings, Help & Support containing the fork's Issues and Source, and About. It does not inherit upstream website, help, donation, or update services. About uses the bundle's localized display name. Keep the existing InputController first-responder action routing and native keyboard, VoiceOver, submenu, and validation behavior. Use real NSMenu hierarchy without leading spaces in titles. Functional SF Symbols may appear on the top-level Settings/Update/Support/About items; submenu rows remain text-first.

`GureumMenuCapabilities` owns the product's valid destinations and updater capability; `GureumMenuBuilder` constructs app-owned menu items from that description. MainMenu.xib contains the delegate/outlet shell rather than a second static copy of those items.

## Design principles

1. **The user's rhythm leads.** Show a clear state; avoid visual activity during typing.
2. **Korean identity through structure.** The letterform and typography carry the identity, not a decorative cloud.
3. **Native where it helps operation.** Preserve AppKit menu, keyboard, focus, VoiceOver, and system appearance behavior.
4. **Controlled color, clear hierarchy.** Jade belongs to the product mark and deliberate highlights. A warm second strand may reveal the large app icon's construction; menu symbols remain bold monochrome. Semantic system colors own everyday controls.
5. **Evidence before promise.** Release language names what was tested and the environments that remain uncertain.

## Visual language

Proposed brand tokens (not yet applied to production code):

| Token | Value | Role |
|---|---|---|
| `brand.jade` | `#14675F` | Primary mark and brand emphasis; white text contrast 6.70:1 |
| `brand.ink` | `#172C2C` | Brand-sheet text; warm-paper contrast 13.32:1 |
| `brand.paper` | `#F6F4EE` | Editorial/installer brand surface; not a forced AppKit window background |
| `brand.mist` | `#E5ECE7` | Quiet separators and diagram ground; never body text |
| `brand.secondary` | `#5D6E68` | Secondary text on paper, 4.90:1 |
| `brand.night` | `#162623` | Dark brand surface |
| `brand.mint` | `#A9E2CD` | Dark-surface mark/accent, night contrast 10.82:1 |
| `brand.warm` | `#D9A15F` | Optional rare annotation/accent, night contrast 6.90:1; not error color |

AppKit controls continue to use `labelColor`, `secondaryLabelColor`, `controlBackgroundColor`, `separatorColor`, and the user's system accent. Do not replace error/warning/success semantics with brand colors. Color pair ratios use WCAG relative luminance and apply only to these exact opaque pairs.

Typography:

- Preferences: AppKit system font, 13 pt regular labels, 13 pt semibold section headings, 11 pt supporting text. Native text supports OS rendering and accessibility expectations.
- Korean brand wordmark: **Apple SD Gothic Neo Bold** as the reviewable starting point, with modest optical spacing. A later outlined custom wordmark may soften the terminal of ㅂ and echo its opening; do not modify the font file or redistribute Apple fonts.
- English descriptor/body: system sans or Helvetica Neue on the brand sheet; 13/11 pt equivalents in UI. No added downloadable font dependency.
- Poetic line: **AppleMyungjo**, used only in large brand/editorial settings. Fallback to the system Korean serif. Never use it for controls or dense help.
- Shipping vector wordmarks should eventually be outlined after approval; the current sheet keeps live accessible text for review and relies on installed macOS fonts.

Spacing: 4/8/10/12/20/24 pt rhythm. The user's System Settings Notifications reference and independent advisor supersede both earlier large forms. Content width is fixed at 500 pt with 20 pt edges; default height is 440 pt and minimum height 340 pt, with vertical resizing/scrolling. Rows use a 36 pt minimum plus a 1 pt separator (typically 37–38 pt pitch), 10 pt horizontal insets, and true label/control vertical centering. Separators are inset 10 pt. Section headers use 13 pt bold primary text aligned with the row labels, with at most one concise 11 pt secondary explanation above each group. Native switches use `.mini` (36×16 pt on macOS 26); category segments and value popups use regular intrinsic sizes with no forced font or frame. Popup width is capped at 220 pt for long-name truncation. Shortcut recorders are 132 pt wide with height derived from a regular native button. Section gaps are 24 pt; no row subtitles or collapsible help.

Shape/elevation: native window chrome and stock `NSBox(.primary)` preference groups with system-owned fill/corners. No custom group fill, border, or radius: on macOS 26 the group should become slightly lighter than its dark window and slightly darker than its light window. Brand document target radii remain 8/12/20 pt plus pill and do not override native control geometry. No nested cards, floating shadows, or gloss. App-icon source master is a full 1024×1024 square with separate background/mark layers; the OS supplies the final mask. Rounded containers shown on the sheet are presentation mockups, not baked production masks.

Motion: retain system menu/switch transitions. Respect Reduce Motion. No typing-time bounce, logo animation, or particle effects.

Iconography: original **바람획 ㅂ** mark; system SF Symbols for functional UI. Master geometry uses a 128-unit frame with 10-unit strokes, curved entries, lower counter, and a curved exit. The small optical version uses 12-unit strokes (1.5 px at 16 px), shortened entries, an enlarged lower counter, and a flat shorter exit; do not scale the master unchanged for the menu. Menu-bar assets are monochrome templates and must read on light/dark bars without a colored square. Large app-icon studies may use paper + warm strands on jade, or a monochrome equivalent. Color separation reveals structure without supplying essential recognition. Keep at least 20% clear space around the mark. Do not add a separate wind illustration to the letter.

`brand-sheet/recognition.png` compares the master, optical correction, a generic wind, a generic cloud, and plain ㅂ at actual 16/32/128 px. It is a structural review grid, not a user study or proof of recall. Before approval, inspect the silhouette without a wordmark and ask whether it remains distinguishable. Never claim recognition is established from geometry tests alone.

## Components

| Component | Contract |
|---|---|
| Wordmark | Korean name primary; English descriptor secondary; keep “입력기” subordinate |
| App icon | Integrated two-wind-strand ㅂ study; concept approved, geometry pending visual approval and size testing |
| Menu symbol | Monochrome template; optically simplified; preserve keyboard-layout distinction through existing text/metadata |
| Category navigation | Native three-way segmented control, one selection, visible keyboard focus |
| Boolean setting | Native mini NSSwitch with VoiceOver name matching its visible row label; explanations belong to the group |
| Value menu | Stock borderless regular NSPopUpButton with natural font/size and system-drawn arrow/hover/focus/type-select; no accessory style, custom cell, chip, or arrow overlay |
| Two-choice setting | The same native popup language as other value settings; Option reuses its existing popup/action |
| Shortcut capture | Existing MASShortcut behavior with consistent width and accessible label |
| System support | Always-visible compact groups and native Open buttons; no disclosure or inline-bezel links |
| Installer | Straight instructions, concrete version/architecture/signature status, scoped backup/rollback |

Token ownership: `docs/brand/baram/tokens.css` owns proposed brand-document color/font values using family role names. This file explains their application; AppKit owns runtime semantic colors. Approved brand assets under `docs/brand/baram` become export sources only after review; they are not yet application resources. No parallel runtime token registry is introduced.

## Accessibility

Aim for WCAG 2.2 AA-equivalent visual contrast and macOS platform accessibility behavior. Test keyboard traversal, Space/Return menu opening, arrow/type-to-select, popup value announcement, switch label/value, and focus visibility. Enable automatic key-loop recalculation; category changes keep traversal in the active page in row order. Recorder controls accept keyboard focus and use the bundled Korean button-title localization. Do not use color alone to show an enabled mode. Keep native controls rather than a drawn imitation.

The HTML sheet has semantic page labels, headings, live text, and screenshot descriptions; original SVG marks are described in text. PDF and PNG are generated review formats; HTML and the design document remain the accessible source. The earlier SVG overview also retains title/description/live text.

## Responsive behavior

This is a macOS desktop input method. Preferences keep a 500 pt content width and resize vertically from 340 pt; each category scrolls vertically when its always-visible groups exceed the viewport. Long values truncate before labels and explanations wrap. No mobile layout is implied. The canonical brand sheet is eight landscape pages at 1200×750 pt (1600×1000 CSS px); PNG previews render each page at 1200×750 px.

## Interaction states

- Selected: native segment/checkmark/switch state; brand highlights must not obscure it.
- Disabled: retain label legibility and give a short reason where needed, including Lab updater isolation.
- Error: state the failed action and recovery, especially registration or preferences loading.
- Loading: avoid a blocking overlay for local preference changes; show progress only for meaningful work such as package/build steps.
- Empty/unknown layout: preserve a safe fallback and name the missing selection rather than showing an unlabeled menu.
- Offline: input remains local; update/network errors do not interrupt typing.
- Debug: experimental capture and developer actions are clearly separated and disabled in Release.

## Content voice

Use calm Korean with short, concrete labels. A setting title names the behavior; one secondary sentence explains the effect or compatibility target. “자동 순서 교정” is accurate for libhangul reorder; “물리적 동시입력” is reserved for verified key-hold grouping. Avoid “완벽한”, “가장 빠른”, or “모든 앱 지원” without evidence.

Brand line proposal: **나의 바람대로, 한글이 흐르다.** Alternative short signature: **손끝의 바람, 글이 되다.** The line is a brand promise of intention, not a technical claim of perfect recognition.

Provenance wording for release review: “구름 입력기를 기반으로 새롭게 개발한 독립 오픈소스 입력기입니다. 과거의 한글입력기 바람과 구름 입력기가 남긴 발자취를 존중합니다.” Do not imply endorsement or formal succession until confirmed.

## Implementation constraints

- Existing stack: Swift/AppKit, XIB/storyboard, InputMethodKit, libhangul, MASShortcut. No web frontend/package framework was found for these surfaces.
- Minimum target: macOS 12; Apple Silicon and Intel packaging require architecture verification.
- Retain existing configuration values, shortcut behavior, localization, and client-composition boundaries during visual changes.
- Keep GureumChordLab identifiers until the dedicated migration step. A rename must cover app, bundle, input-source IDs, defaults, IMKit connection, installers, labels, docs, and safe migration/rollback together.
- Existing cloud icons have separate CC-BY-NC-ND terms (`OSX/Icons/COPYING`); the sheet's geometry is newly authored and does not trace them.
- No historical Baram artwork is included. No third-party font binaries or stock images are added.
- Rebuild with `node docs/brand/baram/build.mjs`; add `--sync-obsidian` to refresh only named PDF/page copies in `/Users/nexus/Obsidian/kathar0s/Resources/brand_assets/baram/`. That folder's README records the source path, provenance, and remaining work.
- Validate preference light/dark, minimum height, long values, always-visible system/developer groups, keyboard focus, native menu interaction, and VoiceOver. Offscreen non-key renders do not prove live accent/focus contrast; current macOS 26 evidence does not establish macOS 12–15 runtime parity.
- Before applying icons, render 16/18/32/128/512/1024 px and inspect silhouettes at actual size. A brand-sheet preview is not a finished `.icns` or menu asset.
- The builder exports original master/small SVGs, 16/32/128 PNG comparisons, a 1024-square two-tone app-icon study, and a no-wordmark recognition grid from `mark.mjs`. Generated assets are not edited by hand.

## Open questions

- [ ] User: approve or revise final 바람획 ㅂ geometry and controlled two-tone application after actual-size/no-wordmark comparison; the integrated wind/ㅂ concept is confirmed.
- [ ] Release owner: complete official trademark/name clearance and attempt contact with historical Baram developer; determines public naming/relationship language, not this draft's ability to be reviewed.
- [ ] Release owner: decide final bundle/defaults identifiers and migration rules after trial gates; prevents settings loss and duplicate input sources.
- [ ] Engineering: prove or reject physical key-up delivery across required clients; determines feature language and architecture.
- [ ] Design/release: approve final outlined Korean wordmark and original icon license; determines shipping asset provenance.
- [ ] QA: verify actual native menu and VoiceOver interaction on both target Macs; sheet illustrations do not prove interaction.
