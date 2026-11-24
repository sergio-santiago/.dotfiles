#!/usr/bin/env bash
################################################################################
# Tests for claude/hooks/bash-guard.py
#
# Tested from both sides, like the secret screen. A guard that lets a write or a
# deletion through does it with nobody asked. A guard that asks on every read is
# the reason it exists, so a safe command that starts asking again is a failure
# too.
################################################################################

GUARD="$DOTFILES/claude/hooks/bash-guard.py"

# Prints allow, ask, or "-" when the hook stays out of the decision.
guard() { # command [cwd]
  local out
  out="$(jq -n --arg c "$1" --arg d "${2:-/Users/x/project}" \
    '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | TMPDIR=/var/folders/xy/T/ python3 "$GUARD")"
  if [[ -z "$out" ]]; then echo "-"; else jq -r '.hookSpecificOutput.permissionDecision' <<<"$out"; fi
}

expect() { # decision command [cwd]
  it "$1: $2${3:+  (in $3)}"
  assert_eq "$1" "$(guard "$2" "${3:-}")"
}

# ── gh api: reads go through ────────────────────────────────────────────────
expect allow 'gh api repos/o/r/pulls/1/comments'
expect allow 'gh api repos/o/r/pulls --paginate --jq ".[] | .title"'
expect allow "gh api repos/o/r/contents/README.md -q '.content' | base64 -d"
expect allow 'gh api -X GET search/issues -f q=repo:o/r'
expect allow 'gh api --method=get repos/o/r'
expect allow 'gh api repos/o/r 2>/dev/null | jq .name'
expect allow 'gh api repos/o/r 2>&1 | head -20'
expect allow "gh api graphql -f query='{ viewer { login } }'"
expect allow 'gh api repos/o/r/pulls && gh api repos/o/r/issues'
expect allow 'cd ~/project && gh api repos/o/r'

# ── gh api: writes ask ──────────────────────────────────────────────────────
expect ask 'gh api -X POST repos/o/r/issues'
expect ask 'gh api -XDELETE repos/o/r'
expect ask 'gh api --method PATCH repos/o/r -f name=x'
expect ask 'gh api repos/o/r/issues -f title=x'
expect ask 'gh api repos/o/r/issues -Ftitle=x'
expect ask 'gh api repos/o/r/issues --input body.json'
expect ask "gh api graphql -f query='mutation { addStar(input: {}) { clientMutationId } }'"
expect ask 'gh api repos/o/r | jq . && gh api -X PUT repos/o/r/topics'
expect ask 'echo $(gh api -X DELETE repos/o/r)'
expect ask "gh api repos/o/r -q '.name"

# ── git reset: only the modes that touch the working tree ask ───────────────
expect allow 'git reset HEAD README.md'
expect allow 'git reset --soft HEAD~1'
expect allow 'git reset'
expect ask 'git reset --hard'
expect ask 'git reset HEAD~1 --hard'
expect ask 'git reset --keep origin/main'
expect ask 'git status && git reset --merge'
expect ask 'git -C . reset --hard'
expect ask 'git -c core.pager=cat reset --hard HEAD~1'
expect ask '/usr/bin/git reset --hard'
expect ask 'git --no-pager -C ~/x reset --keep'

# ── rm: only inside the temporary directories ───────────────────────────────
expect allow 'rm /tmp/out.json'
expect allow 'rm -rf /private/tmp/claude-1/scratch/build'
expect allow 'rm -f /var/folders/xy/T/thing.txt'
expect allow 'rm -rf build' /private/tmp/claude-1/scratch
expect allow 'cd /tmp/work && rm -r dist'
expect ask 'rm README.md'
expect ask 'rm -rf /tmp'
expect ask 'rm -rf /tmp/*'
expect ask 'rm /tmp/../etc/hosts'
expect ask 'rm /tmp/ok ~/notes.md'
expect ask 'rm -rf $DIR/build'
expect ask 'rm -rf -- -weird' /Users/x
expect ask 'cd /tmp && cd ~/project && rm x'
expect - 'echo $(rm /tmp/x)'
expect ask 'echo $(rm ~/x)'
expect ask 'echo "$(rm -rf ~)"'
expect ask 'echo "$(cd x && sudo rm -rf ~)"'
expect - 'echo "$(docker run --rm alpine true)"'
expect ask 'rm -rf "$(pwd)/x"'
expect - "python3 -c 'print(\"\$(rm x)\")'"
expect ask '(cd /tmp); rm -rf ~/x'

