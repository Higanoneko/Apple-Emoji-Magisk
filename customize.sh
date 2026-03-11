SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=true
LATESTARTSERVICE=true

. "$MODPATH/lib/common.sh"

ui_print "*******************************"
ui_print " Apple Emoji conflict cleanup "
ui_print "*******************************"

ensure_runtime_dirs

chmod 0755 "$MODPATH/action.sh" 2>/dev/null
chmod 0755 "$MODPATH/post-fs-data.sh" 2>/dev/null
chmod 0755 "$MODPATH/service.sh" 2>/dev/null
chmod 0755 "$MODPATH/uninstall.sh" 2>/dev/null
chmod 0755 "$MODPATH/lib/common.sh" 2>/dev/null

if acquire_lock; then
    scan_and_clean_conflicts "ui_print"
    release_lock
else
    ui_print "AppleEmoji: another cleanup task is already running, skip install-time scan."
fi
