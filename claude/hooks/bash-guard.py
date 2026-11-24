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
#                         the repo root or .git (see unrestorable). A $VAR in a
#                         target is expanded only when its value is certain
#                         (see known_vars), a relative target only from every
#                         directory the command can be in (see directories),
#                         otherwise it asks. Behind a wrapper (sudo, env,
#                         command, xargs...) or in a quoted $( ) it always asks.
#                         An rm git can restore is left to the normal rules
#     allow  every part is a safe form of the above, a filter from
#            SAFE_FILTERS or a `cd`, with no substitution and no redirect
#            other than to /dev/null or between stdout and stderr.
#     -      anything else. The normal rules and mode decide.
#
#   Anything it cannot read for certain asks or stays out, it never allows.
#   A crash asks too, since an empty answer would let the command through.
#
# Layout:
#   constants, then reading the command (split, heredocs, words), what its
#   variables and directory are at each point, the rm checks, and main.
################################################################################

import glob
import json
import os
import re
import shlex
import subprocess
import sys

# ── What the command is made of ─────────────────────────────────────────────
SEPARATORS = {"|", "||", "&&", ";", "&", "(", ")", "\n"}
REDIRECTS = {">", ">>", ">&", "<", "&>"}
# Words a command can sit behind without being an argument of them.
KEYWORDS = {"do", "then", "else", "elif", "if", "while", "until", "{", "!"}
# Commands that run the command after them. An rm behind one asks whatever its
# targets, since xargs takes them from stdin and the rest change who runs it.
WRAPPERS = {"command", "builtin", "exec", "env", "sudo", "doas", "nohup", "nice",
            "time", "timeout", "caffeinate", "xargs"}
NAME = r"[A-Za-z_]\w*"
HEREDOC = re.compile(r"<<-?\s*(['\"]?)(" + NAME + r")\1")
SUBSTITUTION = re.compile(r"\$\(|`|<\(")

# ── Variables ───────────────────────────────────────────────────────────────
ASSIGNMENT = re.compile(r"(" + NAME + r")=(.*)", re.S)
# Any word that binds a name: `S=`, `S+=`, `S[0]=`. Counted wherever it sits.
BINDS = re.compile(r"(" + NAME + r")(\[[^\]]*\])?\+?=")
# `$S`, `${S}` and `${S:?}`, which only adds a failure when S is unset
VARIABLE = re.compile(r"\$\{(" + NAME + r")(?::?\?[^}]*)?\}|\$(" + NAME + r")")
# Words whose arguments name variables they set. Each name after one counts as
# another binding of it, which is enough to stop trusting that name.
REBINDERS = {"read", "for", "select", "export", "declare", "typeset", "local",
             "unset", "readonly", "mapfile", "readarray", "getopts", "printf"}
# Words that can change any variable at all. One of them and none is trusted.
ANY_REBINDER = {"eval", "source", ".", "let"}

# ── The commands it decides ─────────────────────────────────────────────────
SAFE_FILTERS = {"jq", "head", "tail", "grep", "rg", "wc", "sort", "uniq", "cut",
                "tr", "base64", "column", "cat", "echo", "printf", "true"}
BODY_FLAGS = ("-f", "-F", "--field", "--raw-field", "--input")
RESET_DESTRUCTIVE = ("--hard", "--merge", "--keep")
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


# ── Reading the command ─────────────────────────────────────────────────────

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


def words(seg):
    """The command words: no redirects or their targets, no leading VAR=x or
    keyword, so `do rm x` reads as `rm x`."""
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
    while out and (out[0] in KEYWORDS or ASSIGNMENT.fullmatch(out[0])):
        out.pop(0)
    return out


def loop_stacks(parts):
    """For each segment, the depths of the loops it sits in, innermost last. A
    `do` opens one at its own depth and a `done` closes the innermost."""
    stack, out = [], []
    for seg, _, _, depth in parts:
        if seg[0] == "do":
            stack.append(depth)
        elif seg[0] == "done" and stack:
            stack.pop()
        out.append(tuple(stack))
    return out


# ── Variables ───────────────────────────────────────────────────────────────

def fixed_loop(seg):
    """`for NAME in word...` over words that expand to nothing else."""
    return len(seg) > 3 and seg[0] == "for" and seg[2] == "in" \
        and re.fullmatch(NAME, seg[1]) \
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
                    n = re.match(NAME, a)
                    if n and not BINDS.match(a):
                        counts[n[0]] = counts.get(n[0], 0) + 1
    return counts


