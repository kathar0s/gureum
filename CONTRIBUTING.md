# 바람 입력기에 기여하기

버그 보고, 자판 자료 보완, 문서와 코드 개선을 환영합니다. Baram은 일상 입력을 다루므로 작은 변경도 기존 동작과 복구 가능성을 우선합니다.

## 버그 보고

[GitHub Issues](https://github.com/sionyuel/baram/issues)에 다음 정보를 포함해 주세요.

- macOS 버전과 Mac 종류(Apple Silicon 또는 Intel)
- Baram 버전: 입력기 메뉴의 `About`에서 확인
- 사용한 자판과 관련 설정
- 문제가 발생한 앱과 버전
- 누른 키 순서, 기대 결과, 실제 결과
- 가능하면 민감한 내용이 없는 최소 재현 문장

입력 내용 노출, 권한 우회, 업데이트 공급망처럼 보안과 관련된 문제는 공개 이슈를 만들지 말고 [SECURITY.md](SECURITY.md)를 따라 주세요.

## 개선 제안

- 실제 불편과 재현 사례를 먼저 설명해 주세요.
- 기본 동작 변경은 기존 사용자에게 미치는 영향을 함께 적어 주세요.
- 새 자판은 출처, 배열 규칙, 조합 규칙, 라이선스를 밝혀 주세요.
- UI 제안은 가능하면 현재 macOS System Settings와 비교 자료를 포함해 주세요.

## 개발 흐름

```sh
git clone --recurse-submodules https://github.com/sionyuel/baram.git
cd baram
make init
```

작은 단위로 수정하고 관련 회귀 테스트를 먼저 추가해 주세요. 전체 테스트는 다음과 같습니다.

```sh
xcodebuild -project Gureum.xcodeproj -scheme OSX -sdk macosx \
  -destination 'platform=macOS' test \
  -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

Swift 파일은 `swift format lint --strict <files>`를 통과해야 하며 `git diff --check`로 공백 오류를 확인합니다.

## Pull Request

- 한 PR은 하나의 문제를 해결하도록 범위를 좁혀 주세요.
- 사용자에게 보이는 변경, 테스트 증거, 남은 위험을 본문에 적어 주세요.
- 입력기 식별자, 설정 키, 마이그레이션, 권한 요청을 바꾸는 경우 호환성 계획을 포함해 주세요.
- 새 의존성은 추가 이유와 라이선스를 명시해 주세요.
- `libhangul-objc` 같은 서브모듈 변경은 하위 저장소 커밋을 먼저 공개한 뒤 부모 포인터를 갱신해 주세요.

## 우선순위 원칙

1. 입력 손실·오조합·설치 실패 같은 정확성 문제
2. 기존 기능의 일관성과 접근성
3. 문서와 진단 가능성
4. 새 기능

Baram은 Gureum과 libhangul의 기여 위에서 만들어집니다. 기존 저작권과 라이선스 고지를 삭제하거나 축소하지 마세요.