# ── rm: by its path, or behind a wrapper ────────────────────────────────────
expect allow '/bin/rm -f /tmp/out.json'
expect ask '/bin/rm -rf ~/x'
expect ask 'command rm -rf ~/x'
expect ask 'sudo rm -rf /tmp/x'
expect ask 'env FOO=1 rm x'
expect ask 'nohup rm -rf ~/x'
expect ask 'echo x | xargs rm -rf'
expect ask 'find . -name "*.log" | xargs /bin/rm'

# ── rm: a variable is expanded only when its value is certain ───────────────
expect allow 'S=/private/tmp/claude-1/scratch; rm -f $S/pag*'
expect allow 'S=/tmp/work && rm -rf ${S}/build'
expect allow 'A=/tmp/a; B=/tmp/b; rm $A/x $B/y'
expect allow 'D=out; cd /tmp/w && rm -r $D'
expect ask 'cd /tmp/w && D=out; rm -r $D'
expect ask 'false && S=/tmp/x; rm -rf $S/*'
expect ask 'test -d x || S=/tmp/x; rm -rf $S/*'
expect ask 'S=/tmp/x | true; rm -rf $S/*'
expect ask 'S=/tmp/x & rm -rf $S/*'
expect ask '(S=/tmp/x); rm -rf $S/*'
expect ask 'S=/tmp/x; read S; rm -rf $S/y'
expect ask 'S=/tmp/x; export S=/; rm -rf $S/y'
expect ask 'S=/tmp/x; false && S=/etc; rm -rf $S/y'
expect ask 'S=$HOME/tmp; rm -rf $S/y'
expect ask 'S=/tmp/x; rm -rf $T/y'
expect ask 'rm -rf $S/y; S=/tmp/x'
expect ask 'S=/tmp; rm -rf $S/*'
# inside an unbroken && chain the rm runs only if the assignment did
expect allow 'cd /tmp/w && S=/private/tmp/s/png && rm -f $S/p-*'
expect - 'cd ~/p && ./gen.sh && S="/private/tmp/s/png" && rm -f $S/p-* && ls $S'
expect ask 'cd /tmp/w && S=/tmp/x || true && rm -rf $S/*'
expect ask 'cd /tmp/w && S=/tmp/x && true; rm -rf $S/*'
expect ask 'cd /tmp/w && S=~/project && rm -rf $S/*'
expect ask 'cd /tmp/w && S=$(mktemp -d) && rm -rf $S'

# A for, a ( ) subshell or a $( ) elsewhere no longer hides a known variable.
# Each name has to be bound exactly once, so nothing can rebind it.
S='S=/private/tmp/c/scratchpad/x'
expect - "$S; rm -rf \$S; for r in a b; do echo \$r; done"
expect - "$S; rm -rf \$S; mkdir -p \$S/a; for r in a b; do (cd \$S/\$r && git init -q); done"
expect - "$S; M=\$(cd \$S && pwd -P); rm -rf \$S/old"
expect allow "$S; J=\$S/cj.txt; rm -f \$J"
expect allow "$S; cd \$S/repro && rm -rf .claude sub"
expect - 'for S in /; do true; done; S=/tmp/x; rm -rf $S'
# a loop variable over fixed words is each of them, and only inside the body
expect - "$S; for p in .claude a.json; do rm -rf \"\${S:?}\"/\"\${p:?}\"; done"
expect ask "$S; for p in .claude ../../../..; do rm -rf \$S/\$p; done"
expect ask "$S; for p in *; do rm -rf \$S/\$p; done"
expect ask "$S; for p in {a,..}; do rm -rf \$S/\$p; done"
expect ask "$S; for p in a; do true; done; rm -rf \$S/\$p"
expect ask "$S; for p in a; do p=/; rm -rf \$p; done"
expect ask 'for p in /tmp/a ~; do rm -rf $p; done'
expect - "$S; for p in a b; do rm -rf \$S/\$p; done; for p in c; do rm -rf \$S/\$p; done"
expect ask "$S; for S in /; do true; done; rm -rf \$S"
expect ask "$S; for S in /; do rm -rf \$S; done"
expect ask 'p=/tmp/x; for p in a; do rm -rf $p; done'
expect ask 'S=/tmp/x; for S in /; do rm -rf $S; done'
expect ask 'S=/tmp/x; S+=/../..; rm -rf $S'
expect ask 'S=/tmp/x; S[0]=/; rm -rf $S'
expect ask 'S=/tmp/x; printf -v S /; rm -rf $S/y'
expect ask 'S=/tmp/x; unset S; rm -rf $S/y'
expect ask 'S=/tmp/x; eval "$X"; rm -rf $S/y'
expect ask 'S=/tmp/x; . ./env.sh; rm -rf $S/y'
expect ask 'S=/tmp/x; command eval "$X"; rm -rf $S/y'
expect - "$S; rm -rf \$S; ruff check ."
expect ask 'S=/tmp/x; (( S++ )); rm -rf $S'
expect ask 'J=$T/cj.txt; rm -f $J'
expect ask 'case x in a) S=/tmp/x;; esac; rm -rf $S/y'
# A keyword in front of rm does not hide it
expect ask 'for x in a; do rm -rf ~; done'
expect ask 'if true; then rm -rf ~/x; fi'
expect ask '{ rm -rf ~/x; }'

