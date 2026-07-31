#!/usr/bin/env bash
################################################################################
# Claude Code — prepare the reply for listening (Stop hook)
#
# Description:
#   Nothing is ever read automatically. When this console is on, the reply is
#   cleaned and saved so it is ready to be read — you decide, with the answer
#   already in front of you, whether it is worth hearing.
#
#   Saved files are overwritten each turn, so nothing accumulates.
#
# Exit code is always 0: a broken speaker must never block a turn.
################################################################################

set -uo pipefail

LIB="$HOME/.claude/speak-lib.sh"
[[ -r "$LIB" ]] || exit 0
# shellcheck source=/dev/null
source "$LIB"

payload="$(cat)"

# Cleared even when off, so no mark is left behind.
speak_admin_take && exit 0

speak_is_on || exit 0

# Keeps the marker young, so the weekly prune measures how long a console has sat
# idle rather than how long ago it was switched on.
speak_touch

mkdir -p "$SPEAK_LAST_DIR"
prefix="$SPEAK_LAST_DIR/$(speak_console_id)"

err="$(printf '%s' "$payload" |
    python3 "$SPEAK_CLEAN" "$prefix" "$(speak_max_chars)" 2>&1 >/dev/null)"
status=$?

# 0 saved it, 3 means there was nothing worth saving. Anything else is a real
# failure — a bad max_chars, a missing interpreter — and must not pass unnoticed
# while the status line goes on promising a reading.
case "$status" in
    0 | 3) ;;
    *) speak_log "speak-clean.py exit $status: ${err:-no output}" ;;
esac

# Nothing is printed from here: the commands appear under the <speak> block
# itself (see SPEAK_POST in speak-lib.sh), which avoids the TUI's "Stop says:"
# prefix and a second speaker icon.
exit 0
