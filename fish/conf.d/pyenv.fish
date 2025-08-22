# --- Pyenv (minimal Homebrew setup) ---
set -gx PYENV_ROOT $HOME/.pyenv
type -q pyenv; and status --is-interactive; and pyenv init - | source
