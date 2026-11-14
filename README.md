<p align="center">
  <img src="docs/brand/baram/assets/baram-app-icon-concept-128.png" width="112" height="112" alt="바람 입력기 아이콘">
</p>

# 바람 입력기

**Baram Input Method**는 macOS용 오픈소스 한글 입력기입니다. [구름 입력기](https://github.com/gureum/gureum)의 검증된 기반을 이어받아 세벌식 모아치기, 현대적인 설정 화면, 독립적인 브랜드와 업데이트 경로를 다듬고 있습니다.

> 현재 상태: 개발자용 시험 빌드입니다. Apple Developer ID 서명·공증을 마친 공개 설치 파일은 아직 제공하지 않습니다.

[![platform](https://img.shields.io/badge/macOS-12%2B-111827?logo=apple)](https://github.com/sionyuel/baram)
[![architectures](https://img.shields.io/badge/architecture-Apple%20Silicon%20%7C%20Intel-458C80)](https://github.com/sionyuel/baram)
[![license](https://img.shields.io/badge/license-BSD--2--Clause%20%2B%20LGPL--2.1-blue)](COPYING)

## 주요 기능

- 두벌식, 세벌식 최종·390·순아래·옛글·2011·2012 등 여러 한글 자판
- 로마자, QWERTY, Dvorak, Colemak 계열 입력 소스
- 초성·중성·종성 순서가 바뀐 낱자를 보정하는 모아치기
- 한글 자판 XML을 그대로 읽는 설정 화면의 키보드 미리보기
- `` ` `` 및 `Shift+`` 키에 자주 쓰는 문자 한 글자 지정
- 선택한 앱에서만 Esc 또는 `Control+[`로 로마자 전환
- 선택한 앱의 바람 로마자 모드에서 완전히 조합되는 세벌식 입력을 자동 한글 변환
- Apple Silicon과 Intel을 함께 지원하는 Universal 빌드
- 구름 입력기와 분리된 앱·입력 소스·설정·업데이트 식별자

지원 자판과 자판별 주의사항은 [지원 자판 문서](docs/keyboards/README.md)를 참고하세요.

### 자동 한글 변환

`고급 → 앱별 동작 → 자동 한글 변환`에서 사용할 앱을 선택하면 켜집니다. 기본값은 꺼짐입니다. 바람의 로마자 모드에서 `jfshea`를 입력한 뒤 공백을 누르면 마지막 한글 자판으로 다시 조합해 `안녕 `으로 바꿉니다. Apple ABC를 직접 선택한 동안에는 동작하지 않습니다.

변환 기준은 영어 사전의 단어 유무가 아니라 세벌식 조합 결과입니다. 현재 한글 자판에서 완성형 두 음절 이상으로 끝나고 낱자·영문·기호가 남지 않을 때만 변환합니다. 공백·Return·Tab에서 판정하며 대문자·숫자·기호가 섞인 키열, 선택 영역, 보안 입력과 지원하지 않는 자판은 유지합니다. 알려진 일부 터미널과 자격증명 앱은 제외합니다. 정상 영어도 우연히 완전한 한글로 조합될 수 있으므로 사용할 앱을 제한해 주세요.

치환은 앱의 텍스트 입력 API를 사용합니다. 실행 취소와 비밀번호 필드 감지는 앱마다 다를 수 있어 실제 앱별 검증이 필요합니다. 키열은 해당 입력 세션의 현재 단어만 메모리에 보관하며 저장하거나 네트워크로 전송하지 않습니다.

## 설치

### 공개 배포

정식 배포 주소는 [baram.sionyuel.com](https://baram.sionyuel.com)입니다. 현재는 서명·공증된 다운로드를 준비 중이며, 출처를 확인할 수 없는 재배포 파일 설치는 권장하지 않습니다.

### 소스에서 시험 빌드

요구 환경은 macOS 12 이상과 Xcode입니다.

```sh
git clone --recurse-submodules https://github.com/sionyuel/baram.git
cd baram
make init
GUREUM_BARAM_ARCHS='arm64 x86_64' tools/install_baram.sh --install
```

설치 후 `시스템 설정 → 키보드 → 텍스트 입력 → 편집`에서 `Baram ·`으로 시작하는 자판을 추가하세요. 입력 소스가 바로 나타나지 않으면 로그아웃 후 다시 로그인해야 할 수 있습니다.

설치 스크립트는 기존 Baram 앱을 `~/Library/Application Support/Baram/Backups/`에 보존합니다. 구름 입력기나 다른 입력기는 변경하지 않습니다.

```sh
tools/baram_input_source.sh list
tools/baram_input_source.sh select han3final
```

## 제거

먼저 ABC 또는 다른 입력기로 전환한 다음 아래 명령을 실행하세요.

```sh
tools/install_baram.sh --uninstall
```

Baram 앱은 백업 폴더로 이동하며 사용자 설정은 자동 삭제하지 않습니다.

## 권한과 개인정보

일반 한글 입력에는 입력 모니터링 권한이 필요하지 않습니다. 이 권한은 다음 선택 기능에만 사용합니다.

- 오른쪽 Command·Option·Control 키를 입력 전환 키로 사용
- 실험적인 물리적 동시입력 묶기

권한은 설정 화면의 명시적인 버튼을 누른 경우에만 macOS에 요청합니다. Release 빌드는 입력 내용이나 조합 문자열을 수집하지 않습니다. Debug 빌드는 개발 로그가 남을 수 있으므로 민감한 문장을 입력하지 마세요.

## 업데이트

Baram은 구름의 업데이트 서버를 사용하지 않습니다. 정식 버전은 `https://baram.sionyuel.com/version.json`의 독립 피드에서 확인하며, 설정에서 알림을 끌 수 있습니다. 공개 배포 전 시험 빌드에서는 업데이트 확인 자체를 비활성화합니다.

## 개발

전체 테스트:

```sh
xcodebuild -project Gureum.xcodeproj -scheme OSX -sdk macosx \
  -destination 'platform=macOS' test \
  -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

빌드 구조와 서브모듈 정책은 [HACKING.md](HACKING.md), 변경 제안과 버그 보고 방법은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요. 보안 문제는 공개 이슈 대신 [SECURITY.md](SECURITY.md)의 비공개 신고 절차를 이용해 주세요.

## 프로젝트 계보

Baram은 Gureum에서 출발한 독립 프로젝트입니다. 기존 저작권과 기여 이력을 존중하며, 과거에 존재했던 동명의 “한글입력기 바람”의 공식 후속판임을 주장하지 않습니다.

- 상위 프로젝트: [gureum/gureum](https://github.com/gureum/gureum)
- 한글 조합 엔진: [libhangul](https://github.com/libhangul/libhangul)
- 공개 저장소: [sionyuel/baram](https://github.com/sionyuel/baram)
- 공식 배포 도메인: [baram.sionyuel.com](https://baram.sionyuel.com)

## 라이선스

저장소의 코드와 포함된 의존성·아이콘 자산에는 서로 다른 라이선스가 적용될 수 있습니다. 프로젝트 코드의 기본 조건과 저작권 고지는 [COPYING](COPYING), 아이콘 관련 고지는 [OSX/Icons/COPYING](OSX/Icons/COPYING)을 확인하세요. `libhangul` 및 하위 구성요소의 라이선스는 각 서브모듈에 포함된 문서를 따릅니다.
