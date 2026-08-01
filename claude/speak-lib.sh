#!/usr/bin/env bash
################################################################################
# Spoken Claude Code replies: shared helpers
#
# Description:
#   Sourced by everything that needs to agree on what a console does: the hooks,
#   the status line indicator and the `speak` command. One place to resolve state
#   means the indicator can never disagree with what actually happens.
#
# State model, two states per console:
#   on    every reply is cleaned and kept ready to be read
#   off   nothing is prepared
#
#   Nothing is ever read automatically: `speak summary` and `speak full` do the
#   reading, whenever you ask for it. Per console because several Claude Code
#   sessions run in parallel, and audio from one ruins dictation into another.
#
# Files:
#   ~/.claude/speak.conf              voice, speed, length (hand-edited, optional)
#   ~/.claude/speak-consoles/<id>     marker, exists ⇒ that console is on
#   ~/.claude/speak-last/<id>.txt     last reply, cleaned for reading aloud
#   ~/.claude/speak-last/<id>.summary its <speak> line, when there was one
#   ~/.claude/speak-last/<id>.admin   this turn was bookkeeping, do not save it
#   ~/.claude/speak.log               readings launched and anything that failed,
#                                     trimmed back to 200 lines once past 500
#
#   The last-reply files are overwritten every turn, so a console holds at most
#   one of each and they never accumulate. The mark is written and taken inside a
#   single turn, and the prompt hook drops any leftover, so it can never change
#   what a later turn does. Files belonging to consoles you stopped using are
#   pruned after a week.
################################################################################

SPEAK_CONF="$HOME/.claude/speak.conf"
SPEAK_CONSOLES_DIR="$HOME/.claude/speak-consoles"
SPEAK_LAST_DIR="$HOME/.claude/speak-last"
SPEAK_LOG="$HOME/.claude/speak.log"

SPEAK_PIPER_HOME="$HOME/.local/share/piper"
SPEAK_PIPER_PY="$SPEAK_PIPER_HOME/venv/bin/python"
SPEAK_VOICES_DIR="$SPEAK_PIPER_HOME/voices"
SPEAK_CLEAN="$HOME/.claude/speak-clean.py"

SPEAK_DEFAULT_VOICE="es_ES-davefx-medium"
SPEAK_DEFAULT_SPEED="1.0"

# Cap on what gets read in one go: ten minutes of audio. Measured, not guessed:
# es_ES-davefx-medium at speed 1.0 reads 1000 characters in 51.5 s (19.4 chars/s),
# so re-measure if the default voice or speed changes.
SPEAK_DEFAULT_MAX_CHARS="11600"

# On-screen dress for the <speak> block: grey icon, grey italic text, and the
# commands at the end of an arrow that descends from the icon's own column, so they
# read as belonging to the block rather than to the reply above it. Rounded corner
# because that is the one the status line draws. The head is a filled triangle and
# the arrow runs into the text with no gap: a plain ─ before a space reads as a hole
# at terminal font sizes, since the rule is thin and sits at mid-height. Monochrome
# on purpose, green belongs to the status line, where it carries state.
#
# The hint rides inside the block instead of coming from a hook systemMessage,
# which the TUI prefixes with an unavoidable "Stop says:" and which would put a
# second speaker icon on screen. One icon, one visual unit, no prefix.
#
# Two closing forms, because the text streams in chunks and the newline the model
# writes before </speak> usually arrives in an earlier chunk than the tag, already
# on screen, impossible to take back. TIGHT is for that case, which the hook
# recognises by the tag starting its chunk. POST breaks the line itself, for a block
# that arrives whole. Measured from real deltas, not assumed.
SPEAK_PRE=$'\033[38;2;170;170;170m󰕾\033[0m \033[38;2;108;108;108m\033[3m'
SPEAK_HINT=$'\033[38;2;108;108;108m╰──▸/speak summary · /speak full\033[0m'
SPEAK_POST=$'\033[0m\n'"$SPEAK_HINT"
SPEAK_POST_TIGHT=$'\033[0m'"$SPEAK_HINT"

# ── Private storage ─────────────────────────────────────────────────────────
#
# The saved replies are content, not bookkeeping, so the directories holding them are
# kept to the owner. On macOS $HOME is drwxr-x--- with group staff, and every local
# account belongs to staff, so a 0755 directory of 0644 files here is readable by any
# other account on the machine. `mkdir -m` only applies at creation, so the mode is
# re-applied on every call, the same reason install.sh re-chmods ~/.ssh: a mode set
# once is a mode nothing restores after something else widens it.
#
# Failures are swallowed and 0 returned throughout. This runs inside hooks, and a
# permission problem must not take a turn down with it.
speak_private_dir() {
    mkdir -p -m 700 "$1" 2>/dev/null
    chmod 700 "$1" 2>/dev/null
    return 0
}

