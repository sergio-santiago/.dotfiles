# ─────────────────────────────────────────────────────────────────────────────
#  Sergio's .dotfiles: common tasks
#  Run `make` (or `make help`) to see available targets.
# ─────────────────────────────────────────────────────────────────────────────

# Derived from this file's own location rather than from `pwd`, so the targets keep
# working under `make -f ~/.dotfiles/Makefile <target>` from another directory.
DOTFILES := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
SHELL    := /bin/bash

.DEFAULT_GOAL := help

.PHONY: help install brew link link-dry default-shell doctor colors-check speak-setup brew-maintenance test

help: ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1m%-16s\033[0m %s\n", $$1, $$2}'

install: brew link ## Full setup on a new machine: install packages + symlink configs
	@echo "✅ install complete. See post-install steps above"

brew: ## Install all packages/apps from the Brewfile
	@command -v brew >/dev/null 2>&1 \
		|| { echo "brew not found. Install Homebrew first: https://brew.sh"; exit 1; }
	brew bundle --file "$(DOTFILES)/Brewfile"

link: ## Symlink configs into ~/.config, ~/.claude, ~/.ssh, ~/.local/bin (idempotent, backs up existing)
	@bash "$(DOTFILES)/scripts/install.sh"

link-dry: ## Show what `make link` would do, changing nothing
	@bash "$(DOTFILES)/scripts/install.sh" --dry-run

default-shell: ## Make Homebrew fish the default login shell
	@FISH="$$(command -v fish)"; \
	if [ -z "$$FISH" ]; then echo "fish not installed. Run 'make brew' first"; exit 1; fi; \
	grep -qxF "$$FISH" /etc/shells || (echo "$$FISH" | sudo tee -a /etc/shells >/dev/null); \
	chsh -s "$$FISH" && echo "Default shell set to $$FISH (restart your terminal)"

doctor: ## Verify tools, symlinks and environment are healthy
	@bash "$(DOTFILES)/scripts/doctor.sh"

brew-maintenance: ## Update, tidy up and review Homebrew (also on PATH, aliased to bm)
	@bash "$(DOTFILES)/scripts/bin/brew-maintenance"

test: ## Run the test suite
	@bash "$(DOTFILES)/scripts/tests/run.sh"

colors-check: ## Lint the linked_data_dark_rainbow palette for drift
	@bash "$(DOTFILES)/scripts/colors-check.sh"

speak-setup: ## Install Piper + Spanish voices so Claude Code can speak its replies
	@bash "$(DOTFILES)/scripts/speak-setup.sh"
