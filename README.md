# 🛠️ Sergio’s .dotfiles — macOS Fish Shell Environment

This repository contains my personal macOS development environment configuration, with a focus on:

- 🐟 **Fish shell**
    - Clean setup with modular functions, aliases, color configuration, and a Starship prompt theme aligned to the
      terminal palette.
    - Modular configuration with 12 numbered conf.d files (00-99) for controlled load order.
    - Custom functions: `fish_greeting`, `fish_user_key_bindings`.
    - Compact welcome banner with rainbow effect (`lolcat`) and fixed seed for consistent colors.
- 🧾 **Aliases**
    - Well-structured and documented with practical usage examples, autoloaded from `conf.d/08-aliases.fish`.
    - Includes smart aliases for modern tools: `l`/`ll` (eza), `v` (bat), `z` (zoxide), `tree` (eza --tree), `c`/`c-yolo` (claude)...
- 🎯 **FZF (Fuzzy Finder)**
    - Comprehensive configuration with `fd` integration for fast file/directory search.
    - Responsive preview windows with `bat` (files) and `eza` (directories).
    - Colors synchronized with the `linked_data_dark_rainbow` palette.
    - Custom keybindings and 80% height layout with rounded borders.
- 🔐 **SSH**
    - Public/private split config, managed from `.dotfiles/ssh` and using 1Password SSH agent for secure key management.
