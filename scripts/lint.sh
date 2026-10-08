#!/bin/bash
################################################################################
# Shell Script Linter
#
# Description:
#   Runs ShellCheck over every tracked bash script in the repo: the *.sh files
#   plus any extensionless file whose shebang names bash or sh, such as the
#   commands under scripts/bin/. Settings and the few rules disabled on purpose
#   live in .shellcheckrc at the repo root, each with its reason.
#
#   Asks git for the file list rather than walking the tree, so a scratch file
#   or anything ignored never fails the lint.
#
# Usage:
#   ./scripts/lint.sh   |   make lint
################################################################################

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not found. Run 'make brew'" >&2
  exit 1
fi

files=()
while IFS= read -r f; do
  [[ -f "$DOTFILES/$f" ]] || continue
  case "$f" in
    *.sh) files+=("$f") ;;
    *.*)  ;;
    *)    head -n 1 "$DOTFILES/$f" | grep -qE '^#!.*\b(bash|sh)\b' && files+=("$f") ;;
  esac
done < <(git -C "$DOTFILES" ls-files)

cd "$DOTFILES" || exit 1
if shellcheck "${files[@]}"; then
  echo "✓ ${#files[@]} scripts, no findings"
else
  exit 1
fi
