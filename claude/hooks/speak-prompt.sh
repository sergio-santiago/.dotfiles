#!/usr/bin/env bash
################################################################################
# Claude Code — ask for a spoken summary (UserPromptSubmit hook)
#
# Description:
#   While this console is on, asks Claude to close each reply with a short
#   <speak>…</speak> line written to be *heard*, so there is something worth
#   listening to when you ask for it. Keeping the instruction in a hook rather
#   than in CLAUDE.md means it disappears the moment you run `speak off` — no
#   stray summaries in replies you are only going to read.
#
#   Also stops playback: sending a new message means you are done listening.
################################################################################

set -uo pipefail

LIB="$HOME/.claude/speak-lib.sh"
[[ -r "$LIB" ]] || exit 0
# shellcheck source=/dev/null
source "$LIB"

payload="$(cat)"
prompt="$(printf '%s' "$payload" | jq -r '.prompt // ""' 2>/dev/null)"

# A turn that asks for a reading must not cancel one, so this runs *before* the
# silencing below. The other order kills the playback the turn's own command just
# started, and the silence looks exactly like Claude Code tearing down the process
# tree — a wrong diagnosis that cost a whole queue. Do not reorder these.
#
# A leading `!` and any spaces after it are stripped so the bash-mode form is
# recognised too, and a subcommand is required so an ordinary sentence starting
# with "speak" is still treated as a prompt.
bare="${prompt#!}"
while [[ "$bare" == ' '* ]]; do bare="${bare# }"; done
case "$bare" in
  /speak | /speak\ * | speak | \
  speak\ on* | speak\ off* | speak\ summary* | speak\ full* | \
  speak\ stop* | speak\ test*) exit 0 ;;
esac

# Any other prompt means you are done listening, and that the previous turn is
# over: a bookkeeping mark still lying around belonged to a turn that never
# reached its Stop hook, and left alone it would swallow this reply. Both before
# the state check, so they still work on the prompt right after `speak off`.
speak_hush
speak_admin_clear

speak_is_on || exit 0

# Turns spent running the command itself never reach this point (see the case
# above): the reply is one line of confirmation, and a block would just repeat it
# back and offer to read it aloud. The Stop hook independently skips saving them.

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Esta consola puede leer tus respuestas en voz alta. Cierra cada respuesta con un bloque <speak>…</speak> de una o dos frases, escrito para ser oído: sin rutas, sin nombres de fichero, sin comandos, sin markdown y sin emojis. Resume qué has hecho y, si procede, qué falta o qué decisión necesitas. El bloque se añade a tu respuesta normal, no la sustituye."
  },
  "suppressOutput": true
}
JSON
