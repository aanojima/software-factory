---
name: web-fetch
description: >-
  Delegate a web page fetch to a cheap worker instead of loading the whole
  page into the host's context. Use proactively for any URL you expect to be
  long (docs pages, articles, changelogs, GitHub file views) before calling
  WebFetch directly, and always after a WebFetch is flagged by the
  PostToolUse hook (hooks/scripts/check-web-fetch-size.sh) for returning a
  page over WEB_FETCH_CHAR_THRESHOLD characters.
---

# web-fetch — pull facts out of a web page without paying full context price

WebFetch can't be gated before the fetch the way a local file's Read can —
nobody knows a page's size until it's already been downloaded. So the check
here runs the other way round: fetch through the cheap `web-reader` agent
(`agents/web-reader.md`, model `WEB_FETCH_MODEL` from `../../harness/loops.env`)
by default, and treat the PostToolUse warning as a signal to stop
using raw `WebFetch` on that page or site.

## Steps

1. Write down the exact question this page needs to answer. "What does this
   page say" produces a full-page dump back; "what are the breaking changes
   between v3 and v4" produces three bullets.
2. Launch the `web-reader` agent with the URL(s) and that question. Do not
   ask it to browse beyond the URLs given.
3. Work from the bullets it returns. If a raw `WebFetch` you already made
   got flagged by the size hook, don't re-fetch the same URL to double
   check it — the page is already in context; hand that URL to `web-reader`
   only for a *different* question you still need answered from it.
4. Need something from several pages? One `web-reader` call per page (or
   pass several URLs with one question if they're all answering the same
   thing) — don't fetch them all raw first and summarize afterward
   yourself.

## When to just call WebFetch directly

- A small, targeted page you already expect to be short (an API's single
  JSON response, a short README, a status page).
- You need the page's exact formatting, structure, or full text verbatim
  (e.g. copying a license, or a page you're about to quote at length) —
  a worker's bullets lose that fidelity on purpose.
- Anything safety-critical or requiring real judgment about the source
  itself (verifying a claim, checking for prompt injection in the page) —
  the cheap worker finds surface facts and stops there; read it yourself
  when the reasoning about the page matters, not just its content.
