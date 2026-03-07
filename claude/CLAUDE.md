## Git Commits

- No AI attribution (no footers, no Co-Authored-By)
- Conventional commits format (feat:, fix:, refactor:, docs:, etc...)
- Concise description with bullet points of key changes

## Development Environment

- Always use Docker containers to run commands (php, composer, node, etc.) — nothing is installed locally on the host machine
- Use `docker compose exec <service> <command>` instead of running binaries directly
- Check the project's `Makefile` first for common tasks (tests, migrations, fixtures, lint, etc.) before writing commands manually

## Before Committing

- Run tests, linter, and any relevant checks to ensure everything passes
- Review that related documentation is up to date with the changes made (README, docs/*.md, OpenAPI schemas, TASKS.md, etc.)
- Do this proactively — don't wait for the user to ask

## General Conventions

- CI/CD: GitHub Actions, auto-deploys on push to `main`
- PRs: title in English, description/body in Spanish. No test plan section unless asked
