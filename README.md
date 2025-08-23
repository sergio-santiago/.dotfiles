# 🛠️ Sergio’s .dotfiles — macOS Fish Shell Environment

This repository contains my personal macOS development environment configuration, with a focus on:

- 🐟 **Fish shell**
    - Clean setup with modular functions, aliases, color configuration, and a Starship prompt theme aligned to the
      terminal palette.
- 🎨 **Custom banner**
    - Multi-line ASCII welcome with compact fallback and optional rainbow effect (`lolcat`).
    - **Banner mode** is configurable via the `BANNER_MODE` env var: `full` | `compact` | `auto`.
- 🧾 **Aliases**
    - Well-structured and documented with practical usage examples, autoloaded from `conf.d/06-aliases.fish`.
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
        - Starship (`palettes.linked_data_dark_rainbow` palette)
        - Fish (`fish_colors_linked_data_dark_rainbow.fish`)
        - Bat (`linked-data-dark-rainbow.tmTheme`)
    - Includes a custom rainbow separator (`rainbow_separator.fish`) to visually divide command output from the next
      prompt.
    - All colors are optimized for pure black backgrounds as well as setups with subtle transparency and blurred effects, ensuring high contrast.
- 🔗 **Finicky**
    - Smart browser profile routing. Sets Chrome as the default browser and opens Google Meet links
      automatically in the **Secture** _(work)_ profile.
- 💾 **iTerm2 backup**
    - Full export of preferences (profiles, colors, fonts), easily restorable.

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

#### 🛠️ CLI tools
- **bat** — `cat` clone with syntax highlighting
- **btop** — modern system resource monitor
- **eza** — improved `ls` with colors and icons
- **fd** — fast and user-friendly alternative to `find`
- **fish** — friendly interactive shell
- **fnm** — fast Node.js version manager
- **fzf** — fuzzy finder for the terminal
- **gemini-cli** — Google Gemini AI CLI
- **lolcat** — rainbow coloring for terminal output
- **micro** — lightweight terminal text editor
- **starship** — fast and customizable prompt
- **zoxide** — smarter `cd` command with jump history
- **pyenv** — manage multiple Python versions

#### 💻 Apps (casks)
- **Finicky** — control which browser/profile opens links
- **Fira Code Nerd Font** — a developer-friendly font with ligatures and Nerd Font icons
- **Hammerspoon** — macOS automation tool with Lua scripting
- **iTerm2** — terminal emulator for macOS

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
```

> ⚠️ **Note:** Symlinks overwrite existing files — backup before linking.

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
