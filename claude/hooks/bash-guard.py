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
#                         working tree, past any global option such as -C
#              rm         any target outside /tmp, /private/tmp or $TMPDIR
#                         that git cannot restore: committed and unchanged,
#                         with nothing untracked or ignored under it, and not
#                         the repo root or .git (see restorable). A $VAR in a
#                         target is expanded only when its value is certain
#                         (see known_vars), a relative target only from every
#                         directory the command can be in (see main), otherwise
#                         it asks. Behind a wrapper (sudo, env, command,
#                         xargs...) or in a quoted $( ) it always asks.
#                         An rm git can restore is left to the normal rules
#     allow  every part is a safe form of the above, a filter from
#            SAFE_FILTERS or a `cd`, with no substitution and no redirect
#            other than to /dev/null or between stdout and stderr.
#     -      anything else. The normal rules and mode decide.
#
#   Anything it cannot read for certain asks or stays out, it never allows.
#   A crash asks too, since an empty answer would let the command through.
################################################################################

import glob
import json
import os
import re
import shlex
import subprocess
import sys

SAFE_FILTERS = {"jq", "head", "tail", "grep", "rg", "wc", "sort", "uniq", "cut",
                "tr", "base64", "column", "cat", "echo", "printf", "true"}
SEPARATORS = {"|", "||", "&&", ";", "&", "(", ")", "\n"}
REDIRECTS = {">", ">>", ">&", "<", "&>"}
BODY_FLAGS = ("-f", "-F", "--field", "--raw-field", "--input")
RESET_DESTRUCTIVE = ("--hard", "--merge", "--keep")
# Commands that run the command after them. An rm behind one asks whatever its
# targets, since xargs takes them from stdin and the rest change who runs it.
WRAPPERS = {"command", "builtin", "exec", "env", "sudo", "doas", "nohup", "nice",
            "time", "timeout", "caffeinate", "xargs"}
# git's global options that take the next word as their value
GIT_VALUE_OPTIONS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace",
                     "--exec-path", "--config-env"}
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
    """Each segment with the separator before and after it (None at either end)
    and its depth inside ( ), plus whether the parentheses balance. A `case`
    pattern's lone `)` unbalances them, and then no variable or cd is trusted."""
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace = " \t\r"  # keep newlines: they separate commands
    lexer.commenters = ""
    lexer.wordchars += "$`=,.:/@%+~*?[]{}^!-"
    out, current, before, depth, balanced = [], [], None, 0, True
    for token in tokens(lexer):
        if token in SEPARATORS:
            if current:
                out.append((current, before, token, depth))
            current, before = [], token
            depth += {"(": 1, ")": -1}.get(token, 0)
            balanced = balanced and depth >= 0
        else:
            current.append(token)
    if current:
        out.append((current, before, None, depth))
    return out, balanced and depth == 0


HEREDOC = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_]\w*)\1")
SUBSTITUTION = re.compile(r"\$\(|`|<\(")


def strip_heredocs(command):
    """The command without heredoc bodies, which are data and not commands, and
    whether an unquoted body substitutes anything, since that one runs its $( )."""
    out, delimiter, strip_tabs, quoted, runs = [], None, False, False, False
    for line in command.split("\n"):
        if delimiter is not None:
            if (line.lstrip("\t") if strip_tabs else line) == delimiter:
                delimiter = None
            elif not quoted and SUBSTITUTION.search(re.sub(r"\\.", "", line)):
                runs = True
            continue
        m = HEREDOC.search(line)
        if m:
            delimiter, strip_tabs = m.group(2), line[m.start():].startswith("<<-")
            quoted = bool(m.group(1))
            line = line[:m.start()] + line[m.end():]
        out.append(line)
    return "\n".join(out), runs


ASSIGNMENT = re.compile(r"([A-Za-z_]\w*)=(.*)", re.S)
# Any word that binds a name: `S=`, `S+=`, `S[0]=`. Counted wherever it sits.
BINDS = re.compile(r"([A-Za-z_]\w*)(\[[^\]]*\])?\+?=")
# Words whose arguments name variables they set. Each name after one counts as
# another binding of it, which is enough to stop trusting that name.
REBINDERS = {"read", "for", "select", "export", "declare", "typeset", "local",
             "unset", "readonly", "mapfile", "readarray", "getopts", "printf"}
# Words that can change any variable at all. One of them and none is trusted.
ANY_REBINDER = {"eval", "source", ".", "let"}
# Words a command can sit behind without being an argument of them.
KEYWORDS = {"do", "then", "else", "elif", "if", "while", "until", "{", "!"}


