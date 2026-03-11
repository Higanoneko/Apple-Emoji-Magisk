#!/system/bin/sh

ui_print() { echo "$1"; }

. "${0%/*}/lib/common.sh"

ensure_runtime_dirs

if ! acquire_lock; then
    ui_print "AppleEmoji: another cleanup task is already running."
    exit 0
fi

trap 'release_lock' INT TERM EXIT

scan_and_clean_conflicts "ui_print"
