# 🛠️ Sergio’s .dotfiles — macOS Fish Shell Environment

This repository contains my personal macOS development environment configuration, with a focus on:

- 🐟 **Fish shell**
    - Clean setup with modular functions, aliases, color configuration, and a Starship prompt theme aligned to the
      terminal palette.
    - Modular configuration with 15 numbered conf.d files (00-99) for controlled load order.
    - Custom functions: `fish_greeting`, `banner_sergio`, `fish_user_key_bindings`.
- 🎨 **Custom banner**
    - Multi-line ASCII welcome with compact fallback and optional rainbow effect (`lolcat`).
    - **Banner mode** is configurable via the `BANNER_MODE` env var: `full` | `compact` | `auto`.
- 🧾 **Aliases**
    - Well-structured and documented with practical usage examples, autoloaded from `conf.d/08-aliases.fish`.
    - Includes smart aliases for modern tools: `l`/`ll` (eza), `v` (bat), `z` (zoxide), `tree` (eza --tree)...
- 🎯 **FZF (Fuzzy Finder)**
    - Comprehensive configuration with `fd` integration for fast file/directory search.
    - Responsive preview windows with `bat` (files) and `eza` (directories).
    - Colors synchronized with the `linked_data_dark_rainbow` palette.
    - Custom keybindings and 80% height layout with rounded borders.
- 🔐 **SSH**
    - Public/private split config, managed from `.dotfiles/ssh` and using 1Password SSH agent for secure key management.
- 🧠 **Git**
    - SSH-based commit signing (1Password agent) with `micro` as commit editor.
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
    - Includes a custom rainbow separator (`98-rainbow_separator.fish`) to visually divide command output from the next
      prompt.
    - All colors are optimized for pure black backgrounds as well as setups with subtle transparency and blurred effects, ensuring high contrast.
    - **📋 Full color palette documentation:** See [COLORS.md](COLORS.md) for the complete 27-color palette with hex/RGB values and semantic usage across all tools.
- 🔗 **Finicky**
    - Smart browser profile routing. Sets Chrome as the default browser and opens Google Meet links
      automatically in the **Secture** _(work)_ profile.
- 💾 **iTerm2 backup**
    - Full export of preferences (profiles, colors, fonts), easily restorable.
- 🤖 **Claude Code**
    - Custom statusline configuration with comprehensive git, system, and environment info.
    - Settings tracked in `.dotfiles/claude/` with custom `statusline.sh` script.

> These files are meant for personal use and backup. Feel free to explore or adapt.

---

## 🔧 Setup & Usage Guide (Restore on a new machine)

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
- **domt4/autoupdate** — keep Homebrew itself and formulae up to date
- **sst/tap** — custom tap (provides `opencode` CLI)

#### 🛠️ CLI tools
- **bat** — `cat` clone with syntax highlighting
- **btop** — modern system resource monitor
- **codex** — agentic coding CLI
- **eza** — improved `ls` with colors and icons
- **fd** — fast and user-friendly alternative to `find`
- **fish** — friendly interactive shell
- **fnm** — fast Node.js version manager
- **fzf** — fuzzy finder for the terminal
- **gemini-cli** — Google Gemini AI CLI
- **gh** — GitHub CLI tool
- **lolcat** — rainbow coloring for terminal output
- **micro** — lightweight terminal text editor
- **node** — JavaScript runtime
- **opencode** — lightweight open-source Claude-compatible CLI
- **pyenv** — manage multiple Python versions
- **starship** — fast and customizable prompt
- **zoxide** — smarter `cd` command with jump history

#### 💻 Apps (casks)
- **Docker Desktop** — container engine and UI
- **Finicky** — control which browser/profile opens links
- **Fira Code Nerd Font** — a developer-friendly font with ligatures and Nerd Font icons
- **Hammerspoon** — macOS automation tool with Lua scripting
- **IINA** — modern video player for macOS
- **iTerm2** — terminal emulator for macOS
- **Ice (jordanbaird-ice)** — menu bar manager for macOS

> 🔄️ You can enable automatic updates for Homebrew itself, formulas, and casks with:  
> `brew autoupdate start 86400 --upgrade --cleanup --immediate --ac-only`  
> (runs daily, cleans old versions, starts at every system login, only on AC power)

---

### 🔗 Symlink configs

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
mkdir -p ~/.claude
ln -sfh ~/.dotfiles/claude/settings.json ~/.claude/settings.json
ln -sfh ~/.dotfiles/claude/statusline.sh ~/.claude/statusline.sh
```

> ⚠️ **Note:** Symlinks overwrite existing files — backup before linking.

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
- `98-rainbow_separator.fish` — Rainbow command separator
- `99-banner.fish` — Custom welcome banner (last)

#### functions/ directory:
- `fish_greeting.fish` — Custom greeting message
- `banner_sergio.fish` — ASCII art banner generator
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

2. You **must create** `~/.ssh/config.private` manually:

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
   /Users/sergiosantiago/.dotfiles/iterm
   ```

4. For saving changes, set **"Save changes"** to: `When Quitting` (or optionally `Manually`)
5. Restart iTerm2 to apply all changes
