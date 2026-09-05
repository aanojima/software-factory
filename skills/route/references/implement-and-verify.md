# Implement, verify, advise — shared core

The same three steps run everywhere code gets written and pushed, whether
that's the first commit before a PR exists (`/route`'s DIRECT/STANDARD/HEAVY)
or a follow-up commit on a PR that's already open and being watched
(`pr-intake`'s STANDARD dispatch and HEAVY apply-decision dispatch). Only the
gate that follows this core differs by context.

## Core (always, in order)

1. Implement the fix or feature.
2. Discover and run the same test command CI itself runs for this repo —
   check the relevant workflow file or the repo's existing test
   scripts/Makefile, don't guess a different one. Capped at `TEST_LOOP_CAP`
   (`harness/loops.env`).
3. Run the advisory pass (`review-panel.md`'s advisory section —
   `coderabbit` + `ponytail-review`). Cheap, non-blocking, never loops —
   catches an obvious mistake before it reaches CI or a human reviewer.

## Then the gate — depends on context

- **No PR yet, tier T0/DIRECT:** no blocking panel — tests are the gate.
  Open a PR.
- **No PR yet, tier T1/STANDARD:** add the T1 blocking panel
  (`review-panel.md`, cap `REVIEW_LOOP_CAP`) before opening a PR.
- **No PR yet, tier T2/HEAVY:** add the T2 blocking panel (cap
  `REVIEW_LOOP_CAP_T2`), then stop for the human to sign the diff before
  opening a PR — never auto-merged.
- **PR already open and being watched** (`pr-intake` dispatched this): no
  blocking-panel re-run. The PR is already under continuous watch, so
  whatever CI or a reviewer does in reaction to this push arrives as the
  next event `pr-intake` triages — re-running the full panel here would
  duplicate that loop instead of feeding it. Push to the existing branch;
  there's no new PR to open.
