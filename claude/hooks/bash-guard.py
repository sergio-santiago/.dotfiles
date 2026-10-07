#!/usr/bin/env python3
################################################################################
# Claude Code: decide the Bash commands a prefix rule cannot (PreToolUse hook)
#
# Description:
#   A permission rule matches a prefix, so it cannot tell `gh api` reading from
#   `gh api -X DELETE`, `git reset --soft` from `git reset HEAD~1 --hard`, or a
#   scratch file from a source file. This hook reads the whole command instead.
#
#     ask    some part of it can lose or publish something:
#              gh api     a method other than GET, a body flag (-f, -F, --field,
#                         --raw-field, --input) without an explicit GET, since
#                         a body turns gh's default method into POST, or a
#                         GraphQL `mutation`
#              git reset  --hard, --merge or --keep, the modes that touch the
#                         working tree
#              rm         any target outside /tmp, /private/tmp or $TMPDIR. A
#                         $VAR in a target is expanded only when the same
#                         command assigned it a literal unconditionally (see
#                         known_vars), otherwise it asks
#     allow  every part is a safe form of the above, a filter from
#            SAFE_FILTERS or a `cd`, with no substitution and no redirect
#            other than to /dev/null or between stdout and stderr.
#     -      anything else. The normal rules and mode decide.
#
#   Anything it cannot read for certain asks or stays out, it never allows.
################################################################################

import json
import os
import re
import shlex
import sys

SAFE_FILTERS = {"jq", "head", "tail", "grep", "rg", "wc", "sort", "uniq", "cut",
                "tr", "base64", "column", "cat", "echo", "printf", "true"}
SEPARATORS = {"|", "||", "&&", ";", "&", "(", ")", "\n"}
REDIRECTS = {">", ">>", ">&", "<", "&>"}
BODY_FLAGS = ("-f", "-F", "--field", "--raw-field", "--input")
RESET_DESTRUCTIVE = ("--hard", "--merge", "--keep")
TMPDIR = os.environ.get("TMPDIR", "").rstrip("/")
SCRATCH_ROOTS = {r for r in ("/tmp", "/private/tmp", TMPDIR, os.path.realpath(TMPDIR or "/tmp"))
                 if r and r != "/"}


def answer(decision, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }}))
    sys.exit(0)


def tokens(lexer):
    """shlex glues adjacent punctuation, so `);` arrives as one token that is
    neither a separator nor a redirect, and the command after it went unread.
    Unknown runs of punctuation are split into single characters."""
    for token in lexer:
        if token and set(token) <= set("();<>|&") \
                and token not in SEPARATORS and token not in REDIRECTS:
            yield from token
        else:
            yield token


def split_with_separators(command):
    """Each segment with the separator before and after it (None at either end)."""
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace = " \t\r"  # keep newlines: they separate commands
    lexer.commenters = ""
    lexer.wordchars += "$`=,.:/@%+~*?[]{}^!-"
    out, current, before = [], [], None
    for token in tokens(lexer):
        if token in SEPARATORS:
            if current:
                out.append((current, before, token))
            current, before = [], token
        else:
            current.append(token)
    if current:
        out.append((current, before, None))
    return out


HEREDOC = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_]\w*)\1")


def strip_heredocs(command):
    """The command without heredoc bodies, which are data and not commands.

    Only for reading the command's structure. Whether it substitutes anything is
    still decided on the original text, since an unquoted heredoc runs its $( ).
    """
    out, delimiter, strip_tabs = [], None, False
    for line in command.split("\n"):
        if delimiter is not None:
            if (line.lstrip("\t") if strip_tabs else line) == delimiter:
                delimiter = None
            continue
        m = HEREDOC.search(line)
        if m:
            delimiter, strip_tabs = m.group(2), line[m.start():].startswith("<<-")
            line = line[:m.start()] + line[m.end():]
        out.append(line)
    return "\n".join(out)


def split(command):
    return [seg for seg, _, _ in split_with_separators(command)]


ASSIGNMENT = re.compile(r"([A-Za-z_]\w*)=(.*)", re.S)
# Words that can change a variable behind an assignment's back, or run code that
# could. Any of them anywhere and no assignment is trusted at all.
REBINDERS = {"read", "for", "export", "declare", "typeset", "local", "unset",
             "eval", "source", ".", "while", "until", "readonly", "mapfile"}