# ── State ───────────────────────────────────────────────────────────────────

# Identifies the terminal tab/pane, not the Claude Code session: restarting
# claude in the same tab keeps that tab's setting. iTerm2 gives every pane a
# stable UUID in ITERM_SESSION_ID ("w0t2p0:UUID"), inherited by hooks and the
# status line alike. Other terminals fall back to the controlling tty.
speak_console_id() {
    local raw="${ITERM_SESSION_ID:-${TERM_SESSION_ID:-}}"
    local id="${raw#*:}"
    [[ -n "$id" ]] || id="$(ps -o tty= -p "${PPID:-$$}" 2>/dev/null | tr -d ' \n')"
    id="${id//[^A-Za-z0-9_-]/_}"   # this becomes a filename
    printf '%s' "${id:-shared}"
}

speak_is_on() {
    [[ -e "$SPEAK_CONSOLES_DIR/$(speak_console_id)" ]]
}

speak_turn_on() {
    speak_private_dir "$SPEAK_CONSOLES_DIR"
    : >"$SPEAK_CONSOLES_DIR/$(speak_console_id)"
    speak_prune
}

# Leaves nothing behind that a later turn could act on: no saved reply to read,
# no bookkeeping mark to consume.
speak_turn_off() {
    local id
    id="$(speak_console_id)"
    rm -f "$SPEAK_CONSOLES_DIR/$id" \
        "$SPEAK_LAST_DIR/$id.txt" "$SPEAK_LAST_DIR/$id.summary" \
        "$SPEAK_LAST_DIR/$id.admin"
}

# Keeps the marker young while the console is in use, so speak_prune measures how
# long a console has sat idle rather than how long ago it was switched on.
speak_touch() {
    local marker="$SPEAK_CONSOLES_DIR/$(speak_console_id)"
    [[ -e "$marker" ]] && touch "$marker" 2>/dev/null
    return 0
}

# Markers and saved replies outlive the consoles that made them, since closing a tab
# leaves its files behind, so drop anything untouched for a week.
speak_prune() {
    for dir in "$SPEAK_CONSOLES_DIR" "$SPEAK_LAST_DIR"; do
        [[ -d "$dir" ]] && find "$dir" -type f -mtime +7 -delete 2>/dev/null
    done
    return 0
}

# ── Config ──────────────────────────────────────────────────────────────────