def fixed_loop(seg):
    """`for NAME in word...` over words that expand to nothing else."""
    return len(seg) > 3 and seg[0] == "for" and seg[2] == "in" \
        and re.fullmatch(r"[A-Za-z_]\w*", seg[1]) \
        and not any(re.search(r"[$`*?\[{~]", v) for v in seg[3:])


def rebinds_any(w):
    """eval, source, `.` or let as the command, plain or behind a wrapper. As an
    argument (`ruff check .`) they are only words."""
    return bool(w) and (w[0] in ANY_REBINDER or
                        (w[0] in WRAPPERS and any(a in ANY_REBINDER for a in w[1:])))


def bindings(parts):
    """How many times each name is bound anywhere in the command. A loop over
    fixed words is left out: its name is known only inside its own body, and
    forgotten after it, so it cannot change a value seen anywhere else."""
    counts = {}
    for seg, _, _, _ in parts:
        if fixed_loop(seg):
            continue
        for i, t in enumerate(seg):
            m = BINDS.match(t)
            if m:
                counts[m[1]] = counts.get(m[1], 0) + 1
            if t in REBINDERS:
                for a in seg[i + 1:]:
                    n = re.match(r"[A-Za-z_]\w*", a)
                    if n and not BINDS.match(a):
                        counts[n[0]] = counts.get(n[0], 0) + 1
    return counts


def known_vars(parts, balanced, command):
    """Variables whose value at each segment is certain, as one dict per segment.

    A name counts only if the command binds it exactly once, so a loop, a `read`,
    an `export` or a `+=` elsewhere cannot change it behind the check's back, and
    a loop body cannot see a later iteration's value, since a segment before the
    assignment never has it.

    That one binding has to be a literal, or built only from names already
    known, at the top level (not in a ( ) subshell), running unconditionally: at
    the start or after `;` or a newline, and followed by `;`, a newline, `&&` or
    the end. `false && S=/tmp/x; rm -rf $S/*` would otherwise expand to
    `rm -rf /*`. One after `&&` counts too, but only while every separator after
    it is another `&&`: in `cd x && S=/tmp/y && rm $S/*` the rm runs only if the
    assignment did. A variable assigned any other way is forgotten, never guessed.
    """
    trusted = balanced and "((" not in command and \
        not any(rebinds_any(words(seg)) for seg, _, _, _ in parts)
    bound = bindings(parts)
    once = {n for n, c in bound.items() if c == 1}
    env, chained, snapshots, loops, pending = {}, set(), [], [], None
    for seg, before, after_sep, depth in parts:
        if before != "&&":
            for name in chained:
                env.pop(name, None)
            chained = set()
        # `for p in a b; do ...; done` over fixed words: inside its body p is
        # each of them, after it p is forgotten
        if seg[0] == "do":
            name = pending[0] if pending and pending[2] == depth and trusted \
                and bound.get(pending[0], 0) == 0 else None
            if name:
                env[name] = tuple(pending[1])
            loops.append(name)
            pending = None
        elif seg[0] == "done" and loops:
            name = loops.pop()
            if name:
                env.pop(name, None)
        snapshots.append(dict(env))
        if fixed_loop(seg):
            env.pop(seg[1], None)  # the loop rebinds it, whatever it held
            chained.discard(seg[1])
            pending = (seg[1], seg[3:], depth)
        matches = [ASSIGNMENT.fullmatch(t) for t in seg]
        if not all(matches):
            continue
        ok = trusted and depth == 0
        certain = ok and before in (None, ";", "\n") \
            and after_sep in (None, ";", "\n", "&&")
        in_chain = ok and before == "&&" and after_sep in (None, "&&")
        for m in matches:
            values = expand(m[2], env)
            name, value = m[1], values[0] if len(values) == 1 else "$"
            if (certain or in_chain) and name in once and not re.search(r"[$`]", value):
                env[name] = value
                if in_chain:
                    chained.add(name)
                else:
                    chained.discard(name)
            else:
                env.pop(name, None)
                chained.discard(name)
    return snapshots


VARIABLE = re.compile(r"\$\{([A-Za-z_]\w*)(?::?\?[^}]*)?\}|\$([A-Za-z_]\w*)")


def expand(path, env):
    """Every value path can take. A known name is a string, or a tuple for a
    loop variable over fixed words. `${S:?}` reads as `$S`, since it only adds
    a failure when S is unset. Unknown names stay as they are."""
    m = VARIABLE.search(path)
    if not m:
        return [path]
    value = env.get(m[1] or m[2])
    if value is None:
        return [path[:m.end()] + rest for rest in expand(path[m.end():], env)]
    values = value if isinstance(value, tuple) else (value,)
    return [path[:m.start()] + v + rest for v in values
            for rest in expand(path[m.end():], env)]


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
    while out and (out[0] in KEYWORDS or re.fullmatch(r"[A-Za-z_]\w*=.*", out[0])):
        out.pop(0)
    return out


