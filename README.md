# 🛠️ Sergio’s .dotfiles — macOS Fish Shell Environment

This repository contains my personal macOS development environment configuration, with a focus on:

- 🐟 **Fish shell**  
  Clean setup with modular functions, aliases, color configuration, and a Starship prompt theme aligned to the terminal palette.


- 🎨 **Custom banner**  
  Multi-line ASCII welcome with compact fallback and optional rainbow effect (`lolcat`).  
  **Banner mode** is configurable via the `BANNER_MODE` env var: `full` | `compact` | `auto`.


- 🧾 **Aliases**  
  Well-structured and documented with practical usage examples, autoloaded from `conf.d/aliases.fish`.


- 🔐 **SSH**  
  Public/private split config, managed from `.dotfiles/ssh` and using 1Password SSH agent for secure key management.


- 🧠 **Git**  
  SSH-based commit signing (1Password agent) with VSCode as commit editor.


- 🌈 **Color theme**
  - Custom `sergio_dark_rainbow` Starship palette + matching Fish `colors_theme.fish` for consistent syntax highlighting, pager, and selection colors.
  - Includes a custom rainbow separator (`rainbow_separator.fish`) to visually divide command output from the next prompt.
  - All colors are optimized for a pure black background and high contrast.


- 💾 **iTerm2 backup**  
  Full export of preferences (profiles, colors, fonts), easily restorable.

> These files are meant for personal use and backup. Feel free to explore or adapt.

---

## 🔧 Setup & Usage Guide

### 🚀 Restore on a new machine

```bash
git clone git@github.com:sergio-santiago/.dotfiles.git ~/.dotfiles
```

**Symlink configs:**

```bash
# SSH
mkdir -p ~/.ssh
ln -sf ~/.dotfiles/ssh/config ~/.ssh/config

# Fish
mkdir -p ~/.config/fish/conf.d ~/.config/fish/functions
ln -sf ~/.dotfiles/fish/config.fish ~/.config/fish/config.fish
ln -sf ~/.dotfiles/fish/conf.d/aliases.fish ~/.config/fish/conf.d/aliases.fish
ln -sf ~/.dotfiles/fish/conf.d/colors_theme.fish ~/.config/fish/conf.d/colors_theme.fish
ln -sf ~/.dotfiles/fish/conf.d/rainbow_separator.fish ~/.config/fish/conf.d/rainbow_separator.fish
ln -sf ~/.dotfiles/fish/functions/banner_sergio.fish ~/.config/fish/functions/banner_sergio.fish
ln -sf ~/.dotfiles/fish/functions/fish_greeting.fish ~/.config/fish/functions/fish_greeting.fish

# Starship
ln -sf ~/.dotfiles/starship/starship.toml ~/.config/starship.toml

# Git
ln -sf ~/.dotfiles/git/gitconfig ~/.gitconfig
```

> ⚠️ **Note:** Symlinks overwrite existing files — backup before linking.

---

### 🐟 Fish Shell Setup

1. Install iTerm2 (recommended terminal for macOS) — choose **one**:
   - **From official website:** [https://iterm2.com](https://iterm2.com)
   - **Using Homebrew:**
     ```bash
     brew install --cask iterm2
     ```
     
2. Install `fish` and set it as your default shell:

   ```bash
   brew install fish
   chsh -s /opt/homebrew/bin/fish
   ```

3. Install starship prompt:

   ```bash
   brew install starship
   ```

4. Install Nerd Font for prompt icons (e.g., Fira Code Nerd Font):

   ```bash
   brew install --cask font-fira-code-nerd-font
   ```

5. Install `fnm` for Node.js version management with fish:

   ```bash
   brew install fnm
   ```

6. For colorful banner output and separator:

   ```bash
   brew install lolcat
   ```

7. Install tools used in aliases:

   ```bash
   brew install lsd bat btop tree
   ```

> `config.fish` already contains:
>
> - `fnm env | source` to initialize fnm
> - `BANNER_MODE` (full | compact | auto) for banner control
> - `starship init fish | source` to initialize starship
> - `banner_sergio` function for custom banner
> - Aliases are automatically loaded from `conf.d/aliases.fish`
> - Syntax, pager, and selection colors are automatically loaded from `conf.d/colors_theme.fish`

### 🧩 Disable Starship in JetBrains IDEs Terminal

If custom Starship config renders incorrectly in the integrated terminal of JetBrains IDEs,
you can disable it by overriding the config path:

1. Go to **Preferences > Tools > Terminal**
2. Set the shell path to:

   ```bash
   env STARSHIP_CONFIG=/dev/null /opt/homebrew/bin/fish
    ```
This launches fish with an empty Starship config, disabling the prompt in WebStorm
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

To preserve the full appearance and behavior of iTerm2 environment (profiles, color schemes, font, etc.), the app preferences are exported and tracked here:

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

- This includes current default profile with custom color palette (matching `sergio_dark_rainbow` and Fish theme) and font config
- Changes to iTerm2 will not be saved unless done manually or with **"When Quitting"** selected
- Back up this file again if you change iTerm2 preferences in the future
