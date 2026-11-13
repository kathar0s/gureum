#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LAB_NAME=GureumChordLab
LAB_BUNDLE_ID=io.github.kathar0s.inputmethod.GureumChordLab
BUILD_DIR="${REPO_DIR}/build/chord-lab"
APP_PATH="${BUILD_DIR}/Build/Products/Debug/${LAB_NAME}.app"
INSTALL_DIR="${HOME}/Library/Input Methods"
INSTALLED_APP="${INSTALL_DIR}/${LAB_NAME}.app"
MODE="${1:---build-only}"

usage() {
    echo "Usage: $0 [--build-only|--install|--uninstall|--help]"
    echo "Builds a separately identified GureumChordLab input method."
}

verify_lab() {
    local bundle_id
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist")
    if [[ "$bundle_id" != "$LAB_BUNDLE_ID" ]]; then
        echo "Refusing to modify a bundle with an unexpected identity: $1" >&2
        exit 1
    fi
}

stop_installed_lab() {
    local lab_pid executable_path
    while IFS= read -r lab_pid; do
        executable_path=$(/bin/ps -p "$lab_pid" -o comm= || true)
        if [[ "$executable_path" == "${INSTALLED_APP}/Contents/MacOS/${LAB_NAME}" ]]; then
            /bin/kill -TERM "$lab_pid"
        fi
    done < <(/usr/bin/pgrep -x "$LAB_NAME" || true)
}

archive_installed_lab() {
    if [[ -e "$INSTALLED_APP" ]]; then
        verify_lab "$INSTALLED_APP"
        stop_installed_lab
        mkdir -p "${BUILD_DIR}/backups"
        local backup_dir
        backup_dir=$(mktemp -d "${BUILD_DIR}/backups/lab.XXXXXX")
        mv "$INSTALLED_APP" "${backup_dir}/${LAB_NAME}.app"
        echo "Previous lab bundle preserved at ${backup_dir}/${LAB_NAME}.app"
    fi
}

case "$MODE" in
    --help) usage; exit 0 ;;
    --build-only|--install) ;;
    --uninstall)
        archive_installed_lab
        echo "GureumChordLab removed. Select your regular input source."
        exit 0
        ;;
    *) usage >&2; exit 2 ;;
esac

cd "$REPO_DIR"
xcodebuild -project Gureum.xcodeproj -scheme OSX -configuration Debug \
    -sdk macosx -destination 'platform=macOS' -derivedDataPath "$BUILD_DIR" \
    -onlyUsePackageVersionsFromResolvedFile GUREUM_VARIANT=LAB \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

verify_lab "$APP_PATH"

# Only transform copied build resources; source localizations remain upstream-compatible.
while IFS= read -r -d '' strings_file; do
    /usr/bin/plutil -convert xml1 "$strings_file"
    /usr/bin/sed -i '' \
        -e 's/org\.youknowone\.inputmethod\.Gureum/io.github.kathar0s.inputmethod.GureumChordLab/g' \
        -e 's#<string>Lab · #<string>#g' \
        -e 's#<string>#<string>Lab · #g' "$strings_file"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleName GureumChordLab' "$strings_file"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Gureum Chord Lab' "$strings_file"
done < <(find "${APP_PATH}/Contents/Resources" -path '*.lproj/InfoPlist.strings' -print0)

/usr/bin/codesign --force --deep --sign - --timestamp=none "$APP_PATH"
/usr/bin/codesign --verify --deep --strict "$APP_PATH"
echo "Verified lab build: $APP_PATH"

if [[ "$MODE" == --install ]]; then
    mkdir -p "$INSTALL_DIR"
    archive_installed_lab
    /usr/bin/ditto "$APP_PATH" "$INSTALLED_APP"
    verify_lab "$INSTALLED_APP"
    /usr/bin/codesign --verify --deep --strict "$INSTALLED_APP"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f "$INSTALLED_APP"
    echo "Installed: $INSTALLED_APP"
    echo "Add a Lab input source in System Settings > Keyboard > Text Input."
    echo "If it is not listed yet, log out and back in."
fi