def after(seg, first, second):
    """The arguments after every `first second` pair in seg, wherever it sits."""
    return [seg[i + 2:] for i in range(len(seg) - 1) if seg[i] == first and seg[i + 1] == second]


def git_reset_args(seg):
    """The arguments of every git reset in seg, past git's global options, so
    `git -C dir reset --hard` is read as a reset like the plain spelling."""
    out = []
    for i, t in enumerate(seg):
        if os.path.basename(t) != "git":
            continue
        j = i + 1
        while j < len(seg) and seg[j].startswith("-"):
            j += 2 if seg[j] in GIT_VALUE_OPTIONS else 1
        if j < len(seg) and seg[j] == "reset":
            out.append(seg[j + 1:])
    return out


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


def in_scratch(path, cwds):
    """Whether path is inside a temporary directory from every directory the
    command can be in at that point. None among them is one it cannot know."""
    if "$" in path or "~" in path or "`" in path:
        return False
    if not path.startswith("/"):
        if None in cwds:
            return False
        return all(in_scratch(os.path.join(c, path), set()) for c in cwds)
    full = os.path.normpath(path)
    for root in SCRATCH_ROOTS:
        if full.startswith(root + "/"):
            # one level below the root at least, and that level not a glob,
            # so `rm -rf /tmp/*` still asks
            return not re.search(r"[*?\[]", full[len(root) + 1:].split("/")[0])
    return False