# The directory: a cd counts only while && holds, since after any other
# separator the next command also runs when the cd failed.
expect allow 'cd /tmp/w && rm -rf x'
expect ask 'cd /tmp/w; rm -rf x'
expect ask 'cd /tmp/w && true || rm -rf x'
expect ask 'cd /tmp/w | rm -rf x'
expect allow 'cd /tmp/w; rm -rf x' /tmp/other
# a directory that exists now is one the cd will not fail on
expect allow 'cd /private/tmp; rm -rf x'
expect ask '(cd /tmp/w && true); rm -rf x'
expect allow '(cd /tmp/w && rm -rf x)'
expect ask 'cd $NOPE && rm -rf x' /tmp/w
expect ask 'cd /tmp/w && for x in a b; do rm -rf y; cd ~; done'
expect ask 'cd /tmp/w && pushd ~ && rm -rf y'
expect ask 'cd "$X"; cd /tmp/w; cd ..; rm -rf y'

# Heredoc bodies are data: their parentheses and words are not commands. The
# check for $( ) still reads the original, since an unquoted heredoc runs it.
expect - $'python3 - x <<\'EOF\'\nprint(open("a").read())\nEOF\nS=/tmp/s; rm -f $S/p*'
expect allow $'cat <<EOF\nrm -rf ~\nEOF'
expect ask $'cat <<EOF\n$(rm -rf ~)\nEOF\nrm /tmp/x'
expect - $'cat <<EOF\n\\$(date)\nEOF\nrm /tmp/x'

# ── rm: what git can restore is not a question ──────────────────────────────
# A real repo outside the temporary directories the guard knows about (the
# runner's scratch sits under the real $TMPDIR, the guard is given a fake one).
R="$SCRATCH/guard-repo"
mkdir -p "$R/docs/sub" "$R/var"
( cd "$R" && git init -q && printf 'a\n' > docs/a.md && printf 'b\n' > docs/sub/b.md \
  && printf 'c\n' > docs/c.md && printf 'var/\n' > .gitignore \
  && git add -A && git -c user.name=t -c user.email=t commit -qm init \
  && printf 'local\n' > var/cache && printf 'new\n' > docs/new.md && printf 'x\n' >> docs/c.md )
expect - 'rm docs/a.md' "$R"
expect - 'rm -r docs/sub' "$R"
expect - "rm $R/docs/a.md $R/docs/sub/b.md"
expect - 'git rm -q --cached docs/a.md; rm docs/a.md' "$R"
expect - "cd $R && rm docs/a.md"
expect - "D=$R/docs; rm \$D/a.md"
expect ask 'rm docs/c.md' "$R"
expect ask 'rm docs/new.md' "$R"
expect ask 'rm -rf var' "$R"
expect ask 'rm -rf docs' "$R"
expect ask 'rm docs/*.md' "$R"
expect - 'rm docs/a*.md' "$R"
expect ask 'rm -rf .' "$R"
expect ask "rm -rf $R"
expect ask 'rm -rf .git' "$R"
expect ask 'rm .git/HEAD' "$R"
expect ask 'rm docs/missing.md' "$R"
expect ask 'rm docs/a.md' "$R/../.."
expect ask "cd $R; cd \$X; rm docs/a.md"
it "the question names the target it is about"
assert_contains "$(jq -n --arg c 'rm docs/a.md docs/new.md' --arg d "$R" '{tool_input: {command: $c}, cwd: $d}' \
  | TMPDIR=/var/folders/xy/T/ python3 "$GUARD")" 'docs/new.md'
it "a GIT_DIR from the session does not point the check at another repo"
assert_eq "-" "$(GIT_DIR=/nonexistent guard 'rm docs/a.md' "$R")"

# ── everything else is left to the normal rules ─────────────────────────────
expect - 'git status'
expect - 'gh pr view 1'
expect - 'gh api repos/o/r > out.json'
expect - 'gh api repos/o/r | sh'
expect - 'cat $(gh api repos/o/r -q .name)'
expect - 'rm /tmp/x && git push'
expect - 'git reset HEAD x && git commit -m wip'
expect - 'npm run format'
