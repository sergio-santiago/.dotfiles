## Git Commits

- No AI attribution (no footers, no Co-Authored-By, no "Generated with" in PRs)
- Conventional commits format (feat:, fix:, refactor:, docs:, etc...)
- Concise description with bullet points of key changes

## Development Environment

- Check the project's `Makefile` first for common tasks (tests, migrations, fixtures, lint, etc.)
- If the project has `docker-compose.yml`, tools (php, composer, node, etc.) run inside Docker, use `docker compose exec <service> <command>` instead of running binaries directly on the host

## Before Committing

- Run tests, linter, and any relevant checks to ensure everything passes
- Review that related documentation is up to date with the changes made (README, docs/*.md, OpenAPI schemas, TASKS.md, etc.)
- Do this proactively, don't wait for the user to ask

## Writing Style

- Never use em dashes (—) or semicolons in prose. They read as AI tells. This covers chat
  replies, READMEs, docs, code comments, commit messages and PR bodies
- Use a colon for a definition in a list or table. Use a comma, a colon, parentheses or two
  sentences for an aside. Never swap an em dash for a semicolon, that trades one tell for another
- Semicolons that are syntax (RGB escape codes, shell, TypeScript, HTML entities) are code, not
  prose. Leave them alone
- Avoid the related tells: rhetorical triplets, "not just X but Y", "it's worth noting", padded
  openers, and closing every answer with an offer to do more

## Working Method

- One pending item at a time: propose it, get it approved, execute it, close it, and only then
  move on. Never a list of twenty things to review at once. I do not know in advance what each
  item involves, so a long list means deciding on things I have not read yet
- Keep the full backlog in memory and take a single item per turn, with its context and its cost
- Before applying anything, show a table of current versus proposed

## Tooling Choices

- Hard constraint for anything in my own setup: free, no payment, no limits, no API keys.
  Quota-limited free tiers count as limited
- Lead with self-hosted, offline or free options. Do not offer a paid one as an equal candidate

## General Conventions

- CI/CD: GitHub Actions, auto-deploys on push to `main`
- PRs: title in English, description/body in Spanish. No test plan section unless asked
