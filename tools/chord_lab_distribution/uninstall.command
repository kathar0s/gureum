#!/bin/bash
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tools/chord_lab_distribution/lab_bundle_common.sh
. "${PACKAGE_DIR}/lab_bundle_common.sh"
configure_target "$@"
archive_existing_lab
echo "Lab 제거 완료. 보관된 앱은 다시 복사할 수 있습니다."
echo "현재 입력기를 ABC 또는 macOS 기본 한글로 선택하고 필요하면 재로그인하세요."
