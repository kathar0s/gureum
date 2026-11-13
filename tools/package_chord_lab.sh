#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_DIR}/build/chord-lab-distribution"
DIST_DIR="${REPO_DIR}/dist"
APP_PATH="${REPO_DIR}/build/chord-lab/Build/Products/Debug/GureumChordLab.app"
SOURCE_COMMIT="$(git -C "$REPO_DIR" rev-parse HEAD)"
LGPL_OBJC_DIR="${REPO_DIR}/libhangul-objc"
LGPL_C_DIR="${LGPL_OBJC_DIR}/libhangul"
LGPL_OBJC_COMMIT="$(git -C "$LGPL_OBJC_DIR" rev-parse HEAD)"
LGPL_C_COMMIT="$(git -C "$LGPL_C_DIR" rev-parse HEAD)"
BUILD_TIME="$(date -u +%Y%m%dT%H%M%SZ)"
PACKAGE_NAME="GureumChordLab-LocalDebug-universal-${SOURCE_COMMIT:0:12}-${BUILD_TIME}"
PACKAGE_DIR="${DIST_DIR}/${PACKAGE_NAME}"
ZIP_PATH="${DIST_DIR}/${PACKAGE_NAME}.zip"
VERSION_SNAPSHOT=$(mktemp /tmp/gureum-chord-lab-version.XXXXXX)
cp "${REPO_DIR}/OSX/Version.xcconfig" "$VERSION_SNAPSHOT"
restore_generated_version() {
    cp "$VERSION_SNAPSHOT" "${REPO_DIR}/OSX/Version.xcconfig"
    rm "$VERSION_SNAPSHOT"
}
trap restore_generated_version EXIT

verify_lgpl_sources() {
    if [[ "$(git -C "$LGPL_OBJC_DIR" rev-parse HEAD)" != "$LGPL_OBJC_COMMIT" || \
          "$(git -C "$LGPL_C_DIR" rev-parse HEAD)" != "$LGPL_C_COMMIT" ]] || \
       ! git -C "$LGPL_OBJC_DIR" diff --quiet HEAD || \
       ! git -C "$LGPL_C_DIR" diff --quiet HEAD; then
        echo "LGPL source commits must stay unchanged and clean while packaging." >&2
        exit 1
    fi
}
verify_lgpl_sources

SOURCE_DIRTY=false
if ! git -C "$REPO_DIR" diff --quiet HEAD; then SOURCE_DIRTY=true; fi
mkdir -p "$BUILD_DIR" "$DIST_DIR"
if [[ -e "$PACKAGE_DIR" || -e "$ZIP_PATH" ]]; then
    echo "Refusing to overwrite an existing distribution: $PACKAGE_NAME" >&2
    exit 1
fi

# No Developer ID identity is required or silently selected: this is a Local Debug package.
GUREUM_LAB_ARCHS='arm64 x86_64' "${SCRIPT_DIR}/install_chord_lab.sh" --build-only
for app_arch in arm64 x86_64; do
    /usr/bin/lipo -verify_arch "$app_arch" "$APP_PATH/Contents/MacOS/GureumChordLab"
done

for helper_arch in arm64 x86_64; do
    xcrun swiftc -O -target "${helper_arch}-apple-macos12.0" \
        "${SCRIPT_DIR}/chord_lab_distribution/register_input_source.swift" \
        -o "${BUILD_DIR}/register-input-source-${helper_arch}"
done
/usr/bin/lipo -create "${BUILD_DIR}/register-input-source-arm64" \
    "${BUILD_DIR}/register-input-source-x86_64" -output "${BUILD_DIR}/register-input-source"
/usr/bin/codesign --force --sign - --timestamp=none "${BUILD_DIR}/register-input-source"

mkdir "$PACKAGE_DIR"
/usr/bin/ditto "$APP_PATH" "${PACKAGE_DIR}/GureumChordLab.app"
cp "${SCRIPT_DIR}/chord_lab_distribution/README.ko.md" "${PACKAGE_DIR}/README.ko.md"
cp "${SCRIPT_DIR}/chord_lab_distribution/install.command" "${PACKAGE_DIR}/install.command"
cp "${SCRIPT_DIR}/chord_lab_distribution/uninstall.command" "${PACKAGE_DIR}/uninstall.command"
cp "${SCRIPT_DIR}/chord_lab_distribution/lab_bundle_common.sh" "${PACKAGE_DIR}/lab_bundle_common.sh"
cp "${SCRIPT_DIR}/chord_lab_distribution/lab_defaults.sh" "${PACKAGE_DIR}/lab_defaults.sh"
cp "${SCRIPT_DIR}/capture_chord_lab_events.sh" "${PACKAGE_DIR}/capture-events.command"
/usr/bin/ditto "${BUILD_DIR}/register-input-source" "${PACKAGE_DIR}/register-input-source"
chmod +x "${PACKAGE_DIR}/install.command" "${PACKAGE_DIR}/uninstall.command" \
    "${PACKAGE_DIR}/capture-events.command"

mkdir "${PACKAGE_DIR}/LICENSES"
cp "${REPO_DIR}/COPYING" "${PACKAGE_DIR}/LICENSES/Gureum-BSD.txt"
cp "${REPO_DIR}/OSX/Icons/COPYING" "${PACKAGE_DIR}/LICENSES/Gureum-icons.txt"
cp "${REPO_DIR}/libhangul-objc/COPYING" "${PACKAGE_DIR}/LICENSES/libhangul-objc-LGPL.txt"
cp "${REPO_DIR}/libhangul-objc/libhangul/COPYING" "${PACKAGE_DIR}/LICENSES/libhangul-LGPL.txt"
cp "${REPO_DIR}/Gureum.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" \
    "${PACKAGE_DIR}/LICENSES/Package.resolved"
