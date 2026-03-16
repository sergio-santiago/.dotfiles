## Git Commits

- No AI attribution (no footers, no Co-Authored-By, no "Generated with" in PRs)
- Conventional commits format (feat:, fix:, refactor:, docs:, etc...)
- Concise description with bullet points of key changes

## Development Environment

- Check the project's `Makefile` first for common tasks (tests, migrations, fixtures, lint, etc.)
- If the project has `docker-compose.yml`, tools (php, composer, node, etc.) run inside Docker — use `docker compose exec <service> <command>` instead of running binaries directly on the host

## Before Committing

- Run tests, linter, and any relevant checks to ensure everything passes
- Review that related documentation is up to date with the changes made (README, docs/*.md, OpenAPI schemas, TASKS.md, etc.)
- Do this proactively — don't wait for the user to ask

## General Conventions

- CI/CD: GitHub Actions, auto-deploys on push to `main`
- PRs: title in English, description/body in Spanish. No test plan section unless asked