def known_vars(parts, command):
    """Variables whose value at each segment is certain, as one dict per segment.

    Only an assignment of a literal that runs unconditionally counts: at the start
    or after `;` or a newline, and followed by `;`, a newline, `&&` or the end.
    `false && S=/tmp/x; rm -rf $S/*` would otherwise expand to `rm -rf /*`, and an
    assignment inside ( ), { }, a pipe or `&` lives in a subshell. A variable
    assigned any other way is forgotten, never guessed.
    """
    trusted = not re.search(r"[()]", command) and \
        not any(t in REBINDERS for seg, _, _ in parts for t in seg)
    env, snapshots = {}, []
    for seg, before, after_sep in parts:
        snapshots.append(dict(env))
        matches = [ASSIGNMENT.fullmatch(t) for t in seg]
        if not all(matches):
            continue
        certain = trusted and before in (None, ";", "\n") \
            and after_sep in (None, ";", "\n", "&&")
        for m in matches:
            name, value = m.group(1), m.group(2)
            if certain and not re.search(r"[$`]", value):
                env[name] = value
            else:
                env.pop(name, None)
    return snapshots


def expand(path, env):
    def sub(m):
        return env.get(m.group(1) or m.group(2), m.group(0))
    return re.sub(r"\$\{([A-Za-z_]\w*)\}|\$([A-Za-z_]\w*)", sub, path)


def words(seg):
    """The command words: no redirects or their targets, no leading VAR=x."""
    out, skip = [], False
    for t in seg:
        if skip:
            skip = False
        elif t in REDIRECTS:
            skip = True
            if out and out[-1] in ("1", "2"):
                out.pop()
        else:
            out.append(t)
    while out and re.fullmatch(r"[A-Za-z_]\w*=.*", out[0]):
        out.pop(0)
    return out


def after(seg, first, second):
    """The arguments after every `first second` pair in seg, wherever it sits."""
    return [seg[i + 2:] for i in range(len(seg) - 1) if seg[i] == first and seg[i + 1] == second]


def gh_api_writes(args):
    if args and args[0] == "graphql":
        return any(re.search(r"\bmutation\b", a, re.I) for a in args)
    method, body = None, False
    for i, arg in enumerate(args):
        if arg in ("-X", "--method") and i + 1 < len(args):
            method = args[i + 1]
        elif arg.startswith("--method="):
            method = arg.split("=", 1)[1]
        elif arg.startswith("-X") and len(arg) > 2:
            method = arg[2:]
        elif arg in BODY_FLAGS or re.match(r"-[fF].|--(field|raw-field|input)=", arg):
            body = True
    if method is not None:
        return method.upper() != "GET"
    return body


def in_scratch(path, cwd):
    if "$" in path or "~" in path:
        return False
    full = os.path.normpath(os.path.join(cwd, path))
    for root in SCRATCH_ROOTS:
        if full.startswith(root + "/"):
            # one level below the root at least, and that level not a glob,
            # so `rm -rf /tmp/*` still asks
            return not re.search(r"[*?\[]", full[len(root) + 1:].split("/")[0])
    return False


def rm_targets(args):
    targets, options = [], True
    for a in args:
        if options and a == "--":
            options = False
        elif not (options and a.startswith("-")):
            targets.append(a)
    return targets


def main():
    data = json.load(sys.stdin)
    command = data.get("tool_input", {}).get("command", "")
    if not re.search(r"\b(gh\s+api|reset|rm)\b", command):
        return
    try:
        structure = strip_heredocs(command)
        parts = split_with_separators(structure)
        segments = [seg for seg, _, _ in parts]
    except ValueError:
        answer("ask", "a command that could not be parsed")

    # ask: anywhere in the command, substitutions included
    for seg in segments:
        if any(gh_api_writes(a) for a in after(seg, "gh", "api")):
            answer("ask", "gh api call that can write")
        if any(a in RESET_DESTRUCTIVE for args in after(seg, "git", "reset") for a in args):
            answer("ask", "git reset that discards working tree changes")

    # allow: only when every part is known to be safe
    substituted = bool(re.search(r"\$\(|`|<\(", command))
    safe, cwd = not substituted, data.get("cwd") or os.getcwd()
    for seg, env in zip(segments, known_vars(parts, structure)):
        for i, t in enumerate(seg):
            target = seg[i + 1] if i + 1 < len(seg) else ""
            if (t in (">", ">>", "&>") and target != "/dev/null") or t == "<" \
                    or (t == ">&" and target not in ("1", "2")):
                safe = False
        w = words(seg)
        if not w:
            continue
        if w[0] == "rm":
            targets = rm_targets(w[1:])
            if substituted or not targets or \
                    not all(in_scratch(expand(t, env), cwd) for t in targets):
                answer("ask", "rm outside the temporary directories")
        elif w[0] == "cd" and len(w) == 2 and "$" not in w[1]:
            cwd = os.path.normpath(os.path.join(cwd, os.path.expanduser(w[1])))
        elif w[:2] in (["gh", "api"], ["git", "reset"]):
            pass
        elif w[0] not in SAFE_FILTERS or (w[0] == "sort" and "-o" in w):
            safe = False
    if safe:
        answer("allow", "only safe forms of gh api, git reset and rm")


if __name__ == "__main__":
    main()
