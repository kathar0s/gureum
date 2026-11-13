#!/bin/bash

initialize_chord_lab_defaults() {
    local lab_suite=io.github.kathar0s.GureumChordLab
    if [[ $# -eq 0 ]]; then
        if ! /usr/bin/defaults read "$lab_suite" HangulAutoReorder >/dev/null 2>&1; then
            /usr/bin/defaults write "$lab_suite" HangulAutoReorder -bool true
            echo "Lab 자동 순서 교정을 처음 켰습니다. 기존에 저장된 선택은 보존합니다."
        fi
        return
    fi

    local test_root preferences_file
    if [[ $# -ne 2 || "$1" != --test-root ]]; then
        echo "Expected no arguments or --test-root marked-directory." >&2
        return 2
    fi
    test_root="$(cd "$2" && pwd -P)"
    if [[ "$test_root" == / || "$test_root" == "$HOME" || \
          ! -f "${test_root}/.gureum-chord-lab-test-root" ]]; then
        echo "Refusing an unmarked defaults test root." >&2
        return 2
    fi
    preferences_file="${test_root}/Library/Preferences/${lab_suite}.plist"
    if ! /usr/libexec/PlistBuddy -c 'Print :HangulAutoReorder' "$preferences_file" >/dev/null 2>&1; then
        mkdir -p "$(dirname "$preferences_file")"
        if [[ ! -e "$preferences_file" ]]; then
            /usr/bin/plutil -create xml1 "$preferences_file"
        fi
        /usr/libexec/PlistBuddy -c 'Add :HangulAutoReorder bool true' "$preferences_file"
    fi
}
