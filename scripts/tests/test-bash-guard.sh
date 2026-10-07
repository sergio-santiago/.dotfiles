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
expect ask 'echo $(rm /tmp/x)'

# ── everything else is left to the normal rules ─────────────────────────────
expect - 'git status'
expect - 'gh pr view 1'
expect - 'gh api repos/o/r > out.json'
expect - 'gh api repos/o/r | sh'
expect - 'cat $(gh api repos/o/r -q .name)'
expect - 'rm /tmp/x && git push'
expect - 'git reset HEAD x && git commit -m wip'
expect - 'npm run format'
