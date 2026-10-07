# ~/.config/fish/conf.d/02-local-bin.fish
# ==============================================================================
# 📦 Local user binaries and private functions
# ------------------------------------------------------------------------------
# Purpose:
#   - Add ~/.local/bin to PATH for user-installed binaries.
#   - Follows XDG Base Directory Specification for user binaries.
#   - Used by tools like pipx, Claude native install, and other user tools.
#   - Add ~/.config/fish/functions-private to the function path, for functions that
#     must not be published. Both halves are the same idea: what belongs to this
#     machine and not to the repo.
#
# Load scope:
#   - Global (applies to both interactive and non-interactive shells).
#
# Load order:
#   - After 01-homebrew, and that order is load-bearing rather than cosmetic.
#     `brew shellenv` prepends /opt/homebrew/bin on every run, so whichever of the
#     two files is sourced last wins. This one ran first until August 2026, which
#     meant Homebrew silently outranked ~/.local/bin: installing espeak-ng put its
#     own `speak` binary on PATH and shadowed the one in scripts/bin, and `speak
#     full` started reading the word "full" out loud instead of the last reply.
#
# Notes:
#   - Uses fish_add_path which is idempotent and handles duplicates.
#   - Prepends to PATH so user binaries take precedence over Homebrew's.
#
# Scope:
#   - `-g`, explicitly. Left to itself, fish_add_path writes a *universal*
#     fish_user_paths, which lives in ~/.config/fish/fish_variables: a file this repo
#     does not track and `make link` does not manage, so part of PATH would be
#     defined outside version control and would survive deleting the line that asked
#     for it. Global instead means PATH is rebuilt from this file on every start,
#     which is the same reasoning 01-homebrew.fish gives for HOMEBREW_NO_ENV_HINTS.
# ==============================================================================

fish_add_path -gp "$HOME/.local/bin"

# ~/.config/fish/functions is a symlink into this repo, which is public, so anything
# dropped there is one `git add .` away from being published. This directory is a
# real directory outside it, and it is where a function goes when its name, its path
# or its description would say more about the machine than a public repo should.
# Backed up through scripts/private-files.sh, not by being in version control here.
if test -d "$HOME/.config/fish/functions-private"
    set -gp fish_function_path "$HOME/.config/fish/functions-private"
end
