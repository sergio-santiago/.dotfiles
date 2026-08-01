# Working in this repo

Instructions specific to `~/.dotfiles`. The global rules in `~/.claude/CLAUDE.md` still
apply, this file only adds what is particular to this repo.

## This repo is public

`sergio-santiago/.dotfiles` is a **public** GitHub repo. Nothing machine-private goes in
it: no hostnames, no usernames for real hosts, no account ids, no tokens, no paths that
identify a client. The private half lives in a separate private repo, driven by
`make private-push` and declared in `scripts/private-files.sh`.

## Documentation drift is this repo's recurring defect

Docs here go stale faster than anything else, and the reason is structural rather than a
lack of care. Most facts in the README are duplicated from code, and a global "review the
docs before committing" rule is too vague to act on, which is why it has already failed
here more than once.

Two mechanisms, and they split the work by whether a machine can check the claim.

### Mechanism one: tests, for anything comparable

Where a doc claim restates something in code, a test compares the two, so drift becomes a
failing test rather than a thing to remember. These already exist:

| Test | Compares |
| --- | --- |
| `test-install.sh` | the README's `ln -sfh` block against `scripts/links.sh`, as source→destination pairs |
| `test-doctor.sh` | the `Brewfile` against `doctor.sh`'s `REQUIRED` list, in both directions |
| `test-private-sync.sh` | that `doctor.sh` and `private-sync.sh` read the same private file map |
| `colors-check.sh` | Starship's declared colours against `docs/COLORS.md`, plus its total count |

**When you add a doc claim that restates code, add the comparison to a test.** When you
cannot, see mechanism two.

### Mechanism two: this lookup, for everything else

Before committing, find every file you touched in the left column and check the right one.
This is deliberately a lookup and not an instruction to re-read the README.

| If you changed | Check |
| --- | --- |
| `scripts/links.sh` | README *Repository layout & symlink map* table, and the `ln -sfh` block under *Symlink configs*. `test-install.sh` covers the second one only |
| `Brewfile` | README *CLI tools* and *Apps (casks)* tables, and `doctor.sh`'s `REQUIRED`. Note a formula whose binary has a different name needs the mapping in `test-doctor.sh` too |
| `Makefile` targets | README *Make targets* table |
| added or removed a test file | README *Tests* table |
| `fish/conf.d/` filenames or numbering | README *Fish load order* diagram and the *conf.d/ files* list |
| `fish/functions/` | README *functions/ directory* list |
| any colour, anywhere | `docs/COLORS.md` and `make colors-check` |
| `scripts/private-files.sh` | README *Machine-private config*, which lists what is in scope and what it is worth |
| the `gh repo create` hint printed by `private-sync.sh init` | the same command in the README's *Creating the remote is a manual step*. The README's copy carries the repo description, the script's is the short form, and they have to stay compatible |
| the README or `.gitignore` heredocs inside `private-sync.sh init` | the live copies in `~/.dotfiles-private`. `init` only writes them when the repo does not exist yet, so an existing clone keeps the old text: regenerate into a temp dir with `DOTFILES_PRIVATE=/tmp/x private-sync.sh init`, copy the file across, and commit it there too |
| `claude/settings.json` hooks, or any `claude/speak-*` file | README *Spoken Claude Code replies* |
| `ssh/config` include order | the rationale comment in the file itself, and the README's SSH section |
| an alias in `fish/conf.d/08-aliases.fish` | only if it is one of the few the README names as examples. The README does **not** enumerate aliases, and it should stay that way |

## Claims that cannot be kept true

Some numbers in the docs are point-in-time measurements, not invariants. Do not "correct"
them from a measurement taken inside an agent session: this environment inherits exported
variables from the launching shell, so a naive timing here is not what a real terminal
sees. This has already produced one wrong "fix" in this repo's history.

Currently marked as measured rather than guaranteed:

- the login shell timing in the README's *The reminder* section
- `brew_nudge`'s per-call cost, in the same paragraph

If you cannot verify a number the way it was originally measured, leave it and say so.
Prefer deleting an unmaintainable number over inventing a fresh one.

## Before committing

Run all three. They are fast and they are the repo's own contract:

```sh
make test          # the suite
make colors-check  # palette drift
make doctor        # the live environment
```

`make doctor` reads the real `$HOME`, so treat its output as information about this
machine, not as a verdict on the change.

## Never do these without asking

- run `install.sh` for real, change the default shell, or install, update or remove packages
- create the private repo's **remote**, or push to it. `make private-init` deliberately
  stops at a local repo, because publishing a host list cannot be undone
- rewrite git history, or force-push anything
- touch `~/.ssh` keys, the 1Password agent, or the global git config
