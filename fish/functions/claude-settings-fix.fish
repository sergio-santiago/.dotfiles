# ~/.config/fish/functions/claude-settings-fix.fish
# ==============================================================================
# 🔗 Open a Claude Code session in this repo to repair ~/.claude/settings.json
# ------------------------------------------------------------------------------
# Purpose:
#   - ~/.claude/settings.json is meant to be a symlink into this repo. Some
#     macOS apps save it with a Foundation atomic write (temp file renamed over
#     the path), which replaces the link with a plain file. From then on the two
#     copies drift apart without anything saying so.
#   - When the link is intact this says so and exits. When it is not, it starts
#     an interactive `claude` session in the repo with a ready-made prompt that
#     carries the diff, so the session starts from the facts.
#
# What the session is asked to do:
#   - Explain which keys differ and what likely rewrote the file, check the new
#     keys for personal data (this repo is public), show current vs proposed and
#     wait for an OK, then back up the loose file, move the keys into the repo
#     and restore the link. Never commit without asking.
#
# Evidence for the cause (checked 2026-11-24):
#   - Claude Code writes through the link. The broken copy had Apple's JSON
#     format (`"key" : value`, sorted keys, `\/`) and mode 755, which a
#     `Data.write(.atomic)` on the symlink reproduces byte for byte.
# ==============================================================================

function claude-settings-fix --description 'Repair a broken ~/.claude/settings.json link with a Claude session'
    # The repo is found from this file, so it works wherever the repo is cloned.
    set -l repo (path resolve (status dirname)/../..)
    set -l target $repo/claude/settings.json
    set -l live $HOME/.claude/settings.json

    if test -L $live; and test (path resolve $live) = (path resolve $target)
        echo "🔗 ~/.claude/settings.json is linked to the repo, nothing to fix."
        return 0
    end

    set -l state
    if test -L $live
        set state "a symlink to "(readlink $live)", not to the repo"
    else if test -f $live
        set state "a plain file (created "(stat -f '%SB' $live)", mode "(stat -f '%Lp' $live)")"
    else
        set state missing
    end

    # Diffed with sorted keys, so a format change alone shows as no difference.
    # Raw files as a fallback when either side is not valid JSON.
    set -l diff
    if test -f $live
        set -l tmp (mktemp -d)
        if jq -S . $target >$tmp/repo 2>/dev/null; and jq -S . $live >$tmp/live 2>/dev/null
            set diff (diff -u --label repo --label live $tmp/repo $tmp/live)
        else
            set diff (diff -u --label repo --label live $target $live)
        end
        rm -rf $tmp
        test -z "$diff"; and set diff "(same content, only the format differs)"
    end

    # `string collect` keeps the diff as one value. Without it the substitution
    # splits on newlines and fish pastes the text around it onto every line.
    set -l prompt "~/.claude/settings.json is $state. It should be a symlink to claude/settings.json in this repo.

Diff with sorted keys (repo vs live):
"(string join \n -- $diff | string collect)"

Steps, one at a time:
1. Explain in plain words which keys differ, and what likely rewrote the file (format, creation time, mode). Apple's JSON format and mode 755 point to a macOS app doing an atomic write over the link.
2. Flag any new key that carries personal or machine-private data. This repo is public, and such keys must not move into it.
3. Show a table of current vs proposed and wait for my OK.
4. Copy the loose file to ~/.claude/backups/, move the approved keys into claude/settings.json, check both copies have the same content with jq -S, then restore the link with ln -sfh.
5. Run the repo checks, and do not commit without asking."

    echo "🔗 ~/.claude/settings.json is $state. Opening a Claude session in $repo"
    cd $repo; or return 1
    command claude $prompt
end
