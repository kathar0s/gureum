#!/bin/bash
set -euo pipefail

variant="${GUREUM_VARIANT:-STANDARD}"
resources_dir="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
case "$variant" in
    STANDARD) exit 0 ;;
    LAB)
        input_prefix='io.github.kathar0s.inputmethod.GureumChordLab'
        english_prefix='Lab · '
        korean_prefix='Lab · '
        bundle_name='GureumChordLab'
        display_name='Gureum Chord Lab'
        ;;
    BARAM)
        input_prefix='com.sionyuel.inputmethod.Baram'
        english_prefix='Baram · '
        korean_prefix='바람 · '
        bundle_name='Baram'
        display_name='Baram Input Method'
        ;;
    *) echo "Unsupported GUREUM_VARIANT: $variant" >&2; exit 2 ;;
esac

while IFS= read -r -d '' strings_file; do
    /usr/bin/plutil -convert xml1 "$strings_file"
    locale_prefix="$english_prefix"
    localized_bundle_name="$bundle_name"
    localized_display_name="$display_name"
    if [[ "$strings_file" == *'/ko.lproj/'* && "$variant" == BARAM ]]; then
        locale_prefix="$korean_prefix"
        localized_bundle_name='바람'
        localized_display_name='바람 입력기'
    fi
    /usr/bin/sed -i '' \
        -e "s#org\.youknowone\.inputmethod\.Gureum#${input_prefix}#g" \
        -e "s#<string>${locale_prefix}#<string>#g" \
        -e "s#<string>#<string>${locale_prefix}#g" "$strings_file"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $localized_bundle_name" "$strings_file"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $localized_display_name" "$strings_file"
done < <(find "$resources_dir" -path '*.lproj/InfoPlist.strings' -print0)

if [[ "$variant" == BARAM ]]; then
    direct_icons_dir="${SRCROOT}/OSX/InputSourceIcons"
    while IFS= read -r -d '' icon_file; do
        /usr/bin/ditto "$icon_file" "${resources_dir}/$(basename "$icon_file")"
    done < <(find "$direct_icons_dir" -maxdepth 1 -type f -name '*.png' -print0)
fi
