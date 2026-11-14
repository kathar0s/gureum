---
tags: [brand, baram, sionyuel, design-system, assets]
created: 2026-11-14
status: v0.4 — 이름·도메인·바람 궤적 B 방향 반영 / 최종 기하 검토 초안
---

# 바람 입력기 브랜드 원본

시트는 **8쪽 · 1200×750pt 가로**이며 표지 / 이야기 / 로고 / 색 / 앱 화면 / 서체와 아이콘 / 하지 말 것 / 적용 순서를 따릅니다.

원본은 이 저장소의 `docs/brand/baram/`입니다. Obsidian `Resources/brand_assets/baram/`은 검토용 PDF·PNG 복사본입니다. 문서 기준은 저장소 루트 `DESIGN.md`입니다.

## 파일과 다시 만들기

| 파일 | 역할 |
|---|---|
| `sheet.html` | 8쪽 시트의 편집 템플릿. `build.mjs`가 마크 기하를 넣어 PDF 생성 |
| `mark.mjs` | 추천 마스터·작은 크기 보정의 기하 원본. 수치는 여기서만 변경 |
| `tokens.css` | 브랜드 문서 색·글꼴·모서리 토큰 |
| `build.mjs` | Chrome PDF 및 8개 페이지 PNG 생성, 선택적 Obsidian 복사 |
| `assets/preferences-input-*.png` | G007 실제 Preferences.prefPane의 라이트·다크 렌더 증거 |
| `brand-sheet/baram-brand-sheet.pdf` | 생성된 8쪽 PDF |
| `brand-sheet/page-1.png` … `page-8.png` | 1200×750 페이지 미리보기 |
| `recognition.html` / `brand-sheet/recognition.png` | 16/18/32/128 px, 워드마크 없는 실루엣 비교판 |
| `assets/baram-mark-master.svg` / `baram-mark-small.svg` | 생성된 원본 벡터와 작은 크기 광학 보정 |
| `assets/baram-app-icon-concept.svg` | 1024 정사각, 비취 바탕과 종이색 단색 획의 앱 아이콘 검토안 |

```sh
cd /Users/nexus/workspace/kathar0s/gureum
node docs/brand/baram/build.mjs
node docs/brand/baram/build.mjs --sync-obsidian
```

필요한 기존 도구: Google Chrome, Poppler `pdfinfo`/`pdftoppm`. 새 npm 의존성은 없습니다. 최초 생성 또는 `--refresh-screenshots`는 `/tmp/gureum-preferences-after/`의 검증된 두 PNG를 증거 자산으로 가져옵니다. 이후 재생성은 저장소 `assets/`를 사용합니다.

## 이름과 마크

**바람 입력기 / Baram Input Method**, 공식 배포 도메인 **baram.sionyuel.com**. 바람은 구름을 움직이는 자연의 힘이자 사용자가 이루고 싶은 마음입니다. 추천 문장은 **나의 바람대로, 한글이 흐르다.**

확정된 방향은 **바람 궤적 B**입니다. 살짝 휜 세로 기둥과 위·아래의 바람 말림이 한 흐름처럼 만나 영문 B를 먼저 만듭니다. 위아래로 겹친 두 공간은 한글 ㅂ을 보조적으로 떠올리게 하지만, ㅂ 우선 인식을 주장하지 않습니다. 바람 기호를 글자 옆에 붙이지 않습니다. 개념은 사용자가 제공한 손그림 방향을 반영했고 최종 기하는 아직 검토 전입니다.

작은 크기는 획 12, 곧은 기둥, 단순한 두 볼과 짧은 안쪽 갈고리를 사용합니다. 마스터는 획 9와 열린 말림을 사용합니다. 기본 앱 아이콘과 메뉴바는 단색이며, 온기색은 큰 크기 선택안에만 제한합니다. `recognition.png`는 ₿·일반 B·일반 ㅂ과 16/18/32/128 px로 비교한 자료이며 사용자 인지 실험 결과는 아닙니다.

## 색과 대비

| 이름 / 역할 | 값 | 쓰는 곳 / 대비 |
|---|---|---|
| 비취 / accent | `#14675F` | 흰 글자 6.70:1 |
| 먹빛 / ink | `#172C2C` | 종이 `#F6F4EE` 위 13.32:1 |
| 보조 글자 / ink-2 | `#5D6E68` | 종이 위 4.90:1 |
| 안개 / accent-soft | `#E5ECE7` | 면·구분, 본문 글자에 사용하지 않음 |
| 밤 / night | `#162623` | 어두운 브랜드 면 |
| 민트 | `#A9E2CD` | 밤 위 10.82:1 |
| 온기 | `#D9A15F` | 드문 주석, 밤 위 6.90:1 |

실제 Mac 창·메뉴·기본 설정 컨트롤은 AppKit 의미 색상과 사용자의 강조색을 우선합니다. 브랜드 색을 오류·주의·성공에 임의로 겸용하지 않습니다.

## 글꼴·아이콘·말투

- 워드마크: Apple SD Gothic Neo Bold를 검토 시작점으로 사용. 승인 후 외곽선 자산화. Apple 글꼴 파일은 재배포하지 않습니다.
- 브랜드 문장: AppleMyungjo, 큰 크기에만 사용.
- Mac UI: AppKit system title/body/label, 13 pt / 11 pt 이상 보조 설명.
- 기능 아이콘: **SF Symbols**, 이모지 없음. 메뉴·키보드·VoiceOver의 네이티브 동작 유지.
- 앱 아이콘: 1024×1024 정사각 마스터에서 배경·마크 레이어로 내보내고 OS 마스크를 고려합니다. 메뉴바는 단색 template와 별도 16/18 pt 광학 보정.
- 말투: 단정할 수 있는 사실만 단정합니다. 불리한 사실을 먼저 알리고 다음 행동 하나를 제시합니다. 근거 없는 최상급·완벽·모든 앱 지원 주장은 사용하지 않습니다.

## 자산 출처

마크·도형·편집 구성은 이 프로젝트를 위해 새로 작성했습니다. 기존 Gureum 아이콘과 과거 Baram 그림을 복사하거나 변형하지 않았습니다. PNG 페이지는 이 HTML을 Chrome으로 PDF 출력한 뒤 Poppler로 렌더한 파생물입니다. 화면 PNG 두 개는 G007 `OSXTestApp/render_preferences.swift`가 검증된 Preferences.prefPane의 CALayer를 렌더한 것으로, 원래 파일은 `/tmp/gureum-preferences-after/`에서 가져왔습니다.

## 남은 일

- [ ] 바람 궤적 B의 최종 기하·실제 크기 인식 검토, 색·자산 라이선스 확정.
- [ ] 최종 워드마크 외곽선, 16–1024 px 자산 및 앱 아이콘 레이어.
- [ ] 실제 Mac 메뉴·VoiceOver·두 기기 검증.
- [ ] 정식 명칭·상표 확인 및 과거 바람 개발자 연락 시도.
- [ ] 기존 Baram/Gureum 크레딧과 독립 구현 관계 표기.
- [x] ChordLab 설정을 보존하는 Baram 앱·입력 소스·defaults·IMK 식별자 전환.
- [ ] 패밀리 모서리 8/12/20과 현재 AppKit 그룹 10 pt 차이 해소. 현재 구현의 10 pt는 이 브랜드 작업에서 수정하지 않았습니다.
