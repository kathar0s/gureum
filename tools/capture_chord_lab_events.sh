#!/bin/bash
set -euo pipefail

if [[ "${1:-}" == --help ]]; then
    echo "Usage: $0 [seconds: 1..600]"
    echo "Captures only CHORDLAB_EVENT metadata into a new /tmp directory."
    exit 0
fi

DURATION="${1:-60}"
if [[ ! "$DURATION" =~ ^[0-9]{1,3}$ ]]; then
    echo "Capture duration must be between 1 and 600 seconds." >&2
    exit 2
fi
DURATION=$((10#$DURATION))
if (( DURATION < 1 || DURATION > 600 )); then
    echo "Capture duration must be between 1 and 600 seconds." >&2
    exit 2
fi

OUTPUT_DIR=$(mktemp -d /tmp/gureum-chord-lab-capture.XXXXXX)
PREDICATE='process == "GureumChordLab" AND subsystem == "io.github.kathar0s.inputmethod.GureumChordLab" AND category == "KeyEvents" AND eventMessage BEGINSWITH "CHORDLAB_EVENT"'
/usr/bin/log stream --style ndjson --level info --timeout "$DURATION" --predicate "$PREDICATE" \
    > "${OUTPUT_DIR}/events.raw" 2> "${OUTPUT_DIR}/capture.stderr" &
CAPTURE_PID=$!
finish_capture() {
    kill "$CAPTURE_PID" 2>/dev/null || true
    wait "$CAPTURE_PID" 2>/dev/null || true
    # Exclude log stream's filter header and final count record.
    /usr/bin/sed -n '/^{.*"eventMessage"[[:space:]]*:/p' \
        "${OUTPUT_DIR}/events.raw" > "${OUTPUT_DIR}/events.ndjson"
}
trap finish_capture EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "Capture: ${OUTPUT_DIR}/events.ndjson"
echo "Type only a short nonsensitive test in a Lab input source for ${DURATION} seconds."
wait "$CAPTURE_PID"
echo "Capture complete: ${OUTPUT_DIR}/events.ndjson"
