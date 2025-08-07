# 🛠️ Sergio’s .dotfiles — macOS Fish Shell Environment

This repository contains my personal macOS development environment configuration, with a focus on:

- 🐟 **Fish shell**  
  Clean setup with custom functions and a visually enhanced Starship prompt

- 🎨 **Custom banner**  
  Multi-line ASCII welcome with fallback support and optional rainbow effect (via `lolcat`)

- 🧾 **Aliases**  
  Well-structured and documented with practical usage examples

- 🔐 **SSH**  
  Public/private split config, using 1Password SSH agent for secure key management

- 🧠 **Git**  
  Opinionated configuration with SSH-based commit signing and commit edit with VSCode

- 🌈 **Color theme**  
  Truecolor support with pastel/rainbow-inspired palette optimized for dark terminals

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
