#!/usr/bin/env bash
################################################################################
# Tests for scripts/bin/brew-maintenance
#
# Every case runs against a fake `brew` whose exit codes and output are driven by
# FAKE_* variables, so the real Homebrew is never invoked and no package is ever
# touched. The fake also logs each invocation, which is how the tests prove a
# negative: that self-updating casks are reported and never upgraded.
################################################################################

BM="$DOTFILES/scripts/bin/brew-maintenance"
CASE_DIR=""

# ── Fake brew ───────────────────────────────────────────────────────────────
setup() {
  CASE_DIR="$(mktemp -d "$SCRATCH/case.XXXXXX")"
  export FAKE_LOG="$CASE_DIR/calls.log"
  export BREW_MAINTENANCE_STAMP="$CASE_DIR/stamp/last-run"
  export BREW_MAINTENANCE_GCLOUD="$CASE_DIR/gcloud.json"
  : >"$FAKE_LOG"

  # Defaults describe a healthy machine with nothing to do. Each test overrides
  # only the variable it is about, so a case reads as its own difference.
  unset FAKE_UPDATE_RC FAKE_UPGRADE_RC FAKE_CLEANUP_RC FAKE_AUTOREMOVE_RC FAKE_DOCTOR_RC
  unset FAKE_UPDATE_OUT FAKE_UPGRADE_OUT FAKE_CLEANUP_OUT FAKE_AUTOREMOVE_OUT FAKE_DOCTOR_OUT
  unset FAKE_OUTDATED_JSON FAKE_GREEDY_JSON

  cat >"$CASE_DIR/brew" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_LOG"
case "$1" in
  update)     printf '%s\n' "${FAKE_UPDATE_OUT-Already up-to-date.}"; exit "${FAKE_UPDATE_RC:-0}" ;;
  upgrade)    printf '%s\n' "${FAKE_UPGRADE_OUT-}";     exit "${FAKE_UPGRADE_RC:-0}" ;;
  cleanup)    printf '%s\n' "${FAKE_CLEANUP_OUT-}";     exit "${FAKE_CLEANUP_RC:-0}" ;;
  autoremove) printf '%s\n' "${FAKE_AUTOREMOVE_OUT-}";  exit "${FAKE_AUTOREMOVE_RC:-0}" ;;
  doctor)     printf '%s\n' "${FAKE_DOCTOR_OUT-Your system is ready to brew.}"
              exit "${FAKE_DOCTOR_RC:-0}" ;;
  outdated)
    if [[ "$*" == *--greedy-auto-updates* ]]; then
      printf '%s\n' "${FAKE_GREEDY_JSON-{\"formulae\":[],\"casks\":[]\}}"
    else
      printf '%s\n' "${FAKE_OUTDATED_JSON-{\"formulae\":[],\"casks\":[]\}}"
    fi
    exit 0 ;;
esac
exit 0
FAKE
  chmod +x "$CASE_DIR/brew"
  export BREW_MAINTENANCE_BREW="$CASE_DIR/brew"
}

# Runs brew-maintenance, capturing output and status separately.
bm_run() {
  OUT="$("$BM" "$@" 2>&1)"
  RC=$?
}

# ── The bug that started this: doctor's status is not the run's status ──────
setup
export FAKE_DOCTOR_RC=1
export FAKE_DOCTOR_OUT='Warning: Some installed formulae or casks are missing dependencies.'
bm_run
it "a brew doctor warning leaves the exit status at 0"
assert_eq 0 "$RC"

it "the warning is still reported, not swallowed"
assert_contains "$OUT" "1 warning(s), advisory only"

it "a real warning is marked with the warning glyph"
assert_contains "$OUT" "! doctor"

# ── Severity is declared, not inferred from the wording ─────────────────────
# "no warnings" contains "warning". A summary line classified by substring match
# rendered a clean doctor as a warning, so the severity is now recorded per step.
setup
bm_run
it "a clean doctor reports no warnings"
assert_contains "$OUT" "no warnings"

it "a clean doctor is NOT marked with the warning glyph"
assert_not_contains "$OUT" "! doctor"

