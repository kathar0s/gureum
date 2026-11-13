# Hangul.framework에 대응하는 LGPL 소스

두 압축 파일은 이 앱을 빌드할 때 사용한 Git 커밋의 전체 추적 파일을 보존한 `git archive`입니다.
소스 코드, Xcode 프로젝트, 빌드 스크립트, 라이선스 파일을 포함합니다. 정확한 커밋과 Git 트리 ID는
옆의 `source-provenance.json` 및 상위 `build-info.json`에 기록되어 있습니다.
소스 압축 파일의 SHA-256 값은 상위 `SHA256SUMS`에 포함되어 있습니다.

- `libhangul-objc-source.tar.gz`: Objective-C 래퍼와 Xcode 빌드 프로젝트.
- `libhangul-source.tar.gz`: 래퍼가 내부 서브모듈로 사용하는 C 라이브러리 전체 소스.

새 작업 폴더에서 다음 순서로 압축을 풀면 원래 중첩 디렉터리 구조가 복원됩니다.

```sh
tar -xzf /패키지/Sources/libhangul-objc-source.tar.gz
tar -xzf /패키지/Sources/libhangul-source.tar.gz -C libhangul-objc
```

Git 기록 전체를 내려받을 필요가 없습니다. 원래 서브모듈 항목만으로는 내부 소스가 복원되지 않으므로
두 번째 압축 파일을 반드시 첫 번째 폴더 안에 풉니다.

Xcode와 해당 macOS SDK가 설치된 개발 환경에서 래퍼 프레임워크를 빌드할 수 있습니다.
실제 패키지 빌드 도구 버전은 상위 `build-info.json`에 있으며 macOS 배포 대상은 12.0입니다.

```sh
cd libhangul-objc
xcodebuild -project Hangul.xcodeproj -scheme Hangul -configuration Debug \
  -sdk macosx -destination 'generic/platform=macOS' \
  -derivedDataPath ./build ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

성공하면 `build/Build/Products/Debug/Hangul.framework`가 생성됩니다. 이 앱은 해당 프레임워크를
`GureumChordLab.app/Contents/Frameworks/Hangul.framework`에서 동적으로 불러옵니다.
LGPL 조건에 따라 수정·재빌드한 호환 프레임워크로 교체할 수 있습니다. 앱을 수정하면 원래 무결성 서명은
무효화되므로 본인이 수정한 로컬 앱에 ad-hoc 서명을 다시 적용할 수 있습니다.

```sh
codesign --force --deep --sign - --timestamp=none /수정한/GureumChordLab.app
```

이 명령은 Developer ID 인증이나 Apple 공증을 제공하지 않으며 Gatekeeper 정책도 변경하지 않습니다.
서명·격리 관련 설명은 상위 `README.ko.md`, LGPL 원문은 상위 `LICENSES/`와 각 소스의 `COPYING`을 확인하세요.
