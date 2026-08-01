#!/usr/bin/env bash
################################################################################
# Tests for scripts/doctor.sh
#
# Two properties, both of which used to rest on nothing but care.
#
# The REQUIRED list is written by hand, so a formula added to the Brewfile and
# forgotten there is installed by `make brew` and then never checked again. Nothing
# breaks when that happens, which is the problem: doctor reports all-green over a
# gap. These tests compare the two lists in both directions.
#
# And doctor.sh promises in its own header that it touches nothing it manages. That
# is checked by running it against a throwaway HOME and asserting the four trees the
# installer owns are still absent afterwards. Deliberately not "the HOME is empty":
# doctor asks `brew outdated`, and brew writes its own bootsnap cache under
# ~/Library/Caches on the way, which is brew's business and not a config change.
################################################################################

DOCTOR="$DOTFILES/scripts/doctor.sh"
BREWFILE="$DOTFILES/Brewfile"

# The one formula whose binary is not named after it. doctor.sh names every entry
# by the binary it provides, so the two lists differ by exactly this mapping. Add
# to it only when a new formula genuinely ships a differently named command.
declare -a BIN_FOR_FORMULA=("poppler=pdftotext")

binary_for() { # formula → the command it provides, one per line
  local pair
  for pair in "${BIN_FOR_FORMULA[@]}"; do
    [[ "${pair%%=*}" == "$1" ]] && { printf '%s\n' "${pair#*=}"; return; }
  done
  printf '%s\n' "$1"
}

# Tap-qualified names are reduced to the bare formula, since that is what the
# binary is called: `hashicorp/tap/terraform` provides `terraform`.
brewfile_binaries() {
  sed -nE 's/^brew "([^"]+)".*/\1/p' "$BREWFILE" | sed 's#.*/##' |
    while IFS= read -r formula; do binary_for "$formula"; done | sort -u
}

doctor_required() {
  sed -nE 's/^REQUIRED=\((.*)\)[[:space:]]*$/\1/p' "$DOCTOR" | tr ' ' '\n' | grep . | sort -u
}

# ── The two lists have to agree ─────────────────────────────────────────────
EXPECTED="$(brewfile_binaries)"
ACTUAL="$(doctor_required)"

it "doctor.sh declares a REQUIRED list at all"
assert_eq 0 "$([[ -n "$ACTUAL" ]] && echo 0 || echo 1)"

it "the Brewfile declares formulae the test can read"
assert_eq 0 "$([[ -n "$EXPECTED" ]] && echo 0 || echo 1)"

# Reported as the difference itself rather than as two counts: "18 vs 19" sends you
# to diff the lists by hand, while the name tells you what to add.
MISSING="$(comm -23 <(printf '%s\n' "$EXPECTED") <(printf '%s\n' "$ACTUAL") | tr '\n' ' ')"
it "every Brewfile formula is checked by doctor.sh"
assert_eq "" "${MISSING% }"

EXTRA="$(comm -13 <(printf '%s\n' "$EXPECTED") <(printf '%s\n' "$ACTUAL") | tr '\n' ' ')"
it "doctor.sh checks nothing the Brewfile does not install"
assert_eq "" "${EXTRA% }"

# ── It looks and never touches ──────────────────────────────────────────────
# A throwaway HOME with nothing in it: every symlink check fails, which is what
# makes the exit status below deterministic instead of a verdict on this machine.
DOCTOR_HOME="$(mktemp -d "$SCRATCH/doctorhome.XXXXXX")"
DOCTOR_OUT="$(env HOME="$DOCTOR_HOME" XDG_CACHE_HOME="$DOCTOR_HOME/.cache" \
  bash "$DOCTOR" 2>&1)"
DOCTOR_RC=$?

it "doctor.sh creates none of the trees the installer owns"
assert_eq "" "$(cd "$DOCTOR_HOME" && ls -d .config .claude .ssh .local 2>/dev/null | tr '\n' ' ')"

it "a HOME with no symlinks exits 1, so a broken machine is not reported as fine"
assert_eq 1 "$DOCTOR_RC"

it "the missing links are named, with the command that creates them"
assert_contains "$DOCTOR_OUT" "missing. Run 'make link'"

it "the summary still prints after failures"
assert_contains "$DOCTOR_OUT" "passed"

# ── What it says about Homebrew ─────────────────────────────────────────────
# doctor.sh takes brew from PATH rather than from a variable, so a fake one goes in
# front of it. Each case is a different answer from brew, and what is under test is
# what doctor.sh concludes from it.
fake_brew() { # body of the case statement for `outdated`
  local dir
  dir="$(mktemp -d "$SCRATCH/brewbin.XXXXXX")"
  cat >"$dir/brew" <<EOF
#!/bin/sh
case "\$1" in
  outdated) $1 ;;
esac
exit 0
EOF
  chmod +x "$dir/brew"
  printf '%s' "$dir"
}

doctor_with_brew() { # fake-bin-dir
  local h
  h="$(mktemp -d "$SCRATCH/dh.XXXXXX")"
  DOUT="$(env HOME="$h" XDG_CACHE_HOME="$h/.cache" PATH="$1:$PATH" bash "$DOCTOR" 2>&1)"
}

# `printf '' | jq '.casks | length'` exits 0 with no output, so the `|| echo 0`
# fallback never fired and a brew that failed outright read as a clean machine.
doctor_with_brew "$(fake_brew 'exit 1')"
it "a brew that cannot answer is reported, not read as nothing outdated"
assert_contains "$DOUT" "could not read the outdated list"

it "and it does not also claim there are no self-updating casks"
assert_not_contains "$DOUT" "no self-updating casks"

# The greedy list is the plain list plus the auto-updating casks, so counting it
# whole made this line contradict the warning printed immediately above it.
GREEDY_FAKE='case "$*" in
      *--greedy-auto-updates*) printf "%s\\n" "{\"formulae\":[],\"casks\":[{\"name\":\"iterm2\"},{\"name\":\"thaw\"}]}" ;;
      *) printf "%s\\n" "{\"formulae\":[],\"casks\":[{\"name\":\"iterm2\"}]}" ;;
    esac'
doctor_with_brew "$(fake_brew "$GREEDY_FAKE")"
it "an ordinary outdated cask is reported as work to do"
assert_contains "$DOUT" "1 cask(s) outdated"

it "and is not double-counted as a cask that updates itself"
assert_contains "$DOUT" "1 cask(s) update themselves"

# Nothing ordinarily outdated, one genuine self-updater: the subtraction must not
# swallow it.
ONLY_GREEDY='case "$*" in
      *--greedy-auto-updates*) printf "%s\\n" "{\"formulae\":[],\"casks\":[{\"name\":\"thaw\"}]}" ;;
      *) printf "%s\\n" "{\"formulae\":[],\"casks\":[]}" ;;
    esac'
doctor_with_brew "$(fake_brew "$ONLY_GREEDY")"
it "with nothing ordinarily outdated the machine reads as clean"
assert_contains "$DOUT" "nothing outdated"

it "and the genuine self-updater is still counted"
assert_contains "$DOUT" "1 cask(s) update themselves"
