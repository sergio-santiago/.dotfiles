# 🛠️ Sergio’s .dotfiles — macOS Fish Shell Environment

This repository contains my personal macOS development environment configuration, with a focus on:

- 🐟 **Fish shell**
    - Clean setup with modular functions, aliases, color configuration, and a Starship prompt theme aligned to the
      terminal palette.

- 🎨 **Custom banner**
    - Multi-line ASCII welcome with compact fallback and optional rainbow effect (`lolcat`).
    - **Banner mode** is configurable via the `BANNER_MODE` env var: `full` | `compact` | `auto`.
- 🧾 **Aliases**
    - Well-structured and documented with practical usage examples, autoloaded from `conf.d/aliases.fish`.
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
    - Custom `linked_data_dark_rainbow` Starship palette + matching Fish `colors_theme.fish` for consistent syntax
      highlighting, pager, and selection colors.
    - Includes a custom rainbow separator (`rainbow_separator.fish`) to visually divide command output from the next
      prompt.
    - All colors are optimized for a pure black background and high contrast.
- 🔗 **Finicky**
    - Smart browser profile routing. Sets Chrome as the default browser and opens Google Meet links
      automatically in the **Secture** profile.
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

### 📦 Install Dependencies

Your development environment is fully reproducible with [Homebrew](https://brew.sh) and a `Brewfile`.

#### 1. 🖥️ Install iTerm2 (terminal emulator for macOS)

- **Recommended**: download from the official website → [https://iterm2.com](https://iterm2.com)  
  👉 In this setup, iTerm2 is installed **manually** to benefit from its built-in auto-updates.

#### 2. ⚙️ Install all tools with Brewfile

Run the following command to install CLI tools and apps:

```bash
brew bundle --file ~/.dotfiles/Brewfile
```

This will install:

### 🛠️ CLI tools
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

### 💻 Apps (casks)
- **Finicky** — control which browser/profile opens links
- **Fira Code Nerd Font** — a developer-friendly font with ligatures and Nerd Font icons
- **Hammerspoon** — macOS automation tool with Lua scripting

> ℹ️ Homebrew automatically handles low-level dependencies (e.g. openssl, icu4c, etc.), so the Brewfile only contains the tools and apps you explicitly install.

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
ln -sfh ~/.dotfiles/git/gitconfig ~/.gitconfig

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

#### 💾 Notes

- This includes current default profile with custom color palette (matching `linked_data_dark_rainbow` and Fish theme)
  and font config
- Changes to iTerm2 will not be saved unless done manually or with **"When Quitting"** selected
- Back up this file again if you change iTerm2 preferences in the future

> `config.fish` contains:
>
> - `fnm env | source` to initialize fnm
> - `BANNER_MODE` (full | compact | auto) for banner control
> - `starship init fish | source` to initialize starship
> - `banner_sergio` function for custom banner
> - Aliases are automatically loaded from `conf.d/aliases.fish`
> - Syntax, pager, and selection colors are automatically loaded from `conf.d/colors_theme.fish`
