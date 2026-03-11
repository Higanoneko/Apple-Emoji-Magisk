#!/system/bin/sh

. "${0%/*}/lib/common.sh"

ensure_runtime_dirs
restore_backups "log_print"
