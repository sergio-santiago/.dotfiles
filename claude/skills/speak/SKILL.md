---
name: speak
description: Read the last reply out loud, or turn this console on/off (on prints the available commands after each reply)
disable-model-invocation: true
argument-hint: "[on|off|summary|full|stop|test]"
allowed-tools: Bash(speak) Bash(speak *)
---

# Spoken replies

The command below already ran — its output is the result:

!`speak $ARGUMENTS`

Answer in **one short line** and nothing else — no explanation, no next steps, no
lists.

The user cannot see the command output above; only your line reaches the screen,
so state the outcome: now on, now off, reading, or nothing to read. If the output
reports a problem, such as Piper missing, say that instead.
