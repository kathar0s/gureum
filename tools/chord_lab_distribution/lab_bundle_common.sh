#!/bin/bash

LAB_NAME=GureumChordLab
LAB_BUNDLE_ID=io.github.kathar0s.inputmethod.GureumChordLab
export TEST_MODE=0
export LAB_TEST_ROOT=''

configure_target() {
    local target_home test_root
    target_home="$HOME"
    if [[ $# -gt 0 ]]; then
        if [[ $# -ne 2 || "$1" != --test-root ]]; then
            echo "Usage: $0 [--test-root /absolute/marked-test-directory]" >&2
            exit 2
        fi
        test_root="$(cd "$2" && pwd -P)"
        if [[ "$test_root" == / || "$test_root" == "$HOME" || \
              ! -f "${test_root}/.gureum-chord-lab-test-root" ]]; then
            echo "Test root must contain .gureum-chord-lab-test-root and must not be HOME or /." >&2
            exit 2
        fi
        target_home="$test_root"
        LAB_TEST_ROOT="$test_root"
        TEST_MODE=1
    fi
    INSTALL_DIR="${target_home}/Library/Input Methods"
    INSTALLED_APP="${INSTALL_DIR}/${LAB_NAME}.app"
    BACKUP_DIR="${target_home}/Library/Application Support/${LAB_NAME}/Backups"
}

verify_lab_bundle() {
    local bundle_path bundle_id executable
    bundle_path="$1"
    if [[ -L "$bundle_path" || ! -d "$bundle_path" ]]; then
        echo "Expected a real Lab app directory: $bundle_path" >&2
        exit 1
    fi
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${bundle_path}/Contents/Info.plist")
    executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${bundle_path}/Contents/Info.plist")
    if [[ "$bundle_id" != "$LAB_BUNDLE_ID" || "$executable" != "$LAB_NAME" ]]; then
        echo "Refusing a bundle with an unexpected identity: $bundle_path" >&2
        exit 1
    fi
    /usr/bin/codesign --verify --deep --strict "$bundle_path"
}

archive_existing_lab() {
    if [[ -e "$INSTALLED_APP" || -L "$INSTALLED_APP" ]]; then
        verify_lab_bundle "$INSTALLED_APP"
        mkdir -p "$BACKUP_DIR"
        local archive_dir
        archive_dir=$(mktemp -d "${BACKUP_DIR}/lab.XXXXXX")
        mv "$INSTALLED_APP" "${archive_dir}/${LAB_NAME}.app"
        echo "기존 Lab 보관: ${archive_dir}/${LAB_NAME}.app"
    fi
}
