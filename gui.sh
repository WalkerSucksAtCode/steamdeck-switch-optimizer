#!/bin/bash
# Desktop Mode menu. Needs zenity or kdialog.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${TMPDIR:-/tmp}/steamdeck-switch-optimizer.log"
TITLE="Switch optimizer"

have() { command -v "$1" >/dev/null 2>&1; }

if ! have zenity && ! have kdialog; then
    echo "Need zenity or kdialog. Or run the .sh scripts directly." >&2
    exit 1
fi

ui_info() {
    local msg=$1
    if have zenity; then
        zenity --info --title="$TITLE" --width=420 --text="$msg" 2>/dev/null || true
    else
        kdialog --title "$TITLE" --msgbox "$msg" 2>/dev/null || true
    fi
}

ui_error() {
    local msg=$1
    if have zenity; then
        zenity --error --title="$TITLE" --width=420 --text="$msg" 2>/dev/null || true
    else
        kdialog --title "$TITLE" --error "$msg" 2>/dev/null || true
    fi
}

ui_confirm() {
    local msg=$1
    if have zenity; then
        zenity --question --title="$TITLE" --width=420 --text="$msg" 2>/dev/null
    else
        kdialog --title "$TITLE" --yesno "$msg" 2>/dev/null
    fi
}

ui_menu() {
    if have zenity; then
        zenity --list --title="$TITLE" --width=520 --height=420 \
            --text="Action:" \
            --column="Id" --column="What" \
            "diagnostic" "System / emu / keys" \
            "apply" "Backup + patch configs" \
            "storage" "Disk usage" \
            "cleanup-dry" "Cleanup dry-run" \
            "cleanup-apply" "Cleanup apply (safe caches)" \
            "orphans" "Orphaned compatdata" \
            "log" "Last log" \
            "docs" "verified-optimizations.md" \
            "quit" "Quit" \
            2>/dev/null
    else
        kdialog --title "$TITLE" --menu "Action:" \
            diagnostic "System / emu / keys" \
            apply "Backup + patch configs" \
            storage "Disk usage" \
            cleanup-dry "Cleanup dry-run" \
            cleanup-apply "Cleanup apply (safe caches)" \
            orphans "Orphaned compatdata" \
            log "Last log" \
            docs "verified-optimizations.md" \
            quit "Quit" \
            2>/dev/null
    fi
}

show_text_file() {
    local title=$1
    local file=$2
    if have zenity; then
        zenity --text-info --title="$title" --width=720 --height=520 \
            --filename="$file" 2>/dev/null || true
    else
        kdialog --title "$title" --textbox "$file" 720 520 2>/dev/null || true
    fi
}

run_and_show() {
    local label=$1
    shift
    local tmp rc=0
    tmp=$(mktemp)

    set +e
    {
        echo "========== $label =========="
        echo "Started: $(date)"
        echo "Command: $*"
        echo "----------------------------"
        "$@"
        rc=$?
        echo "----------------------------"
        echo "Finished: $(date) (exit $rc)"
    } >"$tmp" 2>&1
    set -e

    cp "$tmp" "$LOG_FILE"
    show_text_file "$TITLE - $label (exit $rc)" "$tmp"
    rm -f "$tmp"

    if [ "$rc" -ne 0 ]; then
        ui_error "Failed (exit $rc). Check Log."
    fi
}

open_docs() {
    local doc="$SCRIPT_DIR/docs/verified-optimizations.md"
    if [ ! -f "$doc" ]; then
        ui_error "Missing: $doc"
        return
    fi
    if have xdg-open; then
        xdg-open "$doc" 2>/dev/null || ui_info "Open this file:\n$doc"
    elif have open; then
        open "$doc" 2>/dev/null || true
    else
        ui_info "Open this file:\n$doc"
    fi
}

cd "$SCRIPT_DIR"

while true; do
    choice=$(ui_menu || true)
    [ -n "${choice:-}" ] || exit 0

    case "$choice" in
        diagnostic)
            run_and_show "diagnostic" ./diagnostic.sh
            ;;
        apply)
            if ui_confirm "Backup and patch Ryubing/Eden configs?\n\nBackups: ~/.config/emulation-backups-*"; then
                run_and_show "apply-configs" ./apply-configs.sh
            fi
            ;;
        storage)
            run_and_show "storage-diagnostic" ./storage-diagnostic.sh
            ;;
        cleanup-dry)
            run_and_show "cleanup (dry-run)" ./cleanup.sh
            ;;
        cleanup-apply)
            if ui_confirm "Delete Steam shader caches, incomplete downloads, and thumbnails?\n\nDoes not touch games, saves, or orphaned compatdata."; then
                run_and_show "cleanup --apply" ./cleanup.sh --apply
            fi
            ;;
        orphans)
            run_and_show "find-orphans" ./find-orphans.sh
            ;;
        log)
            if [ -f "$LOG_FILE" ]; then
                show_text_file "$TITLE - log" "$LOG_FILE"
            else
                ui_info "No log yet."
            fi
            ;;
        docs)
            open_docs
            ;;
        quit)
            exit 0
            ;;
        *)
            exit 0
            ;;
    esac
done
