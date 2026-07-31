#!/usr/bin/env bash
################################################################################
# Claude Code — pretty-print the spoken block (MessageDisplay hook)
#
# Description:
#   Turns the raw <speak>…</speak> markers into a quiet one-liner prefixed with a
#   speaker icon, so the text you can have read aloud is recognisable instead of
#   looking like stray XML.
#
#   MessageDisplay is display-only: the transcript keeps the original text, which
#   is what the Stop hook reads. Text arrives in `delta` chunks, so each tag is
#   rewritten independently rather than as a pair — a block split mid-stream
#   still renders correctly. The opening tag only matches at the start of a line,
#   so prose mentioning the literal tag is left alone.
#
# Performance:
#   Fires while text streams, so the common path is one string test and exit.
################################################################################

set -uo pipefail

payload="$(cat)"

[[ "$payload" == *'speak>'* ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

LIB="$HOME/.claude/speak-lib.sh"
[[ -r "$LIB" ]] || exit 0
# shellcheck source=/dev/null
source "$LIB"

# A console that is off never gets asked for a block, so a marker here can only
# be prose that mentions the tag. Leave it exactly as written.
speak_is_on || exit 0

jq -c -n \
  --arg payload "$payload" \
  --arg pre "$SPEAK_PRE" \
  --arg post "$SPEAK_POST" \
  '($payload | fromjson) as $in
   | ($in.delta // "") as $t
   | if ($t | type) == "string" and ($t | test("(^|\n)<speak>|</speak>")) then
       { hookSpecificOutput: {
           hookEventName: "MessageDisplay",
           displayContent: ($t
             | gsub("(?<p>^|\n)<speak>[ \t]*"; .p + $pre)
             | gsub("[ \t]*</speak>"; $post))
         } }
     else
       empty
     end' 2>/dev/null

exit 0