it "a clean doctor is marked as passing"
assert_contains "$OUT" "✓ doctor"

it "a clean doctor leaves the warning total at zero"
assert_contains "$OUT" "0 warning(s)"

# Self-updating casks are information, not work, so they stay green however many
# there are. Yellow has to keep meaning something.
setup
export FAKE_GREEDY_JSON='{"formulae":[],"casks":[{"name":"thaw","installed_versions":["1.1.0"],"current_version":"1.2.0"}]}'
bm_run
it "self-updating casks are reported as passing, never as a warning"
assert_contains "$OUT" "✓ greedy"

it "self-updating casks do not inflate the warning total"
assert_contains "$OUT" "0 warning(s)"

# ── The other half: && no longer cancels the rest of the run ────────────────
setup
export FAKE_UPDATE_RC=1
export FAKE_UPDATE_OUT='fatal: unable to access github.com: Could not resolve host'
bm_run
it "a failed update still lets upgrade run"
assert_contains "$(cat "$FAKE_LOG")" "upgrade"

it "a failed update still lets cleanup run"
assert_contains "$(cat "$FAKE_LOG")" "cleanup"

it "a failed update still lets autoremove run"
assert_contains "$(cat "$FAKE_LOG")" "autoremove"

it "a failed update still lets doctor run"
assert_contains "$(cat "$FAKE_LOG")" "doctor"

it "a failed action does set the exit status to 1"
assert_eq 1 "$RC"

it "the failed step is named in the summary"
assert_contains "$OUT" "✗ update"

# ── Action failures count, one at a time ────────────────────────────────────
setup
export FAKE_UPGRADE_RC=1
bm_run
it "a failed upgrade fails the run"
assert_eq 1 "$RC"

setup
export FAKE_CLEANUP_RC=1
bm_run
it "a failed cleanup fails the run"
assert_eq 1 "$RC"

setup
export FAKE_AUTOREMOVE_RC=1
bm_run
it "a failed autoremove fails the run"
assert_eq 1 "$RC"

# ── A clean run ─────────────────────────────────────────────────────────────
setup
export FAKE_UPGRADE_OUT='==> Upgrading 3 outdated packages:'
export FAKE_CLEANUP_OUT='==> This operation has freed approximately 412MB of disk space'
export FAKE_AUTOREMOVE_OUT='==> Autoremoving 2 unneeded formulae:'
bm_run
it "a clean run exits 0"
assert_eq 0 "$RC"

it "the upgrade count is read from brew's own batch line"
assert_contains "$OUT" "3 upgraded"

it "the reclaimed space is reported"
assert_contains "$OUT" "412MB freed"

it "the autoremove count is reported"
assert_contains "$OUT" "2 removed"

it "every action is counted as ok"
assert_contains "$OUT" "4 action(s) ok"

# ── The stamp: the only record of when maintenance ran ──────────────────────
it "a real run writes the stamp"
assert_file "$BREW_MAINTENANCE_STAMP"

STAMP_LINE="$(cat "$BREW_MAINTENANCE_STAMP")"
it "the stamp starts with an epoch, so its mtime is not the only readable date"
assert_eq 0 "$([[ "${STAMP_LINE%% *}" =~ ^[0-9]{10}$ ]] && echo 0 || echo 1)"

it "the stamp records the failure count"
assert_contains "$STAMP_LINE" "failed=0"

it "the stamp records the action count"
assert_contains "$STAMP_LINE" "actions=4"

setup
export FAKE_UPGRADE_RC=1
bm_run
it "a failed run still writes a stamp, recording the failure"
assert_contains "$(cat "$BREW_MAINTENANCE_STAMP")" "failed=1"

# ── Self-updating casks are reported and never upgraded ─────────────────────
setup
export FAKE_GREEDY_JSON='{"formulae":[],"casks":[{"name":"gcloud-cli","installed_versions":["567.0.0"],"current_version":"578.0.0"},{"name":"thaw","installed_versions":["1.1.0"],"current_version":"1.2.0"}]}'
bm_run
it "self-updating casks are counted"
assert_contains "$OUT" "2 cask(s) with their own updater"