- 🧠 **Git**
    - SSH-based commit signing (1Password agent) with `micro` as commit editor.
    - **Directory-based identities** via `includeIf`: a base identity (`@secture.com`) with automatic
      email overrides for Tribbu (`~/Projects/tribbu/`) and personal (`~/Projects/personal/`) repos,
      all sharing a single signing key. See [Git identities](#-git-identities-multi-account).
- ✏️ **Micro editor**
    - Lightweight terminal-based editor with custom settings and a matching `linked-data-dark-rainbow` color scheme for
      a consistent look with Fish and Starship.
    - Custom theme with true color, icon-based statusline, consistent syntax highlighting, 4-space indentation... and
      more.
- 🌈 **Color theme**
    - Custom `linked_data_dark_rainbow` theme for consistent syntax highlighting, pager, and selection colors.
      Implemented across:
        - Starship (`palettes.linked_data_dark_rainbow` palette, three-line prompt with powerline segments)
        - Fish (`09-theme.fish`)
        - Bat (`linked-data-dark-rainbow.tmTheme`)
        - Micro editor (`linked-data-dark-rainbow.micro`)
        - FZF (`05-fzf.fish` with synchronized color palette)
        - iTerm2 (ANSI colors + UI elements)
    - Includes a custom rainbow separator (`99-rainbow_separator.fish`) to visually divide command output from the next
      prompt.
    - All colors are optimized for pure black backgrounds as well as setups with subtle transparency and blurred effects, ensuring high contrast.
    - **📋 Full color palette documentation:** See [COLORS.md](docs/COLORS.md) for the complete 28-color palette with hex/RGB values and semantic usage across all tools.
- 🔗 **Finicky**
    - Smart browser routing (config in TypeScript). Sets Chrome as the default browser, opens Google Meet
      links automatically in the **Tribbu** Chrome profile, and sends Zoom links straight to the native Zoom app.
- 💾 **iTerm2 backup**
    - Full export of preferences (profiles, colors, fonts), easily restorable.
- 🤖 **Claude Code**
    - Custom statusline configuration with comprehensive git, system, and environment info.
    - Usage quota bar with 5-hour utilization percentage, gradient bar, and reset countdown.
    - Granular permission rules: read-only git/gh commands auto-allowed, mutations require confirmation.
    - Tuned for Opus 5: auto mode, `high` effort, Spanish responses, voice dictation, fullscreen TUI, and no AI attribution in commits/PRs.
    - Global instructions (`CLAUDE.md`), behaviour rules (`rules/`), hooks, skills and settings all tracked in
      `.dotfiles/claude/`, with a custom `statusline.sh`.
    - 🔊 **Spoken replies**: `/speak summary` reads the last answer out loud through local neural TTS —
      offline, free, one switch per terminal. See [Spoken Claude Code replies](#-spoken-claude-code-replies).
- 📊 **btop**
    - Modern system resource monitor with custom configuration.
    - Truecolor support, braille graphs, rounded corners, and transparent background.
    - Fast 100ms refresh rate for real-time monitoring.
- 🐙 **GitHub CLI (gh)**
    - GitHub command-line tool configured with SSH protocol.

> These files are meant for personal use and backup. Feel free to explore or adapt.

---

## 📑 Table of Contents

- [🗺️ Architecture](#️-architecture)
    - [📦 Repository layout & symlink map](#repository-layout--symlink-map)
    - [⚙️ Fish load order](#fish-load-order-confd)
    - [🎨 Color theme propagation](#color-theme-propagation)
    - [🧠 Git identity resolution](#git-identity-resolution)
- [🔧 Setup & Usage Guide](#-setup--usage-guide-restore-on-a-new-machine)
    - [⚡ Quick start](#-quick-start)
    - [🧬 Clone repository](#-clone-repository)
    - [📦 Install dependencies with Brewfile](#-install-dependencies-with-brewfile)
    - [🔗 Symlink configs](#-symlink-configs)
    - [🐟 Set fish as the default shell](#-set-fish-as-the-default-shell)
    - [🧠 Git identities (multi-account)](#-git-identities-multi-account)
    - [🪄 Manual steps (not automatable)](#-manual-steps-not-automatable)
    - [🐟 Fish Shell Configuration Structure](#-fish-shell-configuration-structure)
    - [🧩 Disable Starship in JetBrains IDEs](#-disable-starship-in-jetbrains-ides-terminal)
    - [🔐 SSH Configuration (Public/Private Split)](#-ssh-configuration-publicprivate-split)
    - [💻 iTerm2 Configuration (Theme, Colors & Profiles)](#-iterm2-configuration-theme-colors--profiles)
    - [🔊 Spoken Claude Code replies](#-spoken-claude-code-replies)
- [📋 Color palette reference](docs/COLORS.md)

---

## 🗺️ Architecture

### Repository layout & symlink map

Configs live in this repo and are symlinked into their expected locations (`make link`).
`git/config-personal` and `git/config-tribbu` are **not** symlinked — they are pulled in by
`git/config` via absolute `includeIf` paths.

```mermaid
flowchart LR
    subgraph repo["📦 ~/.dotfiles"]
        fish["fish/"]
        starship["starship/starship.toml"]
        gitc["git/config"]
        ssh["ssh/config"]
        micro["micro/"]
        bat["bat/themes"]
        claude["claude/"]
        misc["btop · gh · finicky"]
        scripts["scripts/<br/>install · doctor · speak"]
        docs["docs/COLORS.md"]
    end
    subgraph home["🏠 $HOME"]
        cfgfish["~/.config/fish/"]
        cfgstar["~/.config/starship.toml"]
        cfggit["~/.config/git/config"]
        sshcfg["~/.ssh/config"]
        cfgmisc["~/.config/{micro,bat,btop,gh,finicky}/"]
        dotclaude["~/.claude/"]
        localbin["~/.local/bin/"]
    end
    fish --> cfgfish
    starship --> cfgstar
    gitc --> cfggit
    ssh --> sshcfg
    micro --> cfgmisc
    bat --> cfgmisc
    misc --> cfgmisc
    claude --> dotclaude
    scripts --> localbin
```

`scripts/` and `docs/` hold tooling and reference rather than configuration, so nothing in them is
linked except `bin/speak`, which needs to be on your `PATH`: `install.sh` and `doctor.sh` run behind
`make link` and `make doctor`, `speak-setup.sh` behind `make speak-setup`, and `docs/COLORS.md` is the
source of truth for the palette. `links.sh` holds the symlink map itself, sourced by both `install.sh`
and `doctor.sh` so that what gets created and what gets verified cannot drift apart.

### Fish load order (`conf.d/`)

Fragments are sourced in lexical order. Environment first, then version managers and tools,
then appearance, and finally a cosmetic separator hook.

```mermaid
flowchart TD
    subgraph env["⚙️ Environment (00–02)"]
        x["00 · XDG redirects"] --> b["01 · ~/.local/bin"] --> h["02 · Homebrew"]
    end
    subgraph ver["📦 Version managers (03–04)"]
        py["03 · pyenv"] --> fnm["04 · fnm"]
    end
    subgraph tools["🛠️ Interactive tools (05–08)"]
        fzf["05 · fzf"] --> batf["06 · bat"] --> zo["07 · zoxide"] --> al["08 · aliases"]
    end
    subgraph look["🎨 Appearance (09–99)"]
        th["09 · theme"] --> sh["10 · starship"] --> rb["99 · rainbow separator"]
    end
    env --> ver --> tools --> look
```

### Color theme propagation

`docs/COLORS.md` is the single source of truth for the `linked_data_dark_rainbow` palette,
replicated by hand into each tool's native format. `make colors-check` lints for drift.

```mermaid
flowchart LR
    src["📋 docs/COLORS.md<br/>(source of truth · 28 colors)"]
    src --> starship["Starship<br/>palette block"]
    src --> bat["Bat<br/>tmTheme"]
    src --> micro["Micro<br/>color-link"]
    src --> fish["Fish<br/>fish_color_*"]
    src --> fzf["FZF / zoxide<br/>256-color"]
    src --> claude["Claude<br/>statusline RGB"]
    src --> iterm["iTerm2<br/>ANSI"]
```

### Git identity resolution

A commit's author email is chosen by where the repository lives; the name and signing key
are always inherited from the base identity.

```mermaid
flowchart TD
    start(["git commit in repo X"]) --> base["Base identity<br/>name: Sergio Santiago<br/>email: @secture.com<br/>signingkey: ssh-ed25519 …"]
    base --> q{"repo path?"}
    q -->|"~/Projects/tribbu/*"| t["config-tribbu<br/>→ @tribbuapp.com"]
    q -->|"~/Projects/personal/*"| p["config-personal<br/>→ @gmail.com"]
    q -->|"anywhere else"| d["keeps @secture.com"]
    t --> sign["Sign with 1Password SSH key"]
    p --> sign
    d --> sign
```

---

## 🔧 Setup & Usage Guide (Restore on a new machine)

### ⚡ Quick start

```bash
git clone git@github.com:sergio-santiago/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make install          # installs Brewfile packages + symlinks every config
make default-shell    # set fish as the default login shell
make doctor           # verify tools, symlinks and environment
```

Then finish the [manual steps](#-manual-steps-not-automatable) (1Password SSH agent, iTerm2 prefs).
The sections below explain each piece in detail.

#### Make targets

| Target | What it does |
|--------|--------------|
| `make install` | `brew` + `link` — full setup on a new machine |
| `make brew` | Install all packages/apps from the `Brewfile` |
| `make link` | Symlink configs into `~/.config`, `~/.claude`, `~/.ssh` (idempotent, backs up existing files) |
| `make default-shell` | Add Homebrew fish to `/etc/shells` and `chsh` to it |
| `make doctor` | Verify required tools, symlinks and environment are healthy |
| `make colors-check` | Lint the `linked_data_dark_rainbow` palette for drift |
| `make speak-setup` | Install Piper + Spanish voices so Claude Code can speak its replies |

> The installer is **idempotent** and **non-destructive**: re-running it is safe, and any existing
> file it would overwrite is first moved to `~/.dotfiles-backup/<timestamp>/`.

---

### 🧬 Clone repository

```bash
git clone git@github.com:sergio-santiago/.dotfiles.git ~/.dotfiles
```

---

### 📦 Install dependencies with Brewfile

Development environment is reproducible with [Homebrew](https://brew.sh) and a `Brewfile`.  
Run the following command to install CLI tools and apps:

```bash
brew bundle --file ~/.dotfiles/Brewfile
```

This will install:

#### 🔖 Taps
- **hamed-elfayome/claude-usage** — Claude API usage tracking
- **hashicorp/tap** — HashiCorp tools (provides `terraform`)

#### 🛠️ CLI tools
- **bat** — `cat` clone with syntax highlighting
- **btop** — modern system resource monitor
- **eza** — improved `ls` with colors and icons
- **fd** — fast and user-friendly alternative to `find`
- **fish** — friendly interactive shell
- **fnm** — fast Node.js version manager
- **fzf** — fuzzy finder for the terminal
- **gh** — GitHub CLI tool
- **jq** — JSON processor for command line
- **lolcat** — rainbow coloring for terminal output
- **micro** — lightweight terminal text editor
- **mole** — deep clean and optimize macOS
- **node** — JavaScript runtime
- **poppler** — PDF rendering library
- **pyenv** — manage multiple Python versions
- **starship** — fast and customizable prompt
- **terraform** — infrastructure as code tool
- **zoxide** — smarter `cd` command with jump history

#### 💻 Apps (casks)
- **Claude Usage Tracker** — Claude API usage dashboard
- **Finicky** — control which browser/profile opens links
- **Fira Code Nerd Font** — a developer-friendly font with ligatures and Nerd Font icons
- **Google Cloud CLI** — `gcloud` command-line interface
- **iTerm2** — terminal emulator for macOS
- **Thaw** — menu bar manager for macOS

> 🔄️ Keeping Homebrew current is a deliberate step, not a background job: run `brew-maintenance`
> (or `bm`), the fish function in `conf.d/08-aliases.fish` that chains `update`, `upgrade`,
> `cleanup`, `autoremove` and `doctor`.
>
> Formulae from third-party taps need `brew trust <tap>` before Homebrew will manage them — see the
> [manual steps](#-manual-steps-not-automatable).

---

### 🔗 Symlink configs

The recommended way is the installer, which creates every symlink, backs up anything it would
overwrite, creates `~/.ssh/config.private`, and rebuilds the bat cache:

```bash
make link
```

It wires the repo into `$HOME` like this:

| Source (`~/.dotfiles/…`) | Destination |
|--------------------------|-------------|
| `ssh/config` | `~/.ssh/config` |
| `fish/{conf.d,functions,config.fish}` | `~/.config/fish/…` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `git/config` | `~/.config/git/config` |
| `micro/{settings.json,colorschemes/…}` | `~/.config/micro/…` |
| `bat/themes` | `~/.config/bat/themes` |
| `finicky/finicky.ts` | `~/.config/finicky/finicky.ts` |
| `btop/btop.conf` | `~/.config/btop/btop.conf` |
| `gh/config.yml` | `~/.config/gh/config.yml` |
| `claude/{CLAUDE.md,settings.json,statusline.sh}` | `~/.claude/…` |
| `claude/{rules,hooks,skills/speak}` | `~/.claude/…` |
| `claude/{speak-lib.sh,speak-clean.py}` | `~/.claude/…` |
| `scripts/bin/speak` | `~/.local/bin/speak` |

<details>
<summary>Prefer to link manually? (click to expand)</summary>

```bash
# SSH
mkdir -p ~/.ssh
ln -sfh ~/.dotfiles/ssh/config ~/.ssh/config

# Fish
mkdir -p ~/.config/fish
ln -sfh ~/.dotfiles/fish/conf.d ~/.config/fish/conf.d
ln -sfh ~/.dotfiles/fish/functions ~/.config/fish/functions
ln -sfh ~/.dotfiles/fish/config.fish ~/.config/fish/config.fish

# Starship
ln -sfh ~/.dotfiles/starship/starship.toml ~/.config/starship.toml

# Git
mkdir -p ~/.config/git
ln -sfh ~/.dotfiles/git/config ~/.config/git/config

# Micro
mkdir -p ~/.config/micro/colorschemes
ln -sfh ~/.dotfiles/micro/settings.json ~/.config/micro/settings.json
ln -sfh ~/.dotfiles/micro/colorschemes/linked-data-dark-rainbow.micro ~/.config/micro/colorschemes/linked-data-dark-rainbow.micro

# Bat
mkdir -p ~/.config/bat
ln -sfh ~/.dotfiles/bat/themes ~/.config/bat/themes
bat cache --build

# Finicky
mkdir -p ~/.config/finicky
ln -sfh ~/.dotfiles/finicky/finicky.ts ~/.config/finicky/finicky.ts

# Claude Code
mkdir -p ~/.claude ~/.local/bin
ln -sfh ~/.dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sfh ~/.dotfiles/claude/settings.json ~/.claude/settings.json
ln -sfh ~/.dotfiles/claude/statusline.sh ~/.claude/statusline.sh
ln -sfh ~/.dotfiles/claude/rules ~/.claude/rules
ln -sfh ~/.dotfiles/claude/hooks ~/.claude/hooks
mkdir -p ~/.claude/skills
ln -sfh ~/.dotfiles/claude/skills/speak ~/.claude/skills/speak
ln -sfh ~/.dotfiles/claude/speak-lib.sh ~/.claude/speak-lib.sh
ln -sfh ~/.dotfiles/claude/speak-clean.py ~/.claude/speak-clean.py
ln -sfh ~/.dotfiles/scripts/bin/speak ~/.local/bin/speak

# btop
mkdir -p ~/.config/btop
ln -sfh ~/.dotfiles/btop/btop.conf ~/.config/btop/btop.conf

# GitHub CLI (gh)
mkdir -p ~/.config/gh
ln -sfh ~/.dotfiles/gh/config.yml ~/.config/gh/config.yml
```

> ⚠️ **Note:** Manual symlinks overwrite existing files with no backup — `make link` is safer.

</details>

---

### 🐟 Set fish as the default shell

```bash
make default-shell        # adds fish to /etc/shells and runs chsh
```

Or manually:

```bash
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish
```

---

### 🧠 Git identities (multi-account)

`git/config` defines a base identity and overrides only the **email** per directory, while
`user.name` and the SSH `signingkey` are inherited everywhere (one verified key for all accounts):

| Repo location | Identity file | Email |
|---------------|---------------|-------|
| anywhere (default) | `git/config` | `sergio@secture.com` |
| `~/Projects/tribbu/…` | `git/config-tribbu` | `sergiosantiago@tribbuapp.com` |
| `~/Projects/personal/…` | `git/config-personal` | `@gmail.com` |

The overrides are pulled in via `includeIf "gitdir:…"` using absolute paths, so they work without
being symlinked. To use them, just clone repos under the matching directory:

```bash
git -C ~/Projects/tribbu/some-repo config user.email   # → sergiosantiago@tribbuapp.com
```

GitHub HTTPS credentials are delegated to `gh auth git-credential`, so run `gh auth login` once.

---

### 🪄 Manual steps (not automatable)

A few things can't be symlinked and must be done by hand on a new machine:

1. **Enable the 1Password SSH agent** (required for SSH auth **and** commit signing):
   1Password → **Settings → Developer → Use the SSH agent**. Commit signing uses
   `op-ssh-sign`, already configured in `git/config`.
2. **Load iTerm2 preferences** — see [iTerm2 Configuration](#-iterm2-configuration-theme-colors--profiles) below.
3. **Create your private SSH hosts** in `~/.ssh/config.private` (the installer creates an empty
   `0600` file for you) — see [SSH Configuration](#-ssh-configuration-publicprivate-split) below.
4. **Install the Claude Code Slack plugin.** `claude/settings.json` enables
   `slack@claude-plugins-official`, but the plugin itself is cached under `~/.claude/plugins/` and is
   not part of this repo. Run `/plugin` in Claude Code to install it, then authenticate.
5. **Add the Context7 MCP server.** `claude/rules/context7.md` instructs Claude to fetch library docs
   through Context7, and that rule *is* symlinked — so without the server a new machine gets an
   instruction pointing at a tool that isn't there. MCP servers live in `~/.claude.json`, outside the
   repo: add it with `claude mcp add`.
6. **Trust the third-party taps.** Homebrew refuses to load formulae from an untrusted tap, so
   `terraform` (from `hashicorp/tap`) and `claude-usage-tracker` (from `hamed-elfayome/claude-usage`)
   need `brew trust hashicorp/tap` and `brew trust hamed-elfayome/claude-usage` before
   `brew bundle` can install them.

---

### 🐟 Fish Shell Configuration Structure

The Fish shell configuration is fully modular and follows a numbered loading order:

#### conf.d/ files (autoloaded in order):
- `00-xdg_redirects.fish` — XDG base directories
- `01-local-bin.fish` — Local user binaries PATH
- `02-homebrew.fish` — Homebrew environment
- `03-pyenv.fish` — Python version management
- `04-fnm.fish` — Node.js version management
- `05-fzf.fish` — Fuzzy finder with fd, bat, eza integration
- `06-bat.fish` — Bat (cat replacement) configuration
- `07-zoxide.fish` — Smart directory jumper
- `08-aliases.fish` — Command aliases and helper functions
- `09-theme.fish` — linked_data_dark_rainbow color theme
- `10-starship.fish` — Starship prompt initialization
- `99-rainbow_separator.fish` — Rainbow command separator

#### functions/ directory:
- `fish_greeting.fish` — Compact welcome banner with lolcat rainbow
- `fish_user_key_bindings.fish` — Custom key bindings

---

### 🧩 Disable Starship in JetBrains IDEs Terminal

If custom Starship config renders incorrectly in the integrated terminal of JetBrains IDEs,
you can disable it by overriding the config path:

1. Go to **Preferences > Tools > Terminal**
2. Set the shell path to:

   ```bash
   env STARSHIP_CONFIG=/dev/null /opt/homebrew/bin/fish
    ```

This launches fish with an empty Starship config, disabling the prompt in JetBrains IDE
without affecting your normal terminal.

---

### 🔐 SSH Configuration (Public/Private Split)

To keep personal hosts out of version control:

1. The tracked `ssh/config` contains:

   ```ssh
   Include ~/.dotfiles/ssh/config.public
   Include ~/.ssh/config.private
   ```

2. `~/.ssh/config.private` holds your private/machine-specific hosts. `make link` creates it
   automatically as an empty `0600` file; to create it by hand instead:

   ```bash
   touch ~/.ssh/config.private
   chmod 600 ~/.ssh/config.private
   ```

3. Put your private or machine-specific SSH hosts there (e.g., staging, personal VPS, etc.)

---

### 💻 iTerm2 Configuration (Theme, Colors & Profiles)

To preserve the full appearance and behavior of iTerm2 environment (profiles, color schemes, font, etc.), the app
preferences are exported and tracked here:

```bash
~/.dotfiles/iterm/com.googlecode.iterm2.plist
```

✅ **To load this config on a new Mac:**

1. Open **iTerm2 > Settings > General > Preferences**
2. Enable: ✔️ `Load preferences from a custom folder or URL`
3. Set the folder path to:

   ```bash
   ~/.dotfiles/iterm
   ```

4. For saving changes, set **"Save changes"** to: `When Quitting` (or optionally `Manually`)
5. Restart iTerm2 to apply all changes

---
### 🔊 Spoken Claude Code replies

Dictating prompts is only half of a hands-free loop — this reads the answers back, out loud, through
**[Piper](https://github.com/OHF-Voice/piper1-gpl)**: a neural TTS engine that runs on the machine.
Offline, free, unlimited, no API key.

```bash
make speak-setup     # one-off: ~130 MB of voices + ~170 MB of venv, outside the repo
/speak on            # arm this console
```

**Nothing is ever read automatically.** When a console is on, each reply is cleaned and kept ready,
and the two commands appear under its spoken block. You skim the answer and decide whether it is
worth hearing — no audio you did not ask for, and no deciding in advance what "reading" should mean.

#### One switch per console

With several sessions open, a global switch is unusable: one console reading aloud while you dictate
into another means the mic picks up the synthetic voice and your prompt comes out garbled. So each
terminal tab decides for itself, and the status line shows which:

A 󰕾 appears in the status line while a console is on — replies prepared, commands offered. Off shows
nothing at all: the indicator is there to flag the exception, and off is the rule.

Off by default in every new console. The switch is keyed on the iTerm2 pane UUID, so restarting
`claude` in the same tab keeps that tab's setting.

#### Commands

`/speak` from the Claude Code prompt, or `speak` from a terminal — same thing. It is a plain
executable rather than a fish function precisely so `! speak …` works from inside Claude Code, where
`!` runs under bash. Both forms read aloud immediately; `! speak summary` also puts the command's own
confirmation on screen instead of a line written by Claude.

| Command | What it does |
|---------|--------------|
| `/speak` | Toggle this console |
| `/speak on` / `/speak off` | Set explicitly (`off` also discards what was saved) |
| `/speak summary` | Read the last reply's summary out loud |
| `/speak full` | Read the whole last reply out loud |
| `/speak stop` | Shut up right now, mid-sentence |
| `/speak test` | Check that audio works at all |

The skill runs `` !`speak $ARGUMENTS` `` *before* the prompt reaches Claude, so the action happens
immediately and only a one-line confirmation comes back. `disable-model-invocation: true` keeps it
user-only — Claude cannot decide to start talking on its own.

> **Not named `voice`**: Claude Code's built-in `/voice` is dictation — it *listens*. This is the
> opposite direction, and reusing the word for both would be a coin flip every time.

Voice, speed and how much `full` will read are global taste, hand-edited in `~/.claude/speak.conf`:

```ini
voice=es_ES-davefx-medium     # or es_ES-sharvard-medium; see ~/.local/share/piper/voices
speed=1.0                     # <1 faster, >1 slower
max_chars=11600               # optional; how much of a reply `full` will read
```

The file does not exist until you create it — the defaults above are the built-in ones. `speed` and
`max_chars` are validated before use, so a typo falls back to the default instead of quietly breaking
the hook.

#### Summary or the whole reply

Both are prepared for every reply, and both strip code, tables, links, paths and markup — whatever a
voice cannot convey. The difference is length:

- **`summary`** is a closing line Claude writes *to be heard*, about twenty seconds. It exists because
  a reply adapted from prose never sounds as good as one written for the ear.
- **`full`** is the entire reply, cleaned. Capped at ten minutes of audio (11 600 chars — the default
  voice reads 19.4 chars/s, measured) so a runaway reply cannot hold the speaker hostage.

In `full`, inline paths become the name a person would say (`claude/speak-lib.sh` → "speak lib")
rather than being deleted, which would leave sentences dangling mid-clause.

#### Nothing accumulates

Each console keeps at most one saved reply, overwritten every turn, and `speak off` deletes it.
Files left behind by consoles you closed are pruned after a week.

#### Cutting a reply off mid-sentence

Claude Code keybindings only map to its own internal actions, so a dedicated hotkey is not possible.
Three things work: **sending the next message** (the prompt hook kills playback first, so answering
back silences it), **`/speak stop`**, and **`/speak off`** for good. All three are scoped to the
console you are in: typing here never cuts off what another pane is saying.

#### How it works

Three hooks in `claude/settings.json`, all no-ops in consoles that are off. Every piece resolves state
through one shared helper (`claude/speak-lib.sh`), so the indicator can never disagree with reality:

```mermaid
flowchart LR
    lib["speak-lib.sh<br/>state · config · playback"]
    prompt["UserPromptSubmit"] --> vp["speak-prompt.sh<br/>asks for a #60;speak#62; line"]
    disp["MessageDisplay"] --> sd["speak-display.sh<br/>󰕾 instead of raw tags"]
    stop["Stop"] --> sp["speak-reply.sh<br/>cleans · saves"]
    sp --> clean["speak-clean.py"]
    cmd["speak summary | full"] --> piper["Piper (local)"] --> af["afplay"]
    lib -.-> vp
    lib -.-> sd
    lib -.-> sp
    lib -.-> sl["statusline.sh<br/>󰕾"]
    lib -.-> cmd
```

- **`speak-prompt.sh`** asks Claude for the `<speak>` line, and stops playback — sending a message
  means you are done listening. Because the instruction lives in a hook and not in `CLAUDE.md`, it
  vanishes the moment you run `speak off`. It bails out early on a prompt that *is* a `speak` command,
  **before** silencing anything — a turn asking for a reading must not cancel the one its own command
  just started. That order matters; the two lines are commented in the hook for a reason.
- **`speak-display.sh`** rewrites the raw tags on screen into a grey 󰕾 with grey italic text, and
  tucks the two commands underneath. `MessageDisplay` is display-only, so the transcript keeps the
  real tags — which is what the Stop hook reads. Text arrives in `delta` chunks, so each tag is
  rewritten independently rather than as a pair: a block split mid-stream still renders. The opening
  tag only matches at the start of a line, so prose mentioning the literal tag is left alone.
- **`speak-reply.sh`** cleans the reply via **`speak-clean.py`** and saves both versions. It prints
  nothing, plays nothing and never touches Piper.
- **`speak`** does the reading itself, the moment you ask. Synthesis is detached, so nothing waits on
  audio: the command returns immediately and Piper keeps going.

Playback is identified by the temp file it was handed, console id included, so `speak stop` in one
pane cannot silence another. Starting a *new* reading does stop every other one — there is only one
pair of speakers.

The cleaning lives in its own Python file rather than a heredoc inside the hook: embedded Python
cannot be compiled, linted or run on its own, and turning prose into speech is fiddly enough to be
worth exercising directly against real payloads.

Synthesis takes about a second per sentence. `make doctor` reports whether Piper, the models, the
Python the cleaner needs and the per-console switches are all in place.
