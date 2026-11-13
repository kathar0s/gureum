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

### git submodule 가져오기

libhangul의 라이선스 전파성을 피하기 위해 프로젝트를 분리하여 준비가 조금 복잡합니다.

git submodule을 포함하고 있으므로 클론 후 submodule도 가져오도록 해야합니다.

``` sh
git clone --recurse-submodules https://github.com/kathar0s/gureum.git
cd gureum
make init
open Gureum.xcodeproj
```

이 포크의 `libhangul-objc`는 `kathar0s/libhangul-objc`에서 버전이 고정된 커밋을 가져옵니다.
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

이 단계의 빌드는 기존 순차 입력과 자동 순서 교정을 유지합니다.
물리적 모아치기 활성화는 앱별 키 해제 이벤트 계측을 통과한 뒤 별도로 검증합니다.

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