def known_vars(parts, balanced, structure):
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

    A `for` over fixed words gives its name each word inside the body, as a
    tuple, provided nothing else binds that name.
    """
    trusted = balanced and "((" not in structure and \
        not any(rebinds_any(words(seg)) for seg, _, _, _ in parts)
    bound = bindings(parts)
    env, chained, snapshots, loop_names, pending, previous = {}, set(), [], [], None, ()
    for (seg, before, after_sep, depth), stack in zip(parts, loop_stacks(parts)):
        if before != "&&":
            for name in chained:
                env.pop(name, None)
            chained = set()
        if len(stack) > len(previous):  # a do: the pending loop's body starts
            name = pending[0] if pending and pending[2] == depth and trusted \
                and pending[0] not in bound else None
            if name:
                env[name] = tuple(pending[1])
            loop_names.append(name)
            pending = None
        elif len(stack) < len(previous) and loop_names:  # a done
            env.pop(loop_names.pop() or "", None)
        previous = stack
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
            if (certain or in_chain) and bound.get(name) == 1 \
                    and not re.search(r"[$`]", value):
                env[name] = value
                if in_chain:
                    chained.add(name)
                else:
                    chained.discard(name)
            else:
                env.pop(name, None)
                chained.discard(name)
    return snapshots


def expand(path, env):
    """Every value path can take. A known name is a string, or a tuple for a
    loop variable over fixed words. Unknown names stay as they are."""
    m = VARIABLE.search(path)
    if not m:
        return [path]
    value = env.get(m[1] or m[2])
    if value is None:
        return [path[:m.end()] + rest for rest in expand(path[m.end():], env)]
    values = value if isinstance(value, tuple) else (value,)
    return [path[:m.start()] + v + rest for v in values
            for rest in expand(path[m.end():], env)]


# ── The directory ───────────────────────────────────────────────────────────

def directories(parts, envs, start, balanced):
    """For each segment, every directory the command can be in when it runs,
    None standing for one it cannot know.

    A cd joins the set instead of replacing it once a separator other than &&
    follows, since the next command runs whether or not the cd worked, unless
    its directory exists now. A ( ) subshell restores the set on its way out,
    and a cd that a loop repeats in its own shell makes every directory unknown,
    since its second iteration starts somewhere else.
    """
    in_loop = any(stack and depth == stack[-1] and words(seg)[:1] in (["cd"], ["pushd"], ["popd"])
                  for (seg, _, _, depth), stack in zip(parts, loop_stacks(parts)))
    cwds = {None} if not balanced or in_loop else {start}
    chain_start, saved, depth, out = set(cwds), [], 0, []
    for (seg, before, _, seg_depth), env in zip(parts, envs):
        while depth < seg_depth:
            saved.append((cwds, chain_start))
            depth += 1
        while depth > seg_depth:
            cwds, chain_start = saved.pop() if saved else ({None}, {None})
            depth -= 1
        if before not in ("&&", "("):
            cwds = chain_start = chain_start | cwds
        elif before == "(":
            chain_start = set(cwds)
        out.append(cwds)
        w = words(seg)
        if not w or w[0] not in ("cd", "pushd", "popd"):
            continue
        to = expand(w[1], env) if len(w) == 2 and w[0] == "cd" else []
        to = to[0] if len(to) == 1 else None
        if to is None or re.search(r"[$`]", to) or to == "-":
            cwds = {None}
            continue
        to = os.path.expanduser(to)
        cwds = {os.path.normpath(to) if to.startswith("/")
                else os.path.normpath(os.path.join(c, to)) if c else None
                for c in cwds}
        if all(c and os.path.isdir(c) for c in cwds):
            chain_start = set(cwds)  # a directory that exists now will not fail
    return out


# ── rm ──────────────────────────────────────────────────────────────────────

def is_rm(w):
    return bool(w) and os.path.basename(w[0]) == "rm"


def wrapped_rm(w):
    return bool(w) and w[0] in WRAPPERS and any(os.path.basename(a) == "rm" for a in w[1:])


def rm_targets(args):
    targets, options = [], True
    for a in args:
        if options and a == "--":
            options = False
        elif not (options and a.startswith("-")):
            targets.append(a)
    return targets


def runs_rm_quoted(command):
    """Whether a substitution inside double quotes runs rm, read with the same
    parser as the command itself, so `docker run --rm` is not one."""
    for body in quoted_substitutions(command):
        parts, _ = split_with_separators(body)
        if any(is_rm(words(seg)) or wrapped_rm(words(seg)) for seg, _, _, _ in parts):
            return True
        if runs_rm_quoted(body):
            return True
    return False


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


def repo_path(path, tops):
    """(repo top, path inside it) for an existing path, or None. Not for the
    repo root itself or anything in .git. tops caches each directory's repo."""
    if not os.path.lexists(path) or ".git" in path.split("/"):
        return None
    where = path if os.path.isdir(path) and not os.path.islink(path) else os.path.dirname(path)
    if where not in tops:
        top = git(where, "rev-parse", "--show-toplevel")
        tops[where] = os.path.realpath(top.strip()) if top else None
    top = tops[where]
    if not top:
        return None
    rel = os.path.relpath(os.path.realpath(where), top)
    if rel.startswith(".."):
        return None
    if where != path:
        rel = os.path.join(rel, os.path.basename(path))
    return None if rel in (".", "") else (top, rel)