def git(cwd, *args):
    """git's output in cwd, or None when it fails or takes too long. GIT_*
    variables from the session are dropped, since GIT_DIR would point every
    question at another repo."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    try:
        p = subprocess.run(["git", "-C", cwd, *args], capture_output=True,
                           text=True, timeout=2, env=env)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return p.stdout if p.returncode == 0 else None


def restorable(path):
    """Whether everything rm would delete at path is committed and unchanged,
    so `git checkout` brings it back. Not the repo root, nothing in .git, and
    nothing untracked, ignored, staged or modified under it."""
    if not os.path.lexists(path) or ".git" in path.split("/"):
        return False
    where = path if os.path.isdir(path) and not os.path.islink(path) else os.path.dirname(path)
    top = git(where, "rev-parse", "--show-toplevel")
    if not top:
        return False
    top = os.path.realpath(top.strip())
    rel = os.path.relpath(os.path.realpath(where), top)
    if rel.startswith(".."):
        return False
    if where != path:
        rel = os.path.join(rel, os.path.basename(path))
    if rel in (".", ""):
        return False
    tracked = git(top, "ls-files", "--", rel)
    status = git(top, "status", "--porcelain", "--ignored", "--untracked-files=all", "--", rel)
    return bool(tracked) and status == ""


def rm_targets(args):
    targets, options = [], True
    for a in args:
        if options and a == "--":
            options = False
        elif not (options and a.startswith("-")):
            targets.append(a)
    return targets


def quoted_substitutions(command):
    """The text of every $( ) or backtick substitution inside double quotes.
    shlex keeps such a string as one word, so an rm in it is never a segment of
    its own. Single-quoted text is never run, so it is skipped."""
    out, i, quote = [], 0, None
    while i < len(command):
        ch = command[i]
        if ch == "\\" and quote != "'":
            i += 2
            continue
        if quote is None and ch in "'\"":
            quote = ch
        elif ch == quote:
            quote = None
        elif quote == '"' and (command.startswith("$(", i) or ch == "`"):
            close, depth, j = ("`", 0, i + 1) if ch == "`" else (")", 1, i + 2)
            k = j
            while k < len(command):
                if close == ")" and command[k] == "(":
                    depth += 1
                elif command[k] == close:
                    depth -= 1
                    if depth <= 0:
                        break
                k += 1
            out.append(command[j:k])
            i = k
        i += 1
    return out


def runs_rm_quoted(command):
    """Whether a substitution inside double quotes runs rm, read with the same
    parser as the command itself, so `docker run --rm` is not one."""
    for body in quoted_substitutions(command):
        parts, _ = split_with_separators(body)
        for seg, _, _, _ in parts:
            w = words(seg)
            if w and (os.path.basename(w[0]) == "rm" or
                      (w[0] in WRAPPERS and any(os.path.basename(a) == "rm" for a in w[1:]))):
                return True
        if runs_rm_quoted(body):
            return True
    return False


def lost_targets(targets, env, cwds):
    """The targets rm could delete for good: neither in a temporary directory
    nor committed and unchanged in git. Unreadable ones count as lost."""
    if not targets:
        return ["(no target)"]
    lost = []
    for t in targets:
        for p in expand(t, env):
            if in_scratch(p, cwds):
                continue
            if p == "~" or p.startswith("~/"):
                p = os.path.expanduser(p)
            if re.search(r"[$`~]", p) or (not p.startswith("/") and None in cwds):
                lost.append(p)
                continue
            fulls = [p] if p.startswith("/") else [os.path.join(c, p) for c in cwds]
            for full in fulls:
                matches = glob.glob(full) if re.search(r"[*?\[]", full) else [full]
                if not matches or not all(restorable(os.path.normpath(m)) for m in matches):
                    lost.append(p)
                    break
    return lost


def cd_in_loop(parts):
    """Whether a cd runs inside a loop body in the loop's own shell. Its second
    iteration then starts somewhere else, which a reading in order cannot see."""
    loops = []
    for seg, _, _, depth in parts:
        if seg[0] == "do":
            loops.append(depth)
        elif seg[0] == "done" and loops:
            loops.pop()
        w = words(seg)
        if w and w[0] in ("cd", "pushd", "popd") and loops and depth == loops[-1]:
            return True
    return False


def main():
    data = json.load(sys.stdin)
    command = data.get("tool_input", {}).get("command", "")
    if not re.search(r"\b(gh\s+api|reset|rm)\b", command):
        return
    try:
        structure, heredoc_runs = strip_heredocs(command)
        parts, balanced = split_with_separators(structure)
        segments = [seg for seg, _, _, _ in parts]
    except ValueError:
        answer("ask", "a command that could not be parsed")

    # ask: anywhere in the command, substitutions included
    for seg in segments:
        if any(gh_api_writes(a) for a in after(seg, "gh", "api")):
            answer("ask", "gh api call that can write")
        if any(a in RESET_DESTRUCTIVE for args in git_reset_args(seg) for a in args):
            answer("ask", "git reset that discards working tree changes")

    if runs_rm_quoted(structure):
        answer("ask", "rm inside a quoted substitution, which cannot be read")

    # allow: only when every part is known to be safe
    safe = not SUBSTITUTION.search(command)
    start = data.get("cwd") or os.getcwd()
    # Every directory the command can be in. A cd joins the set instead of
    # replacing it once a separator other than && follows, since the next
    # command runs whether or not the cd worked. A ( ) subshell restores it.
    cwds = {None} if not balanced or cd_in_loop(parts) else {start}
    chain_start, stack, depth = set(cwds), [], 0
    for (seg, before, _, seg_depth), env in zip(parts, known_vars(parts, balanced, structure)):
        while depth < seg_depth:
            stack.append((cwds, chain_start))
            depth += 1
        while depth > seg_depth:
            cwds, chain_start = stack.pop() if stack else ({None}, {None})
            depth -= 1
        if before not in ("&&", "("):
            cwds = chain_start = chain_start | cwds
        elif before == "(":
            chain_start = set(cwds)
        for i, t in enumerate(seg):
            target = seg[i + 1] if i + 1 < len(seg) else ""
            if (t in (">", ">>", "&>") and target != "/dev/null") or t == "<" \
                    or (t == ">&" and target not in ("1", "2")):
                safe = False
        w = words(seg)
        if not w:
            continue
        if os.path.basename(w[0]) == "rm":
            targets = rm_targets(w[1:])
            lost = lost_targets(targets, env, cwds) if not heredoc_runs else ["?"]
            if lost:
                answer("ask", f"rm of {lost[0]}, outside the temporary directories "
                              "and not restorable from git")
            if not all(in_scratch(p, cwds) for t in targets for p in expand(t, env)):
                safe = False  # restorable from git: not a question, not an allow
        elif w[0] in WRAPPERS and any(os.path.basename(a) == "rm" for a in w[1:]):
            answer("ask", "rm behind a wrapper, whose targets cannot be read")
        elif w[0] in ("cd", "pushd", "popd"):
            to = expand(w[1], env) if len(w) == 2 and w[0] == "cd" else [None]
            to = to[0] if len(to) == 1 else None
            if to is None or re.search(r"[$`]", to) or to == "-":
                cwds = {None}
            else:
                to = os.path.expanduser(to)
                cwds = {os.path.normpath(to) if to.startswith("/")
                        else os.path.normpath(os.path.join(c, to)) if c else None
                        for c in cwds}
                # a directory that exists now is one the cd will not fail on
                if all(c and os.path.isdir(c) for c in cwds):
                    chain_start = set(cwds)
        elif w[:2] in (["gh", "api"], ["git", "reset"]):
            pass
        elif w[0] not in SAFE_FILTERS or (w[0] == "sort" and "-o" in w):
            safe = False
    if safe:
        answer("allow", "only safe forms of gh api, git reset and rm")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # a crash would otherwise let the command through unread
        answer("ask", f"bash-guard could not read the command ({type(e).__name__})")
