#!/bin/bash
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tools/chord_lab_distribution/lab_bundle_common.sh
. "${PACKAGE_DIR}/lab_bundle_common.sh"
configure_target "$@"

(cd "$PACKAGE_DIR" && /usr/bin/shasum -a 256 --status -c SHA256SUMS)
verify_lab_bundle "${PACKAGE_DIR}/${LAB_NAME}.app"
mkdir -p "$INSTALL_DIR"
STAGING_DIR=$(mktemp -d "${INSTALL_DIR}/.GureumChordLab-install.XXXXXX")
/usr/bin/ditto "${PACKAGE_DIR}/${LAB_NAME}.app" "${STAGING_DIR}/${LAB_NAME}.app"
verify_lab_bundle "${STAGING_DIR}/${LAB_NAME}.app"
archive_existing_lab
mv "${STAGING_DIR}/${LAB_NAME}.app" "$INSTALLED_APP"
rmdir "$STAGING_DIR"
verify_lab_bundle "$INSTALLED_APP"
# shellcheck source=tools/chord_lab_distribution/lab_defaults.sh
. "${PACKAGE_DIR}/lab_defaults.sh"
if [[ "$TEST_MODE" -eq 0 ]]; then
    initialize_chord_lab_defaults
else
    initialize_chord_lab_defaults --test-root "$LAB_TEST_ROOT"
fi

if [[ "$TEST_MODE" -eq 0 ]]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f "$INSTALLED_APP"
    if ! "${PACKAGE_DIR}/register-input-source" "$INSTALLED_APP"; then
        echo "자동 등록이 완료되지 않았습니다. 로그아웃 후 다시 로그인해 주세요." >&2
    fi
fi

echo "설치 완료: $INSTALLED_APP"
echo "시스템 설정 > 키보드 > 텍스트 입력에서 Lab · 세벌식 자판을 추가하세요."
echo "목록에 없거나 선택되지 않으면 로그아웃 후 다시 로그인하세요."
echo "이 패키지는 Developer ID 서명·공증이 없는 Local Debug/ad-hoc 실험 빌드입니다."
