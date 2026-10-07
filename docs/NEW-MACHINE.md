# 💻 Setting up a new Mac

The whole restore, in the order that works. Each step only needs what the steps before it
installed, which is the reason for the order: the SSH key lives in 1Password, so nothing can
be cloned over SSH until 1Password is running and `make link` has pointed `~/.ssh/config` at
its agent.

Nothing here is all-or-nothing. Steps 1 to 5 are the base. Everything after that is a menu:
install what this machine needs and skip the rest.

---

## 1. Sign in and install 1Password

1. Sign in to the App Store with your Apple ID, so the App Store apps below can install.
2. Install **1Password** from [1password.com/downloads/mac](https://1password.com/downloads/mac),
   sign in, then enable **Settings → Developer → Use the SSH agent**. It holds the SSH key for
   GitHub and signs every commit (`op-ssh-sign` in `git/config`).

## 2. Homebrew and this repo

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# HTTPS, because SSH does not work yet: ~/.ssh/config is created by `make link` below
git clone https://github.com/sergio-santiago/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make link-dry        # read the plan first
make install         # Brewfile + every symlink
make default-shell   # fish as the login shell

# SSH works from here on, so switch the remote to it
git remote set-url origin git@github.com:sergio-santiago/.dotfiles.git
```

## 3. The private half

```bash
git clone git@github.com:sergio-santiago/dotfiles-private.git ~/.dotfiles-private
make private-pull
```

It restores SSH hosts, AWS profiles, the work git identities, the Finicky rules, the private fish
functions and the manual-duplex settings. See the README's *Machine-private config*.

## 4. Apps installed by hand

These carry their own updater or come from the App Store, so Homebrew would only add a stale
version record on top. The few apps that do **not** update themselves (Finicky, the Nerd Font)
are in the `Brewfile` instead and arrived with `make install`.

**Needed by this repo's configuration**

| App | Where | Why it is needed |
|-----|-------|------------------|
| Google Chrome | [google.com/chrome](https://www.google.com/chrome/) | The Finicky rules name it as the default browser and route links to its profiles |
| iTerm2 | [iterm2.com](https://iterm2.com/) | The terminal. Load its preferences from `~/.dotfiles/iterm`, see the README's *iTerm2 Configuration* |
| Claude Code | `curl -fsSL https://claude.ai/install.sh \| bash` | Everything under `claude/` configures it |

**Everyday apps**

| App | Where |
|-----|-------|
| Raycast | [raycast.com](https://raycast.com/) |
| Visual Studio Code | [code.visualstudio.com](https://code.visualstudio.com/) |
| Docker Desktop | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) |
| Claude | [claude.com/download](https://claude.com/download) |
| ChatGPT | [chatgpt.com](https://chatgpt.com/) |
| Claude Usage Tracker | [GitHub releases](https://github.com/hamed-elfayome/Claude-Usage-Tracker/releases) |
| Spark | [sparkmailapp.com](https://sparkmailapp.com/) |
| Discord | [discord.com](https://discord.com/) |
| WhatsApp | App Store |
| MeetingBar | App Store |

**Depending on the job**

| App | Where |
|-----|-------|
| Slack | App Store |
| Linear | [linear.app](https://linear.app/) |
| Notion | [notion.com](https://www.notion.com/) |
| Tailscale | [tailscale.com](https://tailscale.com/) |
| JetBrains IDEs | Through [JetBrains Toolbox](https://www.jetbrains.com/toolbox-app/), only when a job needs one |

Chrome's web apps (YouTube Music, Calendar, Meet) come back on their own once Chrome sync is on.

## 5. Claude Code, the parts outside this repo

```bash
claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp
```

Then run `/plugin` inside Claude Code to install the Slack plugin that `claude/settings.json`
enables, and authenticate it.

Optional, for spoken replies: `make speak-setup` (about 500 MB of model and venv, outside the repo).

## 6. Two-sided printing (manual-duplex)

For a printer without a duplexer. It prints one side, tells you how to turn the stack, then
prints the other. Source: [yasasalwis/macos-manual-duplex](https://github.com/yasasalwis/macos-manual-duplex).

The settings that matter live in `~/.config/manual-duplex/config`: the printer queue, the pass
order found by calibration, and `FLIP_HINT`, the message shown before the second pass. The default
message does not describe what this printer needs, so the one in use was rewritten by hand, and
that file is kept in the private repo.

**Order matters:** run `make private-pull` (step 3) *before* the installer. `install.sh` ends by
running `--setup`, which loads the config it finds and saves it back, so a restored `FLIP_HINT`
survives. The other way round, setup writes the default message.

```bash
git clone https://github.com/yasasalwis/macos-manual-duplex.git /tmp/manual-duplex
cd /tmp/manual-duplex && chmod +x install.sh manual-duplex.sh && ./install.sh
```

Setup asks for the printer and prints a two-sheet calibration. Redo it any time with
`~/.local/bin/manual-duplex --calibrate`, and check the result with `--doctor`.

## 7. Projects with their own dependencies

Each project installs its own, from a `Brewfile` and setup steps in its own repository. Nothing
here installs a dependency that only one project uses.

## 8. Check

```bash
make doctor
```