it "brew's record is shown beside the version actually available"
assert_contains "$OUT" "brew records 567.0.0"

it "the escape hatch is printed but not taken"
assert_contains "$OUT" "brew upgrade --cask --greedy-auto-updates <cask>"

it "no upgrade is ever invoked with --greedy"
assert_not_contains "$(grep '^upgrade' "$FAKE_LOG" || true)" "--greedy"

# ── The greedy list is a superset, and has to be reduced ────────────────────
# `brew outdated --greedy-auto-updates` returns the plain outdated casks as well as
# the self-updating ones: the flag only disables the `auto_updates` short circuit in
# Homebrew's Cask#outdated_version. Reported whole, a cask that is genuinely behind
# was filed under "already current, brew's record just trails", which is the worst
# possible thing to say about work still to do.
setup
export FAKE_OUTDATED_JSON='{"formulae":[],"casks":[{"name":"iterm2","installed_versions":["3.5.0"],"current_version":"3.6.0"}]}'
export FAKE_GREEDY_JSON='{"formulae":[],"casks":[{"name":"iterm2","installed_versions":["3.5.0"],"current_version":"3.6.0"},{"name":"thaw","installed_versions":["1.1.0"],"current_version":"1.2.0"}]}'
bm_run
it "a cask in both lists is ordinary work, not a self-updating one"
assert_contains "$OUT" "1 cask(s) with their own updater"

it "the ordinary outdated cask is kept out of the left-alone detail block"
assert_not_contains "$OUT" "iterm2         brew records"

it "the genuinely self-updating cask is still listed there"
assert_contains "$OUT" "thaw"

# The reverse mistake is just as bad: subtracting must not empty the list when the
# plain one happens to be empty.
setup
export FAKE_OUTDATED_JSON='{"formulae":[],"casks":[]}'
export FAKE_GREEDY_JSON='{"formulae":[],"casks":[{"name":"thaw","installed_versions":["1.1.0"],"current_version":"1.2.0"}]}'
bm_run
it "with nothing ordinarily outdated the self-updating cask still surfaces"
assert_contains "$OUT" "1 cask(s) with their own updater"

it "and its versions are still shown side by side"
assert_contains "$OUT" "brew records 1.1.0"

# Every cask outdated for the ordinary reason means nothing is left alone at all.
setup
export FAKE_OUTDATED_JSON='{"formulae":[],"casks":[{"name":"iterm2","installed_versions":["3.5.0"],"current_version":"3.6.0"}]}'
export FAKE_GREEDY_JSON='{"formulae":[],"casks":[{"name":"iterm2","installed_versions":["3.5.0"],"current_version":"3.6.0"}]}'
bm_run
it "a greedy list that is only the plain list reduces to no self-updating casks"
assert_contains "$OUT" "no self-updating casks"

it "and no left-alone detail block is printed at all"
assert_not_contains "$OUT" "Casks with their own updater, left alone"

# --check reads both lists in the order the subtraction needs.
setup
export FAKE_OUTDATED_JSON='{"formulae":[],"casks":[{"name":"iterm2","installed_versions":["3.5.0"],"current_version":"3.6.0"}]}'
export FAKE_GREEDY_JSON='{"formulae":[],"casks":[{"name":"iterm2","installed_versions":["3.5.0"],"current_version":"3.6.0"},{"name":"thaw","installed_versions":["1.1.0"],"current_version":"1.2.0"}]}'
bm_run --check
it "--check applies the same subtraction"
assert_contains "$OUT" "1 cask(s) with their own updater"

it "--check still counts the ordinary outdated cask as pending work"
assert_contains "$OUT" "! casks       1 outdated"

# ── Outdated counts reach the stamp ─────────────────────────────────────────
setup
export FAKE_OUTDATED_JSON='{"formulae":[{"name":"jq"},{"name":"fd"}],"casks":[{"name":"iterm2"}]}'
bm_run
it "the stamp records how many formulae are still outdated"
assert_contains "$(cat "$BREW_MAINTENANCE_STAMP")" "formulae=2"

