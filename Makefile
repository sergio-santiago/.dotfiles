# ─────────────────────────────────────────────────────────────────────────────
#  Sergio's .dotfiles — common tasks
#  Run `make` (or `make help`) to see available targets.
# ─────────────────────────────────────────────────────────────────────────────

DOTFILES := $(shell pwd)
SHELL    := /bin/bash

.DEFAULT_GOAL := help

.PHONY: help install brew link unlink default-shell doctor colors-check

help: ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1m%-16s\033[0m %s\n", $$1, $$2}'

install: brew link ## Full setup on a new machine: install packages + symlink configs
	@echo "✅ install complete — see post-install steps above"

brew: ## Install all packages/apps from the Brewfile
	brew bundle --file "$(DOTFILES)/Brewfile"

link: ## Symlink configs into ~/.config, ~/.claude, ~/.ssh (idempotent, backs up existing)
	@bash "$(DOTFILES)/scripts/install.sh"

default-shell: ## Make Homebrew fish the default login shell
	@FISH="$$(command -v fish)"; \
	if [ -z "$$FISH" ]; then echo "fish not installed — run 'make brew' first"; exit 1; fi; \
	grep -qxF "$$FISH" /etc/shells || (echo "$$FISH" | sudo tee -a /etc/shells >/dev/null); \
	chsh -s "$$FISH" && echo "Default shell set to $$FISH (restart your terminal)"

doctor: ## Verify tools, symlinks and environment are healthy
	@bash "$(DOTFILES)/scripts/doctor.sh"

colors-check: ## Lint the linked_data_dark_rainbow palette for drift
	@bash "$(DOTFILES)/scripts/colors-check.sh"
