#!/usr/bin/env bash
################################################################################
# Claude Code: ask for a spoken summary (UserPromptSubmit hook)
#
# Description:
#   While this console is on, asks Claude to close each reply with a short
#   <speak>…</speak> line written to be *heard*, so there is something worth
#   listening to when you ask for it. Keeping the instruction in a hook rather
#   than in CLAUDE.md means it disappears the moment you run `speak off`. No
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
# silencing below. DO NOT REORDER: the other way round kills the playback that this
# very turn's command just started, and the symptom, silence with a half-written
# wav, looks like an external process killing Piper rather than us doing it.
#
# A leading `!` and any spaces after it are stripped so the bash-mode form is
# recognised too. The subcommands are matched whole and not as prefixes: none of
# them takes an argument, and a prefix glob would swallow an ordinary sentence that
# merely opens with the word. "speak only in English please" is a prompt, and
# treating it as a command left the turn with no instruction and nothing silenced.
bare="${prompt#!}"
while [[ "$bare" == ' '* ]]; do bare="${bare# }"; done
case "$bare" in
  /speak | /speak\ * | speak | \
  speak\ on | speak\ off | speak\ summary | speak\ full | \
  speak\ stop | speak\ test | speak\ help) exit 0 ;;
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

# The instruction names where the block belongs because Claude Code generates other
# text from the same context, the end-of-turn recap most visibly, and that text
# reaches the screen without passing through MessageDisplay, which fires only on
# assistant message deltas. A block written there cannot be rendered as an icon and
# shows as raw tags. Harmless otherwise: the reading comes from the Stop hook's
# last_assistant_message, so a stray block is never saved and never read.
cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Esta consola puede leer tus respuestas en voz alta. Cierra cada respuesta con un bloque <speak>…</speak> de una o dos frases, escrito para ser oído: sin rutas, sin nombres de fichero, sin comandos, sin markdown y sin emojis. Resume qué has hecho y, si procede, qué falta o qué decisión necesitas. El bloque se añade a tu respuesta normal, no la sustituye. Va únicamente al final de tu respuesta al usuario: no lo pongas nunca en un recap, un resumen de sesión, un título ni en ningún otro texto que se genere aparte de la respuesta."
  },
  "suppressOutput": true
}
JSON