it "the stamp records how many casks are still outdated"
assert_contains "$(cat "$BREW_MAINTENANCE_STAMP")" "casks=1"

# ── --check changes nothing ─────────────────────────────────────────────────
setup
export FAKE_OUTDATED_JSON='{"formulae":[{"name":"jq"}],"casks":[]}'
bm_run --check
it "--check exits 0"
assert_eq 0 "$RC"

it "--check writes no stamp, because looking is not maintaining"
assert_no_file "$BREW_MAINTENANCE_STAMP"

# Anchored to the start of the logged argv: `outdated --greedy-auto-updates`
# contains the substring "update", and matching that would pass for the wrong
# reason while a real `brew update` slipped through.
it "--check runs no update"
assert_eq 0 "$(grep -c '^update' "$FAKE_LOG" || true)"

it "--check runs no upgrade"
assert_eq 0 "$(grep -c '^upgrade' "$FAKE_LOG" || true)"

it "--check runs no cleanup"
assert_eq 0 "$(grep -c '^cleanup' "$FAKE_LOG" || true)"

it "--check runs no autoremove"
assert_eq 0 "$(grep -c '^autoremove' "$FAKE_LOG" || true)"

it "--check does read the offline outdated list"
assert_eq 1 "$(grep -c '^outdated --json' "$FAKE_LOG" || true)"

it "--check still reports what is pending"
assert_contains "$OUT" "1 outdated"

setup
export FAKE_DOCTOR_RC=1
export FAKE_DOCTOR_OUT='Warning: something the maintainers might want to know'
bm_run --check
it "--check exits 0 even when doctor warns"
assert_eq 0 "$RC"

# ── gcloud is reported from its own state file, never run ───────────────────
setup
printf '%s\n' '{"notifications":[{"id":"update"}]}' >"$BREW_MAINTENANCE_GCLOUD"
bm_run
it "a pending gcloud notice is surfaced"
assert_contains "$OUT" "gcloud has 1 pending notice(s)"

it "the pending notice names the flag that would act on it"
assert_contains "$OUT" "--with-external"

it "a pending gcloud notice does not fail the run"
assert_eq 0 "$RC"

setup
printf '%s\n' '{"notifications":[]}' >"$BREW_MAINTENANCE_GCLOUD"
bm_run
it "an empty notification list reads as no news"
assert_contains "$OUT" "gcloud has no news"

# ── Argument handling ───────────────────────────────────────────────────────
setup
bm_run --nope
it "an unknown flag exits 2, distinct from a failed action"
assert_eq 2 "$RC"

setup
bm_run --help
it "--help exits 0"
assert_eq 0 "$RC"

it "--help explains the status contract"
assert_contains "$OUT" "Actions decide the exit status"

setup
export BREW_MAINTENANCE_BREW="$CASE_DIR/no-such-brew"
bm_run
it "a missing brew exits 2 rather than pretending to work"
assert_eq 2 "$RC"

# ── --quiet ─────────────────────────────────────────────────────────────────
setup
export FAKE_UPDATE_OUT='==> Updating Homebrew...'
bm_run --quiet
it "--quiet suppresses the command output"
assert_not_contains "$OUT" "==> Updating Homebrew"

it "--quiet keeps the summary"
assert_contains "$OUT" "action(s) ok"

# The remedy has to match the mode. Under --quiet there is no output above to look
# at, and $WORK is gone by then, so the usual pointer sends you nowhere.
setup
export FAKE_UPGRADE_RC=1
bm_run --quiet
it "a failure under --quiet does not point at output that was never printed"
assert_not_contains "$OUT" "see the output above"

it "it names the flag to drop instead"
assert_contains "$OUT" "re-run without --quiet"

setup
export FAKE_UPGRADE_RC=1
bm_run
it "without --quiet the pointer still refers to the output above"
assert_contains "$OUT" "see the output above"

unset BREW_MAINTENANCE_BREW BREW_MAINTENANCE_STAMP BREW_MAINTENANCE_GCLOUD FAKE_LOG
