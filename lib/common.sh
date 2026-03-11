[ -n "$_APPLE_EMOJI_COMMON_SH" ] && return
_APPLE_EMOJI_COMMON_SH=1

if [ -z "$MODPATH" ]; then
    SCRIPT_REAL_PATH="$(readlink -f "$0" 2>/dev/null || echo "$0")"
    MODPATH="${SCRIPT_REAL_PATH%/*}"
fi

MODULE_PARENT="/data/adb/modules"
SELF_MOD_NAME="$(basename "$MODPATH")"
TARGET_FONT_REL_PATH="system/fonts/NotoColorEmoji.ttf"
BACKUP_ROOT="$MODPATH/backup"
SHA1_DIR="$MODPATH/sha1"
LOG_FILE="$MODPATH/conflict-clean.log"
LOCK_DIR="/data/adb/apple_emoji_lock"

ensure_runtime_dirs() {
    mkdir -p "$BACKUP_ROOT" "$SHA1_DIR"
}

log_print() {
    local message="$1"
    printf '%s\n' "$message" >> "$LOG_FILE"
    if command -v log >/dev/null 2>&1; then
        log -t AppleEmoji "$message"
    fi
}

print_message() {
    local printer="$1"
    local message="$2"

    case "$printer" in
        ui_print)
            ui_print "$message"
            ;;
        log_print)
            log_print "$message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

acquire_lock() {
    local attempt=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        attempt=$((attempt + 1))
        [ "$attempt" -ge 100 ] && return 1
        sleep 0.1
    done
    return 0
}

release_lock() {
    rmdir "$LOCK_DIR" 2>/dev/null || true
}

sanitize_name() {
    printf '%s' "$1" | tr '/ ' '__'
}

sha1_file_for_module() {
    local module_name="$1"
    printf '%s/%s.sha1' "$SHA1_DIR" "$(sanitize_name "$module_name")"
}

write_sha1_atomic() {
    local sha1_value="$1"
    local target_file="$2"

    if ! printf '%s' "$sha1_value" > "${target_file}.tmp"; then
        return 1
    fi

    mv -f "${target_file}.tmp" "$target_file"
}

remove_empty_parent_dir() {
    local target_dir="$1"

    if [ -d "$target_dir" ] && [ -z "$(ls -A "$target_dir" 2>/dev/null)" ]; then
        rmdir "$target_dir" 2>/dev/null || true
    fi
}

process_conflicting_font() {
    local printer="$1"
    local module_name="$2"
    local target_file="$3"
    local backup_file="$BACKUP_ROOT/$module_name/$TARGET_FONT_REL_PATH"
    local backup_dir
    local target_dir
    local current_sha1=""

    backup_dir="${backup_file%/*}"
    target_dir="${target_file%/*}"

    mkdir -p "$backup_dir"

    if command -v sha1sum >/dev/null 2>&1; then
        current_sha1="$(sha1sum "$target_file" | cut -d' ' -f1)"
    fi

    if ! cp -af "$target_file" "$backup_file"; then
        print_message "$printer" "AppleEmoji: failed to back up $target_file"
        return 1
    fi

    if [ -n "$current_sha1" ]; then
        write_sha1_atomic "$current_sha1" "$(sha1_file_for_module "$module_name")" || {
            print_message "$printer" "AppleEmoji: failed to write checksum for $module_name"
        }
    fi

    if ! rm -f "$target_file"; then
        print_message "$printer" "AppleEmoji: failed to remove conflicting font from $module_name"
        return 1
    fi

    remove_empty_parent_dir "$target_dir"
    print_message "$printer" "AppleEmoji: removed conflicting $TARGET_FONT_REL_PATH from module $module_name"
    return 0
}

cleanup_stale_backups() {
    local printer="$1"
    local backup_dir
    local module_name
    local module_dir
    local sha1_file

    [ -d "$BACKUP_ROOT" ] || return 0

    for backup_dir in "$BACKUP_ROOT"/*; do
        [ -d "$backup_dir" ] || continue
        module_name="$(basename "$backup_dir")"
        module_dir="$MODULE_PARENT/$module_name"
        sha1_file="$(sha1_file_for_module "$module_name")"

        if [ ! -d "$module_dir" ]; then
            rm -rf "$backup_dir"
            rm -f "$sha1_file"
            print_message "$printer" "AppleEmoji: removed stale backup for missing module $module_name"
        fi
    done
}

scan_and_clean_conflicts() {
    local printer="$1"
    local module_dir
    local module_name
    local target_file
    local found_conflict=0

    if [ ! -f "$MODPATH/$TARGET_FONT_REL_PATH" ]; then
        print_message "$printer" "AppleEmoji: module font $TARGET_FONT_REL_PATH is missing."
        return 1
    fi

    for module_dir in "$MODULE_PARENT"/*; do
        [ -d "$module_dir" ] || continue
        module_name="$(basename "$module_dir")"

        if [ "$module_name" = "$SELF_MOD_NAME" ] || [ -f "$module_dir/disable" ] || [ -f "$module_dir/remove" ]; then
            continue
        fi

        target_file="$module_dir/$TARGET_FONT_REL_PATH"
        [ -f "$target_file" ] || continue

        found_conflict=1
        process_conflicting_font "$printer" "$module_name" "$target_file"
    done

    cleanup_stale_backups "$printer"

    if [ "$found_conflict" -eq 0 ]; then
        print_message "$printer" "AppleEmoji: no conflicting $TARGET_FONT_REL_PATH found in other modules"
    fi

    return 0
}

restore_backups() {
    local printer="$1"
    local backup_dir
    local module_name
    local module_dir
    local backup_file
    local target_file
    local target_dir

    [ -d "$BACKUP_ROOT" ] || return 0

    for backup_dir in "$BACKUP_ROOT"/*; do
        [ -d "$backup_dir" ] || continue
        module_name="$(basename "$backup_dir")"
        module_dir="$MODULE_PARENT/$module_name"
        backup_file="$backup_dir/$TARGET_FONT_REL_PATH"

        [ -f "$backup_file" ] || continue
        [ -d "$module_dir" ] || continue

        target_file="$module_dir/$TARGET_FONT_REL_PATH"
        target_dir="${target_file%/*}"

        if [ -f "$target_file" ]; then
            print_message "$printer" "AppleEmoji: skip restoring $module_name because target font already exists"
            continue
        fi

        mkdir -p "$target_dir"
        if cp -af "$backup_file" "$target_file"; then
            print_message "$printer" "AppleEmoji: restored $TARGET_FONT_REL_PATH to module $module_name"
        else
            print_message "$printer" "AppleEmoji: failed to restore $TARGET_FONT_REL_PATH to module $module_name"
        fi
    done
}