for dependency_dir in "${REPO_DIR}/build/chord-lab/SourcePackages/checkouts/"*; do
    for license_name in LICENSE LICENSE.txt LICENSE.md COPYING NOTICE; do
        if [[ -f "${dependency_dir}/${license_name}" ]]; then
            cp "${dependency_dir}/${license_name}" \
                "${PACKAGE_DIR}/LICENSES/$(basename "$dependency_dir")-${license_name}"
        fi
    done
done

verify_lgpl_sources
mkdir "${PACKAGE_DIR}/Sources"
git -C "$LGPL_OBJC_DIR" archive --format=tar.gz --prefix=libhangul-objc/ \
    -o "${PACKAGE_DIR}/Sources/libhangul-objc-source.tar.gz" "$LGPL_OBJC_COMMIT"
git -C "$LGPL_C_DIR" archive --format=tar.gz --prefix=libhangul/ \
    -o "${PACKAGE_DIR}/Sources/libhangul-source.tar.gz" "$LGPL_C_COMMIT"
cp "${SCRIPT_DIR}/chord_lab_distribution/Sources-README.ko.md" "${PACKAGE_DIR}/Sources/README.ko.md"
SOURCE_INFO="${BUILD_DIR}/source-provenance-${BUILD_TIME}.plist"
/usr/bin/plutil -create xml1 "$SOURCE_INFO"
/usr/bin/plutil -insert libhangulObjcCommit -string "$LGPL_OBJC_COMMIT" "$SOURCE_INFO"
/usr/bin/plutil -insert libhangulCommit -string "$LGPL_C_COMMIT" "$SOURCE_INFO"
/usr/bin/plutil -insert libhangulObjcTree -string "$(git -C "$LGPL_OBJC_DIR" rev-parse "${LGPL_OBJC_COMMIT}^{tree}")" "$SOURCE_INFO"
/usr/bin/plutil -insert libhangulTree -string "$(git -C "$LGPL_C_DIR" rev-parse "${LGPL_C_COMMIT}^{tree}")" "$SOURCE_INFO"
/usr/bin/plutil -insert libhangulObjcArchive -string 'libhangul-objc-source.tar.gz' "$SOURCE_INFO"
/usr/bin/plutil -insert libhangulArchive -string 'libhangul-source.tar.gz' "$SOURCE_INFO"
/usr/bin/plutil -convert json -o "${PACKAGE_DIR}/Sources/source-provenance.json" "$SOURCE_INFO"

INFO_PLIST="${BUILD_DIR}/build-info-${BUILD_TIME}.plist"
/usr/bin/plutil -create xml1 "$INFO_PLIST"
/usr/bin/plutil -insert sourceCommit -string "$SOURCE_COMMIT" "$INFO_PLIST"
APP_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")
/usr/bin/plutil -insert appVersion -string "$APP_VERSION" "$INFO_PLIST"
/usr/bin/plutil -insert builtAtUTC -string "$BUILD_TIME" "$INFO_PLIST"
/usr/bin/plutil -insert architecture -string 'arm64 x86_64' "$INFO_PLIST"
/usr/bin/plutil -insert minimumMacOS -string '12.0' "$INFO_PLIST"
/usr/bin/plutil -insert configuration -string 'Debug' "$INFO_PLIST"
/usr/bin/plutil -insert signing -string 'ad-hoc; no Developer ID' "$INFO_PLIST"
/usr/bin/plutil -insert notarized -bool false "$INFO_PLIST"
/usr/bin/plutil -insert sourceWorktreeDirty -bool "$SOURCE_DIRTY" "$INFO_PLIST"
/usr/bin/plutil -insert physicalChordingVerified -bool false "$INFO_PLIST"
/usr/bin/plutil -insert libhangulObjcSourceCommit -string "$LGPL_OBJC_COMMIT" "$INFO_PLIST"
/usr/bin/plutil -insert libhangulSourceCommit -string "$LGPL_C_COMMIT" "$INFO_PLIST"
/usr/bin/plutil -insert correspondingSourceIncluded -bool true "$INFO_PLIST"
/usr/bin/plutil -insert autoReorderEnabledOnlyWhenUnset -bool true "$INFO_PLIST"
/usr/bin/plutil -insert buildTool -string "$(xcodebuild -version | tr '\n' ' ')" "$INFO_PLIST"
/usr/bin/plutil -convert json -o "${PACKAGE_DIR}/build-info.json" "$INFO_PLIST"

/usr/bin/codesign --verify --deep --strict "${PACKAGE_DIR}/GureumChordLab.app"
/usr/bin/codesign --verify --strict "${PACKAGE_DIR}/register-input-source"
(cd "$PACKAGE_DIR" && find . -type f ! -name SHA256SUMS -print0 | \
    LC_ALL=C sort -z | xargs -0 /usr/bin/shasum -a 256 > "${BUILD_DIR}/SHA256SUMS")
cp "${BUILD_DIR}/SHA256SUMS" "${PACKAGE_DIR}/SHA256SUMS"
(cd "$PACKAGE_DIR" && /usr/bin/shasum -a 256 --status -c SHA256SUMS)
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_DIR" "$ZIP_PATH"
(cd "$DIST_DIR" && /usr/bin/shasum -a 256 "${PACKAGE_NAME}.zip" > "${PACKAGE_NAME}.zip.sha256")
echo "Portable Local Debug directory: $PACKAGE_DIR"
echo "Portable Local Debug ZIP: $ZIP_PATH"
echo "ZIP checksum: ${ZIP_PATH}.sha256"
