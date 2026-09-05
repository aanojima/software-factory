---
description: Start an unattended CI + review-comment watcher for a shipped PR, delegated to a cheap intake agent.
argument-hint: [pr-number-or-url]
---

Use the `pr-watch` skill to start watching:

`$ARGUMENTS`

Launch the plugin's `pr-intake` agent in the background and return
immediately — do not poll CI or review comments from this session. Durable
state and the event log live under `.agent-runs/pr-watch/<pr>/`.
