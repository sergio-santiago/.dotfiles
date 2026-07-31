#!/usr/bin/env python3
"""Turn a Claude Code reply into something worth listening to.

Reads the Stop hook payload as JSON on stdin and writes two files:

    <out>.txt       the whole reply, stripped of everything that sounds like
                    noise when read aloud
    <out>.summary   the <speak>…</speak> line, when the reply carries one

Usage:  speak-clean.py <output-prefix> <max-chars>

Exit codes:  0 wrote something · 3 nothing worth saving · 1-2 something broke.
The hook logs anything that is neither 0 nor 3, so a bad config cannot stop
replies being saved with nothing to show for it.

Lives in its own file rather than inside the hook: a heredoc in the middle of a
shell script cannot contain an apostrophe without breaking the script, and code
this fiddly is worth being able to run on its own.
"""

import json
import os
import re
import sys

# The spoken block is the *last* one that starts a line. Anchored, because prose
# discussing this feature quotes the tag; last, because the hook asks for it at
# the end of the reply. First-wins let a quoted example hijack the summary.
SPOKEN = re.compile(
    r"(?:\A|\n)[ \t]*<speak>(?![\s\S]*\n[ \t]*<speak>)([\s\S]*?)(?:</speak>|\Z)"
)

# Curly quotes become straight ones instead of being stripped as symbols, or
# every contraction turns into two words.
QUOTES = str.maketrans({"‘": "'", "’": "'", "“": '"', "”": '"'})

# Emoji, arrows, dingbats: nothing a voice can say.
SYMBOLS = re.compile(r"[\U0001F000-\U0001FAFF←-⯿️]")

CODE_SPAN_MAX = 30   # past this an inline span is a blob, not a word


def unfenced(text: str) -> str:
    """Drop paired code blocks — before anything else looks at the text.

    A <speak> example inside a fence must not be mistaken for the real block,
    which is why this runs first rather than inside readable().
    """
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    return re.sub(r"~~~.*?~~~", " ", text, flags=re.S)


def undangled(text: str) -> str:
    """A fence with no closing partner swallows the rest of the reply.

    An odd number of fences is ordinary — one inside a bullet, or a reply cut
    short — and the leftover opener would otherwise leave every following line to
    be read out as prose ("hash bang slash usr slash bin…"). Losing the tail is
    the lesser loss. Runs after the summary has been taken, so a spoken block
    sitting past the stray fence still survives.
    """
    return re.sub(r"(?:```|~~~)[\s\S]*", " ", text)


def spoken_code(match: "re.Match[str]") -> str:
    """Keep inline code that reads as a word; say paths the way a person would.

    Deleting paths outright leaves sentences dangling mid-clause ("I edited
    and then…"), so `claude/speak-lib.sh` becomes "speak lib". Every span goes
    through here, long ones included: testing the length in the pattern instead
    let a long span pair its closing backtick with the next span's opening one
    and swallow the sentence between them.
    """
    text = match.group(1).strip()
    if not text or len(text) > CODE_SPAN_MAX:
        return " "
    if not re.search(r"[/\\_~]|\.\w|--|\(\)", text):
        return text
    base = re.split(r"[/\\]", text.rstrip("/\\"))[-1]
    stem = re.sub(r"\.[A-Za-z][A-Za-z0-9]{0,4}$", "", base)   # a file extension
    words = re.sub(r"[-_]+", " ", (stem or base).lstrip(".-")).strip()
    return words if 0 < len(words) <= 20 else " "


def readable(text: str) -> str:
    """Strip markup and paths — whatever a voice cannot convey.

    Expects fenced code to be gone already (see unfenced).
    """
    out = SPOKEN.sub(" ", text)                                  # spoken block
    out = re.sub(r"^\s*\|.*\|\s*$", " ", out, flags=re.M)        # tables
    out = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", out)         # links, images
    out = re.sub(r"https?://\S+", "un enlace", out)
    out = re.sub(r"`([^`\n]*)`", spoken_code, out)               # inline code
    out = re.sub(r"^\s*#{1,6}\s*", "", out, flags=re.M)          # headings
    out = re.sub(r"^\s*[-*+•>]\s+", "", out, flags=re.M)         # bullets, quotes
    out = re.sub(r"[*_]{1,3}([^*_\n]+)[*_]{1,3}", r"\1", out)    # emphasis
    out = SYMBOLS.sub(" ", out.translate(QUOTES))
    out = re.sub(r"[ \t]+", " ", out)
    return re.sub(r"\s*\n\s*", " ", out).strip()


def trim(text: str, limit: int) -> str:
    """Cap the text at a sentence boundary when possible."""
    if len(text) <= limit:
        return text
    cut = text[:limit]
    stop = max(cut.rfind(". "), cut.rfind("? "), cut.rfind("! "))
    return cut[: stop + 1] if stop > limit // 3 else cut.rsplit(" ", 1)[0] + "…"


def clear(prefix: str) -> None:
    """Forget the last reply.

    A turn that produced no text must not leave the previous one on disk, or
    `speak summary` reads an older answer as if it were the latest.
    """
    for suffix in (".txt", ".summary"):
        try:
            os.remove(prefix + suffix)
        except OSError:
            pass


def main() -> int:
    if len(sys.argv) < 3:
        return 2
    prefix = sys.argv[1]
    try:
        limit = int(sys.argv[2])
    except ValueError:
        return 2

    try:
        data = json.loads(sys.stdin.read() or "{}")
    except ValueError:
        return 1

    # Subagents finish their own turns; only the main conversation is narrated,
    # and the main console's files are not theirs to clear — hence the early
    # return, before clear() below.
    #
    # Keyed on agent_id and NOT on agent_type: a session started with
    # `claude --agent <name>` carries agent_type on the *main* thread too, so
    # testing it silenced those sessions completely while the status line went on
    # promising a reading. agent_id is the field that means "this is a subagent".
    if data.get("agent_id"):
        return 3

    reply = (data.get("last_assistant_message") or "").strip()
    if not reply:
        clear(prefix)
        return 3

    body = unfenced(reply)
    match = SPOKEN.search(body)

    # The summary is cleaned and capped like the full text. It is the version
    # played most often, and an unclosed tag makes it swallow the entire reply —
    # half an hour of audio where a few seconds were meant.
    full = trim(readable(undangled(body)), limit)
    summary = trim(readable(match.group(1)), limit) if match else ""

    wrote = False
    for path, text in ((prefix + ".txt", full), (prefix + ".summary", summary)):
        if text:
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(text + "\n")
            wrote = True
        elif os.path.exists(path):
            os.remove(path)  # never leave a stale version behind

    return 0 if wrote else 3


if __name__ == "__main__":
    sys.exit(main())