# Read a key without sourcing the file: a hand-edited or corrupt config must not
# be able to run code or break a hook. Trailing `# comments` are stripped, since a
# file meant to be hand-edited invites them.
speak_conf_get() {
    [[ -r "$SPEAK_CONF" ]] || return 0
    sed -n "s/^$1=//p" "$SPEAK_CONF" | tail -1 |
        sed -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

speak_voice() {
    local v
    v="$(speak_conf_get voice)"
    printf '%s' "${v:-$SPEAK_DEFAULT_VOICE}"
}

# Speed and length are validated rather than passed through: one reaches piper as
# --length-scale and the other python as an int, and a typo in either would fail
# deep inside a hook whose output nobody sees. A bad voice needs no fallback: it
# is named in the log, which is more useful than silently reading in another one.
speak_speed() {
    local s
    s="$(speak_conf_get speed)"
    [[ "$s" =~ ^[0-9]+([.][0-9]+)?$ ]] || s="$SPEAK_DEFAULT_SPEED"
    printf '%s' "$s"
}

speak_max_chars() {
    local c
    c="$(speak_conf_get max_chars)"
    [[ "$c" =~ ^[1-9][0-9]*$ ]] || c="$SPEAK_DEFAULT_MAX_CHARS"
    printf '%s' "$c"
}

speak_last_path() {
    printf '%s/%s%s' "$SPEAK_LAST_DIR" "$(speak_console_id)" "${1:-.txt}"
}

# ── Admin turns ─────────────────────────────────────────────────────────────
#
# A turn spent running `speak` itself is bookkeeping, not content: its reply is
# one line ("this console is on") and saving it would overwrite the reply you
# actually wanted to hear. The command leaves this mark, and the Stop hook takes it
# and skips the turn.
#
# A mark whose turn never reached its Stop hook, an interrupted one, would eat
# the *next* reply instead, so the prompt hook drops any leftover before the turn
# it belongs to can be mistaken for bookkeeping.

speak_admin_path() {
    printf '%s/%s.admin' "$SPEAK_LAST_DIR" "$(speak_console_id)"
}

speak_admin_mark() {
    speak_private_dir "$SPEAK_LAST_DIR"
    : >"$(speak_admin_path)"
}

speak_admin_clear() {
    rm -f "$(speak_admin_path)"
    return 0
}

speak_admin_take() {
    local mark
    mark="$(speak_admin_path)"
    [[ -e "$mark" ]] || return 1
    rm -f "$mark"
}

speak_log() {
    # Restricted at creation only, so the common path stays a single append. The log
    # quotes what was read aloud, so it is content too.
    if [[ ! -e "$SPEAK_LOG" ]]; then
        : >"$SPEAK_LOG" 2>/dev/null && chmod 600 "$SPEAK_LOG" 2>/dev/null
    fi
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$SPEAK_LOG" 2>/dev/null
    # Keep the log bounded.
    if [[ -f "$SPEAK_LOG" ]] && (($(wc -l <"$SPEAK_LOG") > 500)); then
        tail -n 200 "$SPEAK_LOG" >"$SPEAK_LOG.tmp" 2>/dev/null && mv "$SPEAK_LOG.tmp" "$SPEAK_LOG"
    fi
}

# ── Speaking ────────────────────────────────────────────────────────────────

# Silence the reading in *this* console and nothing else. Several sessions run in
# parallel and this fires on every prompt submit, so typing here must never cut
# off what another pane is saying.
speak_hush() {
    local id tmpdir
    id="$(speak_console_id)"
    tmpdir="${TMPDIR:-/tmp}"
    pkill -f "claude-speak-$id-[0-9]" 2>/dev/null
    # The wrapper removes its own pair on the way out, but a reading killed before
    # piper ever started leaves the copy behind.
    rm -f "$tmpdir/claude-speak-$id-"* 2>/dev/null
    return 0
}

# Synthesise and play a text file, detached: nothing waits on audio.
#
# The handle is the temp file name, and it carries the console id so one pane can
# never silence another. Not a pid: the one worth having is piper's, while the
# shell only hands back the subshell that launched it.
#
#     ${TMPDIR:-/tmp}/claude-speak-<console-id>-<pid>.{txt,wav}
speak_say_file() {
    local src="$1" voice speed onnx tmp
    [[ -s "$src" ]] || return 1

    voice="$(speak_voice)"
    speed="$(speak_speed)"
    onnx="$SPEAK_VOICES_DIR/$voice.onnx"

    if [[ ! -x "$SPEAK_PIPER_PY" ]]; then
        speak_log "piper missing. Run 'make speak-setup'"
        return 1
    fi
    # A voice is two files. Piper aborts without the sidecar JSON, and the
    # downloader writes the 63 MB model straight to its final path and fetches the
    # JSON afterwards, so an interrupted setup leaves a model that never speaks.
    if [[ ! -r "$onnx" ]]; then
        speak_log "voice missing: $onnx. Check voice= in ~/.claude/speak.conf"
        return 1
    fi
    if [[ ! -r "$onnx.json" ]]; then
        speak_log "voice incomplete: $onnx.json is missing. Re-run 'make speak-setup'"
        return 1
    fi

    # There is one pair of speakers, so starting a reading stops every other one,
    # whichever console owns it. Deliberately wider than speak_hush, which stays
    # inside its own console because it runs on every prompt submit.
    pkill -f 'claude-speak-' 2>/dev/null

    tmp="${TMPDIR:-/tmp}/claude-speak-$(speak_console_id)-$$"
    # Under a umask in a subshell: TMPDIR is a per-user 0700 directory on macOS, but
    # the /tmp fallback is world-readable, and this file holds the text being spoken.
    (umask 077; cp "$src" "$tmp.txt" 2>/dev/null) || return 1

    # The pair is removed by the last line inside the subshell rather than by an
    # EXIT trap: macOS ships bash 3.2, which replaces the final command of a
    # background subshell with an exec and takes the EXIT trap with it. The trap
    # covers the signal cases only, and having a command after it is also what
    # stops that optimisation.
    {
        trap 'rm -f "$tmp".*; exit' INT TERM
        if nohup "$SPEAK_PIPER_PY" -m piper -m "$onnx" --length-scale "$speed" \
            -i "$tmp.txt" -f "$tmp.wav" >/dev/null 2>"$tmp.err"; then
            nohup afplay "$tmp.wav" >/dev/null 2>&1
        elif (($? <= 128)); then
            # Above 128 means a signal, i.e. someone asked us to stop, and that is not
            # a failure and must not fill the log on every prompt submit.
            speak_log "piper failed: $(tr '\n' ' ' <"$tmp.err" 2>/dev/null | tail -c 200)"
        fi
        rm -f "$tmp".*
    } >/dev/null 2>&1 &

    # "launching", not "speaking": this returns the moment the job is detached, so
    # it cannot know whether anything was heard. Whatever happens afterwards logs
    # itself from inside the subshell above.
    speak_log "launching $(wc -c <"$src" | tr -d ' ') chars · $voice · $(speak_console_id)"
    return 0
}
