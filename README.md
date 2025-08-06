# 🛠️ Sergio’s dotfiles — macOS Fish Shell Environment

This repository contains my personal macOS development environment configuration, focused on:

- 🐟 Fish shell setup with clean config and plugin management via Fisher
- 🧾 Well-documented aliases with usage examples
- 🎨 Custom ASCII banner with color and terminal width fallback
- 🔐 SSH config using 1Password SSH agent
- 🧠 Git config with SSH commit signing and VSCode integration

> These files are meant for personal use and backup. Feel free to explore or adapt.

## 🔧 Setup & Usage Guide

This section explains how to restore the configuration, link files safely, and manage sensitive parts like SSH hosts.

---

### 🚀 Restore on a new machine

1. Clone this repository:

   ```bash
   git clone https://github.com/your-username/dotfiles.git ~/dotfiles
   ```

2. Create symlinks to your real config files:

   ```bash
   # SSH
   mkdir -p ~/.ssh
   ln -sf ~/dotfiles/ssh/config ~/.ssh/config

   # Fish
   mkdir -p ~/.config/fish/conf.d ~/.config/fish/functions
   ln -sf ~/dotfiles/fish/config.fish ~/.config/fish/config.fish
   ln -sf ~/dotfiles/fish/conf.d/aliases.fish ~/.config/fish/conf.d/aliases.fish
   ln -sf ~/dotfiles/fish/functions/banner_sergio.fish ~/.config/fish/functions/banner_sergio.fish

   # Git
   ln -sf ~/dotfiles/git/gitconfig ~/.gitconfig
   ```

   > ⚠️ **Warning:** This will overwrite existing files. Back up any current config before linking.
   > For example, if you have ~/.ssh/config already, symlinking will replace it.

---

### 🐟 Fish Shell Setup

1. Install `fish` and set it as your default shell (optional):

   ```bash
   brew install fish
   chsh -s /opt/homebrew/bin/fish
   ```

2. Install Fisher (plugin manager):

   ```bash
   curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher
   ```

3. Install required plugins:

   ```bash
   fisher install oh-my-fish/theme-bobthefish
   ```

4. Install a Nerd Font (e.g. [FiraCode Nerd Font](https://www.nerdfonts.com/font-downloads)) and use it in your terminal.

5. Install `fnm` for Node.js version management:

   ```bash
   brew install fnm
   ```

6. Optional: for colorful banner output:

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
> - `set -g theme_nerd_fonts yes` for Nerd Font support
> - `banner_sergio` function for custom banner
> - Aliases are automatically loaded from `conf.d/aliases.fish`

---

### 🔐 SSH Configuration (Public/Private Split)

To keep personal hosts out of version control:

1. The tracked `ssh/config` contains:

   ```ssh
   Include ~/dotfiles/ssh/config.public
   Include ~/.ssh/config.private
   ```

2. You **must create** `~/.ssh/config.private` manually:

   ```bash
   touch ~/.ssh/config.private
   chmod 600 ~/.ssh/config.private
   ```

3. Put your private or machine-specific SSH hosts there (e.g. staging, personal VPS, etc.)

---

### 📦 Notes

- Aliases are defined in `fish/conf.d/aliases.fish`, with descriptions and usage examples
- Banner logic is in `fish/functions/banner_sergio.fish`, adapts to terminal width
- Git config includes SSH key signing via 1Password and VSCode as default editor
- `~/.ssh/config` includes both public and private SSH configs via `Include`

---

### 🧪 Safety Notes

- Symlinks may overwrite files silently (`ln -sf`)
- Always inspect your real config before linking
- Sensitive files like `config.private`, keys or secrets are excluded via `.gitignore`