def status_paths(status):
    """The paths in `git status --porcelain -z`: each entry is "XY path", and a
    rename or copy is followed by its original path as an entry of its own."""
    entries, out, i = status.split("\0"), [], 0
    while i < len(entries):
        e = entries[i]
        if len(e) > 3:
            out.append(e[3:])
            if "R" in e[:2] or "C" in e[:2]:
                i += 1
                out += entries[i:i + 1]
        i += 1
    return out


def under(rel, names):
    """Whether any of names is rel or inside it. An ignored directory comes
    with a trailing slash, which this still counts."""
    return any(n == rel or n.startswith(rel + "/") for n in names)


def unrestorable(paths):
    """The paths `git checkout` could not bring back: everything under each one
    has to be committed and unchanged, with nothing untracked, ignored, staged
    or modified. One ls-files and one status per repo, not per path."""
    tops, by_repo, lost = {}, {}, []
    for p in paths:
        found = repo_path(p, tops)
        if found:
            by_repo.setdefault(found[0], []).append((p, found[1]))
        else:
            lost.append(p)
    for top, items in by_repo.items():
        rels = [rel for _, rel in items]
        # literal, so a file named `a[1].md` is not read as a pattern
        tracked = git(top, "--literal-pathspecs", "ls-files", "-z", "--", *rels)
        status = git(top, "--literal-pathspecs", "status", "--porcelain", "-z",
                     "--ignored", "--untracked-files=all", "--", *rels)
        if tracked is None or status is None:
            lost.extend(p for p, _ in items)
            continue
        files, changed = tracked.split("\0"), status_paths(status)
        lost.extend(p for p, rel in items if not under(rel, files) or under(rel, changed))
    return lost


def lost_targets(targets, env, cwds):
    """The targets rm could delete for good: neither in a temporary directory
    nor committed and unchanged in git. Unreadable ones count as lost."""
    if not targets:
        return ["(no target)"]
    checks = []  # (target as written, paths it reaches), None for one unreadable
    for t in targets:
        for p in expand(t, env):
            if in_scratch(p, cwds):
                continue
            if p == "~" or p.startswith("~/"):
                p = os.path.expanduser(p)
            if re.search(r"[$`~]", p) or (not p.startswith("/") and None in cwds):
                checks.append((p, [None]))
                continue
            reached = []
            for full in [p] if p.startswith("/") else [os.path.join(c, p) for c in cwds]:
                matches = glob.glob(full) if re.search(r"[*?\[]", full) else [full]
                reached += [os.path.normpath(m) for m in matches] or [None]
            checks.append((p, reached))
    gone = set(unrestorable({r for _, reached in checks for r in reached if r}))
    return [p for p, reached in checks if None in reached or gone & set(reached)]


# ── Deciding ────────────────────────────────────────────────────────────────

def gh_api_write_in(seg):
    """Whether any `gh api` call in seg can write."""
    return any(gh_api_writes(seg[i + 2:]) for i in range(len(seg) - 1)
               if seg[i] == "gh" and seg[i + 1] == "api")


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


def redirects_somewhere(seg):
    """A redirect other than to /dev/null or between stdout and stderr."""
    for i, t in enumerate(seg):
        target = seg[i + 1] if i + 1 < len(seg) else ""
        if (t in (">", ">>", "&>") and target != "/dev/null") or t == "<" \
                or (t == ">&" and target not in ("1", "2")):
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
    except ValueError:
        answer("ask", "a command that could not be parsed")

    # ask: anywhere in the command, substitutions included
    for seg, _, _, _ in parts:
        if gh_api_write_in(seg):
            answer("ask", "gh api call that can write")
        if any(a in RESET_DESTRUCTIVE for args in git_reset_args(seg) for a in args):
            answer("ask", "git reset that discards working tree changes")
    if runs_rm_quoted(structure):
        answer("ask", "rm inside a quoted substitution, which cannot be read")

    # rm, segment by segment, then allow only when every part is known to be safe
    envs = known_vars(parts, balanced, structure)
    places = directories(parts, envs, data.get("cwd") or os.getcwd(), balanced)
    safe = not SUBSTITUTION.search(command)
    for (seg, _, _, _), env, cwds in zip(parts, envs, places):
        safe = safe and not redirects_somewhere(seg)
        w = words(seg)
        if is_rm(w):
            targets = rm_targets(w[1:])
            lost = ["?"] if heredoc_runs else lost_targets(targets, env, cwds)
            if lost:
                answer("ask", f"rm of {lost[0]}, outside the temporary directories "
                              "and not restorable from git")
            # what git can restore is left to the normal rules, never allowed
            safe = safe and all(in_scratch(p, cwds) for t in targets for p in expand(t, env))
        elif wrapped_rm(w):
            answer("ask", "rm behind a wrapper, whose targets cannot be read")
        elif not w or w[0] in ("cd", "pushd", "popd") or w[:2] in (["gh", "api"], ["git", "reset"]):
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
