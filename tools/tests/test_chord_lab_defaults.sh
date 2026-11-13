#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=tools/chord_lab_distribution/lab_defaults.sh
. "${TOOLS_DIR}/chord_lab_distribution/lab_defaults.sh"

host_lab_before=$(/usr/bin/defaults read io.github.kathar0s.GureumChordLab 2>/dev/null || echo __ABSENT__)
host_upstream_before=$(/usr/bin/defaults read org.youknowone.Gureum 2>/dev/null || echo __ABSENT__)
test_root=$(mktemp -d /tmp/gureum-chord-lab-defaults-test.XXXXXX)
touch "${test_root}/.gureum-chord-lab-test-root"
mkdir -p "${test_root}/Library/Preferences"
lab_preferences="${test_root}/Library/Preferences/io.github.kathar0s.GureumChordLab.plist"
upstream_preferences="${test_root}/Library/Preferences/org.youknowone.Gureum.plist"
/usr/bin/plutil -create xml1 "$upstream_preferences"
/usr/libexec/PlistBuddy -c 'Add :HangulAutoReorder bool false' "$upstream_preferences"
upstream_before=$(shasum -a 256 "$upstream_preferences")

initialize_chord_lab_defaults --test-root "$test_root"
test "$(/usr/libexec/PlistBuddy -c 'Print :HangulAutoReorder' "$lab_preferences")" = true
echo 'PASS absent -> true'

/usr/libexec/PlistBuddy -c 'Set :HangulAutoReorder false' "$lab_preferences"
initialize_chord_lab_defaults --test-root "$test_root"
test "$(/usr/libexec/PlistBuddy -c 'Print :HangulAutoReorder' "$lab_preferences")" = false
echo 'PASS existing false preserved'

/usr/libexec/PlistBuddy -c 'Set :HangulAutoReorder true' "$lab_preferences"
initialize_chord_lab_defaults --test-root "$test_root"
test "$(/usr/libexec/PlistBuddy -c 'Print :HangulAutoReorder' "$lab_preferences")" = true
echo 'PASS existing true preserved'

lab_before_uninstall=$(shasum -a 256 "$lab_preferences")
/bin/bash "${TOOLS_DIR}/chord_lab_distribution/uninstall.command" --test-root "$test_root"
test "$lab_before_uninstall" = "$(shasum -a 256 "$lab_preferences")"
test "$upstream_before" = "$(shasum -a 256 "$upstream_preferences")"
echo 'PASS uninstall preserves Lab preferences; unrelated upstream preferences unchanged'

host_lab_after=$(/usr/bin/defaults read io.github.kathar0s.GureumChordLab 2>/dev/null || echo __ABSENT__)
host_upstream_after=$(/usr/bin/defaults read org.youknowone.Gureum 2>/dev/null || echo __ABSENT__)
test "$host_lab_before" = "$host_lab_after"
test "$host_upstream_before" = "$host_upstream_after"
echo 'PASS test-root mode leaves host Lab/upstream defaults unchanged'
echo "Isolated evidence preserved at $test_root"
