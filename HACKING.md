# 개발하기

## 개발자 채팅방

[![Discord Banner](https://discordapp.com/api/guilds/1043532404251430952/widget.png?style=banner2)](https://discord.gg/wMbNU7EC8y)

구름 입력기의 코드를 직접 수정하고 싶은 분들을 위해 개발자 채널을 운영하고 있습니다.

## 개발환경 설정

### 지원 환경

- 실행 대상: macOS 12 이상. 구름과 `libhangul-objc` 프로젝트에 같은 최소 버전을 사용합니다.
- CI: GitHub Actions `macos-15` 이미지의 Xcode 26.2를 명시적으로 선택합니다.
- 최신 도구 호환성: 로컬 Mac의 Xcode 27.1에서도 아래 빌드·테스트 명령을 검증합니다.

릴리스 서명 인증서 없이 빌드와 유닛 테스트를 실행할 수 있습니다.

```sh
xcodebuild -project Gureum.xcodeproj -scheme OSX -sdk macosx \
  -destination 'platform=macOS' test \
  -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

최소 macOS 버전은 프로젝트에 저장되어 있으므로 명령행에서 `MACOSX_DEPLOYMENT_TARGET`을 덮어쓸 필요가 없습니다.
위 명령은 테스트용입니다. 입력기를 실제 설치할 때는 별도로 앱 서명과 입력 소스 등록을 확인해야 합니다.
Swift 패키지는 `Gureum.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`에 고정합니다.
의존성을 갱신할 때만 이 파일을 업데이트하고, CI는 고정된 버전을 사용합니다.

Baram 공개 버전은 기존 Gureum 번들 버전보다 단조 증가하도록 `2.0.0`부터 시작하며 릴리스 태그는 `Baram-2.0.0` 형식을 사용합니다.

### git submodule 가져오기

libhangul의 라이선스 전파성을 피하기 위해 프로젝트를 분리하여 준비가 조금 복잡합니다.

git submodule을 포함하고 있으므로 클론 후 submodule도 가져오도록 해야합니다.

``` sh
git clone --recurse-submodules https://github.com/sionyuel/baram.git
cd baram
make init
open Gureum.xcodeproj
```

이 포크의 `libhangul-objc`는 `sionyuel/libhangul-objc`에서 버전이 고정된 커밋을 가져옵니다.
서브모듈의 빌드 설정을 바꿀 때는 해당 포크에 커밋을 먼저 푸시한 뒤 부모 저장소의 서브모듈 커밋을 갱신합니다.
원본 변경을 비교하려면 서브모듈 안에서 `https://github.com/gureum/libhangul-objc.git`을 `upstream` 원격으로 사용합니다.

submodule의 URL 변경 등을 이유로 submodule이 제대로 클론되지 않을 경우에는 다음 명령어로 다시 가져올 수 있습니다.

``` sh
git submodule deinit -f --all
rm -rf .git/modules/*
git submodule update --init --recursive
```

## 빌드

`Gureum` 타겟을 빌드하면 의존성과 함께 구름 입력기가 빌드됩니다.

![image](https://user-images.githubusercontent.com/906974/48977284-c5fc8e80-f0da-11e8-9ad2-7a40b8e774ea.png)

Debug Configuration으로 빌드하면 Console.app에서 로그를 확인할 수 있습니다.

## 디버그 빌드 테스트

### GureumChordLab 실험 빌드

기존 구름과 함께 사용할 수 있는 별도 입력기입니다. 앱 이름은 `GureumChordLab.app`이며,
입력 소스와 설정 영역도 분리되어 있습니다. Firebase 초기화 및 구름 업데이트 확인은 사용하지 않습니다.
설치 시 Lab의 `HangulAutoReorder` 저장값이 없으면 처음에만 `true`로 설정합니다.
기존의 명시적인 켜짐·꺼짐과 일반 구름의 설정은 보존하고, 제거 시에도 Lab 설정을 지우지 않습니다.
이 설정은 libhangul의 순차 입력 자동 순서 교정이며 물리적 동시입력 엔진은 아닙니다.

```sh
./tools/install_chord_lab.sh --build-only
```

서명 검증을 마친 앱은 `build/chord-lab/Build/Products/Debug/GureumChordLab.app`에 생성됩니다.
입력기는 앱을 더블클릭하는 대신 다음 전용 설치 명령으로 사용자 입력기 폴더에 설치합니다.

```sh
./tools/install_chord_lab.sh --install
```

시스템 설정 → 키보드 → 텍스트 입력에서 `Lab ·`로 시작하는 원하는 자판을 추가합니다.
목록에 나타나지 않으면 로그아웃 후 다시 로그인합니다. 아래 명령은 실험 앱만 제거하며,
이전 실험 앱은 `build/chord-lab/backups/`에 보존합니다.

```sh
./tools/install_chord_lab.sh --uninstall
```

일반 순차 입력과 자동 순서 교정은 안전한 기본 경로로 유지합니다.
별도로 Lab 전용 실험 기능인 **물리적 키 묶기**가 구현되어 있으며 기본값은 꺼짐입니다.
설치·시작·테스트는 입력 모니터링 권한을 자동 요청하거나 이 기능을 켜지 않습니다.

### 물리적 키 묶기: 구현 범위와 사용 절차

활성 Lab 세벌식 세션에 한해 공개 CG session event tap을 `listenOnly`로 사용해 키 해제를 관찰합니다.
키 누름과 입력 문자열의 주체는 계속 IMK이며, 관찰 탭은 키를 억제·수정·재전송하지 않습니다.
마지막 활성 세션이 끝나면 탭과 타이머도 정리합니다.

지원하는 일반 세벌식의 XML 형식은 `jaso` 또는 `jaso-yet`입니다. 모든 키를 한글 역할로 매핑할 수 있고
초성·중성이 포함된 완성 그룹만 Hangul.framework의 키보드 XML을 기준으로 초성→중성→종성으로 정렬합니다.
같은 역할 안의 누른 순서는 유지합니다. strict 자판 선택은 조합기와 정책이 같은 식별자 함수를 사용합니다.
기호·알 수 없는 매핑·지원하지 않는 형식과 불완전 그룹은 원래 순서를 유지합니다.
전용 조합 경로를 쓰는 최종 순아래 `3gs`와 `3gc`는 재정렬하지 않습니다.

기능을 직접 시험하려면 다음 절차를 사용합니다.

1. `Lab · 세벌식 최종` 등 원하는 Lab 자판을 선택합니다.
2. 입력기 메뉴의 `설정…` → `입력` → `실험 · 물리적 키 묶기`에서 `물리적 키 묶기`를 켭니다.
3. 권한이 없으면 `키 해제 관찰 권한` 행의 `허용…` 버튼을 직접 누릅니다. 이 버튼만 `CGRequestListenEventAccess`를 호출합니다.
4. macOS 안내 또는 `시스템 설정 → 개인정보 보호 및 보안 → 입력 모니터링`에서 GureumChordLab을 허용합니다.
   대상은 `~/Library/Input Methods/GureumChordLab.app`이며 설치기나 테스트에서 대신 승인하지 않습니다.
5. macOS가 재시작을 안내하면 지시를 따른 뒤 ABC 또는 기본 입력기로 전환했다가 Lab 자판을 다시 선택합니다.
6. `키 해제 수신 준비됨` 상태를 확인하고 짧고 민감하지 않은 문구로 실제 겹치는 키 누름을 시험합니다.

공백·Return·Tab·명령·후보창·마우스 같은 일반 경계에서는 대기 그룹만 원래 순서로 비우고 계속 사용할 수 있습니다.
권한 없음은 일반 입력으로 통과시키며, 권한 회수·Secure Event Input·탭 장애·누락 release 워치독 등 안전 실패는
대기 입력을 원래 순서로 비운 후 해당 세션을 중지합니다. 원인을 해결한 뒤 입력기를 다시 선택해야 합니다.

되돌리려면 같은 설정에서 `물리적 키 묶기`를 끕니다. 관찰을 중지하고 기존 순차 입력으로 돌아가며,
기존 `모아치기` 스위치인 libhangul 자동 순서 교정은 별도로 유지할 수 있습니다.
입력 모니터링 허용도 철회하려면 시스템 설정에서 GureumChordLab 항목만 사용자가 직접 끕니다.

### Baram 로컬 정식명 빌드

`Baram.app`은 기존 구름과 GureumChordLab을 그대로 둔 채 나란히 설치하는 독립 입력기입니다.
bundle/input-source prefix는 `com.sionyuel.inputmethod.Baram`, defaults suite는
`com.sionyuel.Baram`, IMK connection은 `Baram_Connection`입니다.

```sh
tools/install_baram.sh --install
tools/baram_input_source.sh list
tools/baram_input_source.sh select han3final
```

첫 실행에서 Baram 설정 영역이 비어 있으면 GureumChordLab의 알려진 설정만 한 번 복사합니다.
마지막 한글·로마자 입력 소스 ID는 Baram prefix로 바꾸고, 새 앱의 입력 모니터링 권한이
필요한 `PhysicalChordingEnabled`는 복사하지 않습니다. Gureum과 Lab 앱·defaults는 삭제하지 않습니다.
macOS가 새 입력 소스를 바로 선택하지 못해 `OSStatus -50`을 반환하면 시스템 설정 → 키보드 →
텍스트 입력에서 `바람 · 세벌식 …`을 추가하거나 로그아웃 후 다시 로그인합니다.

제거는 Baram만 백업으로 옮깁니다.

```sh
tools/install_baram.sh --uninstall
```
Lab 자체를 제거하려면 먼저 ABC 또는 기본 입력기로 전환한 뒤
`tools/install_chord_lab.sh --uninstall`을 사용합니다.

Studio와 MacBook의 설치·빌드·결정적 테스트 결과와 별개로, 실제 권한 승인 후의 기기·앱 호환성 매트릭스는
아직 검증하지 않았습니다. 패키지 메타데이터의 `physicalChordingVerified`는 계속 `false`입니다.
긴 연속 rollover와 TextEdit·Terminal·Chromium·VS Code 등에서의 실제 사용 검증 전에는 일상용 대체를 보장하지 않습니다.

### Lab 키 이벤트 계측

Debug의 `CHORDLAB_EVENT` 채널은 Lab의 IMK 콜백 메타데이터를 기록합니다. Release에서는 이 디버그 로그와
추가 IMK keyUp 요청을 제외합니다. 공개 CG 탭의 물리적 키 해제 관찰은 이 채널과 별개이며,
물리적 키 묶기를 켜고 권한·활성 세션 조건을 충족할 때만 동작합니다.
물리적 기능이 꺼져 있으면 IMK 키 입력은 기존 조합기로 즉시 전달됩니다. 문자·조합 문자열·문서 내용은 기록하지 않습니다.
키 코드는 입력을 추정하는 데 쓰일 수 있으므로 짧고 민감하지 않은 시험 문구만 사용합니다.
이 관찰 경로는 접근성 권한을 요청하지 않습니다. 입력 모니터링은 위의 명시적 버튼으로만 요청합니다.

등록된 Lab 자판과 현재 입력 소스를 확인할 수 있습니다.

```sh
./tools/chord_lab_input_source.sh list
./tools/chord_lab_input_source.sh current
```

원하는 자판을 선택하면 이전 입력 소스를 파일에 저장합니다. 예를 들어 최종 자판은 `han3final`,
390은 `han390`, 최종 순아래는 `han3finalnoshift`, 2012는 `han3-2012`입니다.
이 도구는 이전 입력 소스를 비활성화하지 않습니다.

```sh
./tools/chord_lab_input_source.sh select han3final
./tools/capture_chord_lab_events.sh 60
./tools/chord_lab_input_source.sh restore
```

새로 설치한 입력기가 등록되어도 현재 로그인 세션에서 선택되지 않아 `OSStatus -50`이 나올 수 있습니다.
이 경우 시스템 설정에서 Lab 자판을 추가하거나 로그아웃 후 다시 로그인한 뒤 같은 명령을 실행합니다.
선택 실패 후에도 `restore`로 저장된 이전 입력 소스를 다시 선택할 수 있습니다.

캡처는 `/tmp/gureum-chord-lab-capture.*/events.ndjson`에 저장합니다. 정확한 로그 필터는 다음과 같습니다.

```text
process == "GureumChordLab" AND subsystem == "io.github.kathar0s.inputmethod.GureumChordLab" AND category == "KeyEvents" AND eventMessage BEGINSWITH "CHORDLAB_EVENT"
```

각 이벤트에는 종류, 시스템 가동 시간 기준 시각, 숫자 키 코드, 반복 여부, modifier 값,
클라이언트 번들 ID와 임의 컨트롤러 토큰만 포함합니다. 이 파일은 IMK 전달 경로의 진단 자료이며
CG 탭에서 관찰한 release 전체를 기록하는 파일이 아닙니다. 따라서 IMK `keyUp`이 없다는 사실만으로
물리적 관찰 경로의 성공·실패를 판정하지 않습니다. 상태 표시, 실제 키 해제 시점의 조합 결과와
일반 입력 복귀도 함께 확인해야 합니다. 합성 이벤트는 실제 기기·앱 검증을 대체하지 않습니다.

### 다른 맥북으로 전달하는 시험 패키지

```sh
./tools/package_chord_lab.sh
```

`dist/`에 Apple Silicon·Intel universal 앱, 독립 설치·제거 명령, 한글 안내, 빌드 정보,
라이선스 고지와 체크섬을 포함한 ZIP을 생성합니다. 대상 맥북에는 Xcode가 필요하지 않습니다.
현재 묶음은 Developer ID 서명·공증이 없는 Local Debug/ad-hoc 빌드입니다.
Gatekeeper와 격리 속성을 자동 변경하지 않으므로 ZIP 안의 보안 안내를 확인하세요.

### 일반 구름 디버그 설치

> 어떠한 경우에도 Xcode에서 Run으로 구름 입력기를 실행하거나 빌드한 구름 입력기 앱을 직접 실행하면 **절대** 안됩니다.

디버그 모드로 빌드한 입력기를 설치합니다.

``` sh
cd tools
./install_debug.sh
```

설치 후에는 구름 입력기가 사라질 수 있습니다. 언어 및 입력기 설정을 다시 열고 입력기를 설정해 줍니다.

Console.app 에서 로그를 확인할 수 있습니다.

## 문제 해결

### xcode-select 관련 에러

설치 과정에서 xcode-select 관련 에러가 나타나는 경우

```
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance something wrong
```

아래 명령어를 실행해줍니다.

``` sh
sudo xcode-select -s /Applications/Xcode.app/
```

### xcpretty 관련 에러

설치 과정에서 xcpretty 에러가 나타나는 경우

```
./install_debug.sh: line 6: xcpretty: command not found
```

아래 명령어를 실행해줍니다.

``` sh
sudo gem install xcpretty
```

## 디버거 사용하기

`install_debug.sh`로 설치 후 Xcode에서 Attach to process 기능을 이용하여 디버거를 동작시킬 수는 있지만, 브레이크 포인트를 만들면 디버거 조작 입력이 처리가 되지 않아 디버그하기가 아주 어렵습니다.

가능한 방법 가운데 하나는 breakpoint에 입력기가 진입하면 가능한 빠르게 시스템 입력기로 되돌려서 시스템 입력기로 Xcode를 조작해 디버거를 사용하는 것입니다.

가능하면 로그와 `Console.app`을 먼저 사용해보고 디버거가 필요한 경우에만 디버거를 붙여 쓰는 것을 추천합니다.


## 환경설정 테스트

환경설정은 실제로 시스템 환경설정을 열지 않고도, `OSXTestApp` 타겟을 빌드하면 테스트 앱으로도 변경하면서 테스트할 수 있습니다.

## 커밋하기 전에

### 유닛 테스트 수행

유닛 테스트를 수행하여 현재 작성된 테스트를 여전히 통과하는지 확인해 주세요. <kbd>command</kbd> + <kbd>u</kbd> 단축키로 실행할 수 있습니다.

테스트를 통과하지 못하는 빌드는 CI 과정에서 통과되지 않으며, 마스터 브랜치에 병합될 수 없습니다.

### 입력기 테스트

입력기의 동작을 고치셨다면, 최소한 다음의 프로그램에서 입력기가 정상적으로 동작하는지 확인해 주면 좋습니다.

- TextEdit.app : 아주 일반적인 맥의 입력환경입니다.
- Terminal.app : 한글 조합에 관한 이벤트 발생이 다른 프로그램과 조금 다릅니다. 예를 들어 한글 입력 중에는 리턴 키를 입력하더라도 조합만 해제됩니다.

특수한 입력을 처리했다면 경우에 따라 아래의 프로그램도 확인해 볼 필요가 있습니다.

- Firefox.app : 단축키 입력을 선점하지 않습니다. Modifier를 수정했다면 테스트해 보아야 합니다.
- MS 오피스 2011 : 화살표 키 등 일부 다른 프로그램에서는 전달하지 않는 키코드가 전달됩니다. (issue #3)

### swift-format 실행

변경한 소스 코드에 대해 swift-format을 실행하여 코드의 일관성을 유지해 주세요. swift-format은 Xcode(Swift 툴체인)에 기본 포함되어 있습니다.

CI 과정에서 swift-format lint를 통과하지 못하는 변경 사항이 있으면 빌드는 통과되지 않습니다.

```sh
make format
```
