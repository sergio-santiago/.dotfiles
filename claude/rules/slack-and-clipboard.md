# Messages to send, and the clipboard

## Messages for Slack (or any chat)

When I ask for a message to send, show it, then copy it with `slack-clip` (in `~/.local/bin`)
without being asked, so it pastes with its formatting. Write it once in simple markdown and pipe
it in: `slack-clip <<'EOF' ... EOF`. The script's header lists what it supports.

Match the format to the kind of message, the way a person would:

- **A reply in a conversation** (answering someone, a question, a thank-you, a quick heads-up):
  short and plain, like a human typing. No headers, no bullet lists, no emoji decoration.
  A link or a bold word only if it helps.
- **A structured update** (a written daily or standup, a status report, a summary of several
  items, an announcement, a handover): make it easy to scan. One idea per line or bullet, an emoji
  at the start of a line when it works as a label (✅ done, 🎯 today, 🚧 blockers), bold for the key
  word of each item, code formatting for commands and identifiers.

When unsure, lean towards the plain one. Formatting earns its place by making the message faster
to read, never as decoration.

In either kind, anything that has a URL (a task, a PR, an issue, a doc, a dashboard) is linked
with a short, readable text, never a bare URL. For PRs, the conventional-commit prefix of their
title reads well as the link text (`fix: MinIO in web-app`).

## Prompts for another session

When I ask for (or you give me) a prompt to open the next session, show it and also copy it to
the clipboard as plain text with `pbcopy`, without being asked.
