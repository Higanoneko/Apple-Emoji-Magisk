#!/system/bin/sh

. "${0%/*}/lib/common.sh"

ensure_runtime_dirs

if ! acquire_lock; then
    log_print "AppleEmoji: skip late_start cleanup because another task holds the lock."
    exit 0
fi

trap 'release_lock' INT TERM EXIT

scan_and_clean_conflicts "log_print"
