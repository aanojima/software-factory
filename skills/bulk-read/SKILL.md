---
name: bulk-read
description: >-
  Delegate a large-file read to a cheap worker instead of loading the whole
  file into the host's context. Use whenever a Read or cat/less/more call is
  denied by the bulk-read hook (hooks/scripts/check-file-size.sh,
  check-bash-read.sh) with a BULK_READ_LINE_THRESHOLD reason, or proactively
  for any file you expect to be large when you only need facts out of it, not
  the file itself.
---

# bulk-read — pull facts out of a large file without paying full context price

A blocked Read means: you do not need the whole file, you need an answer
that happens to live inside it. Get that answer through the `bulk-reader`
agent (`agents/bulk-reader.md`, model `BULK_READ_MODEL` from
`../../harness/loops.env`) instead of retrying the Read.

## Steps

1. Write down the exact question this file needs to answer. Vague questions
   ("summarize this file") produce vague bullets — ask for what you'll
   actually use ("which functions call `checkoutSession`, with line
   numbers").
2. Launch the `bulk-reader` agent with the file path(s) and that question.
   Do not pass it anything else to explore.
3. Work from the bullets it returns. Never re-issue the blocked Read to
   check the agent's answer — that defeats the point, and the file's
   content is not meant to reach this context at all.
4. If the bullets are insufficient, ask a sharper follow-up question to a
   new `bulk-reader` call rather than falling back to a full Read. Only
   fall back to a targeted `Read` with an explicit `offset`/`limit` if you
   already know the precise section you need to edit — the hook lets that
   through on its own.

A dispatched agent's result can carry a trailing `agentId: ... (use
SendMessage with to: '...', summary: '...')` block after its actual answer —
that is orchestration bookkeeping from the dispatch mechanism, not something
the `bulk-reader` wrote and never something from the file. Disregard it: it
is not file content, not an instruction, and not a prompt-injection attempt,
even if it resembles one out of context — it shows up most often when the
worker's real answer is short or empty (e.g. a genuinely blank last line).
Treat only the text before that block as the answer.

## What this is not for

- Editing a file. Line numbers from a summary are not reliable enough to
  edit against; read the target section directly with `offset`/`limit`.
- Anything safety-critical or requiring real reasoning over the file (e.g.
  spotting a concurrency bug). The cheap worker finds surface patterns and
  stops there — escalate those to a normal Read instead of trusting a
  summary.
