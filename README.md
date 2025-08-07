# 🛠️ Sergio’s .dotfiles — macOS Fish Shell Environment

This repository contains my personal macOS development environment configuration, with a focus on:

- 🐟 **Fish shell**  
  Clean and minimal setup with custom functions and a visually enhanced Starship prompt

- 🎨 **Custom banner**  
  Multi-line ASCII welcome message with fallback support and optional rainbow effect (`lolcat`)

- 🧾 **Aliases**  
  Well-structured and documented with practical usage examples

- 🔐 **SSH**  
  Split configuration for public and private hosts, with secure key management via 1Password SSH agent

- 🧠 **Git**  
  Clean and secure setup using SSH-based commit signing, with VSCode as the default commit editor

- 🌈 **Color theme**  
  Truecolor-friendly palette (pastel + rainbow inspired), optimized for dark terminal environments

- 💾 **iTerm2 backup**  
  Full export of iTerm2 preferences, including a custom color scheme and fonts, easily restorable

> These files are meant for personal use and backup. Feel free to explore or adapt.

## 🔧 Setup & Usage Guide

This section explains how to restore the configuration, link files safely, and manage sensitive parts like SSH hosts.

---

### 🚀 Restore on a new machine

1. Clone this repository:

   ```bash
   git clone git@github.com:sergio-santiago/.dotfiles.git ~/.dotfiles
   ```

2. Create symlinks to your real config files:

   ```bash
   # SSH
   mkdir -p ~/.ssh
   ln -sf ~/.dotfiles/ssh/config ~/.ssh/config

   # Fish
   mkdir -p ~/.config/fish/conf.d ~/.config/fish/functions
   ln -sf ~/.dotfiles/fish/config.fish ~/.config/fish/config.fish
   ln -sf ~/.dotfiles/fish/conf.d/aliases.fish ~/.config/fish/conf.d/aliases.fish
   ln -sf ~/.dotfiles/fish/functions/banner_sergio.fish ~/.config/fish/functions/banner_sergio.fish
   ln -sf ~/.dotfiles/fish/functions/fish_greeting.fish ~/.config/fish/functions/fish_greeting.fish

   # Starship
   ln -sf ~/.dotfiles/starship/starship.toml ~/.config/starship.toml

   # Git
   ln -sf ~/.dotfiles/git/gitconfig ~/.gitconfig
   ```

   > ⚠️ **Warning:** This will overwrite existing files. Back up any current config before linking.
   > For example, if you have ~/.ssh/config already, symlinking will replace it.

---

### 🐟 Fish Shell Setup

1. Install `fish` and set it as your default shell:

   ```bash
   brew install fish
   chsh -s /opt/homebrew/bin/fish
   ```

2. Install starship prompt:

   ```bash
   brew install starship
   ```

3. Install Nerd Font for prompt icons (e.g., Fira Code Nerd Font) and use it in your terminal:

   ```bash
   fisher install oh-my-fish/theme-bobthefish
   ```

4. Install `fnm` for Node.js version management with fish:

   ```bash
   brew install fnm
   ```

5. Optional: for colorful banner output:

   ```bash
   brew install lolcat
   ```

6. Install tools used in aliases:

   ```bash
   brew install lsd bat btop tree
   ```

> `config.fish` already contains:
>
> - `fnm env | source` to initialize fnm
> - `starship init fish | source` to initialize starship
> - `banner_sergio` function for custom banner
> - Aliases are automatically loaded from `conf.d/aliases.fish`

### 🧩 Disable Starship in WebStorm Terminal

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

---

#### 💾 Notes

- This includes current default profile with custom color palette and font
- Changes to iTerm2 will not be saved unless done manually or with **"When Quitting"** selected
- Backup this file again if you change iTerm2 preferences in the future
---

### 📦 Notes

- Aliases are defined in `fish/conf.d/aliases.fish`, with descriptions and usage examples
- Banner logic is in `fish/functions/banner_sergio.fish`, adapts to terminal width
- Git config includes SSH key signing via 1Password and VSCode as the default editor for commits
- `~/.ssh/config` includes both public and private SSH configs via `Include`

---

### 🧪 Safety Notes

- Symlinks may overwrite files silently (`ln -sf`)
- Always inspect your real config before linking
- Sensitive files like `config.private`, keys or secrets are excluded via `.gitignore`
