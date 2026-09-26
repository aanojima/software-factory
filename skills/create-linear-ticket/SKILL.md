---
name: create-linear-ticket
description: >-
  Draft and save concise Linear issues: context, scope, testable acceptance
  criteria, settled decisions, and an optional high-level design. Resolves
  team, project, milestone, and repo; sets priority and blocker relations via
  save_issue. Use when the user asks to create or file a Linear ticket/issue
  (or a batch), tighten a verbose ticket, update an issue's description, or
  asks for a ticket/issue template. Not for implementing a ticket — use
  implement-ticket or stage-ticket for that.
---

# create-linear-ticket — concise Linear issues, saved with correct links

## Trigger
- Create a new Linear ticket/issue, or a batch of them.
- Make an existing ticket concise, or the user flags one as verbose.
- Update/save a Linear issue's description.
- Asked for a "ticket template" or "issue template" (show the template; do
  not save anything).

## Template

The title goes in the `title` field, not in the description.

```markdown
**Context** — 1–2 lines: why this exists, what it is split from. Link discussions; do not summarize them.
Repo: <org>/<name>

**Scope**
- Concrete deliverable (code, design, doc, action) — what must exist when done, not steps

**Out of scope**
- Explicit exclusion that stops scope creep

**Acceptance criteria**
- [ ] Testable condition (Given X, when Y, then Z — or a plain check)

**Design (high-level)** — complex work only, 3–8 lines:
- Components touched and the data flow between them
- Interface, schema/contract, or flag changes
- Main risk or trade-off and how it is handled
- Link to the full design doc — do not copy it

**Decisions**
- YYYY-MM-DD — settled call (outcome only, no rejected options)
```

## Writing rules
- **Title**: `[Area] Verb + object`, scannable in a list. No "As a user, I
  want…".
- **Cut test**: if a line does not change what gets built or how it is
  verified, delete it.
- **Acceptance criteria**: someone other than the author can check each one
  off without asking what "done" means.
- **Design**: only when work spans components, changes a contract/schema, or
  has a non-obvious risk. Shape of the solution, not steps.
- **Decisions**: a log of outcomes, not the debate.
- No step-by-step implementation plan — that is the assignee's job.
- Omit empty sections; never leave placeholders.
- Blockers go in Linear relations (`blockedBy`/`blocks`), not the description.

## Field rules
- **Team** (required): use the team the user named, or the parent/related
  issue's team. If `list_teams` returns one team, use it. Otherwise ask.
- **Project + milestone**: always attempt both via `list_projects` /
  `list_milestones`. Set only at HIGH confidence — the user named it, a
  parent/blocking issue is in it, or the ticket clearly fits the project's
  stated scope and its active milestone. Otherwise leave unset and say so.
- **Repo** (engineering tickets only): exactly one. Put `Repo: <org>/<name>`
  in Context and pass `links: [{url: "<repo URL>", title: "Repo: <name>"}]`.
  Work across repos → one ticket per repo, linked by relations. Ops, design,
  docs, and process tickets skip this.
- **Labels, assignee, estimate**: set only when known; never guess.
- **Priority**: 1=Urgent, 2=High, 3=Medium, 4=Low. Never leave 0=None on a
  new issue.

## Priority rule for blockers
A blocker's priority must be ≥ every issue it blocks (numerically:
blocker ≤ downstream; 0=None counts as lowest).

1. Reject cycles in the dependency graph before saving anything.
2. Process in reverse topological order (downstream first):
   `priority(blocker) = min(own, min(priority of each issue it blocks))`,
   ignoring 0 values.
3. Only raise blockers. Never lower a downstream issue to satisfy the rule.
4. If a new ticket is blocked by an existing issue, apply the same check and
   raise the existing issue if needed — report that change explicitly.

## Steps
1. **Gather**: task/problem, settled decisions, related/blocking issues,
   team, candidate project/milestone, repo. For a rewrite, fetch the
   current issue first (`get_issue`).
2. **Draft** each ticket from the template, then apply the cut test.
3. **Rewrites**: keep every issue mention (e.g. `FIN-123`), date, and
   decision already recorded. Do not invent new ones.
4. **Plan the batch**: build the dependency graph, check for cycles, and
   compute final priorities with the blocker rule.
5. **Confirm**: show all drafts with their fields, the dependency graph, and
   priorities. Wait for approval unless the user already approved the content
   or asked to skip review.
6. **Save**: `save_issue` per ticket with `team`, `title`, `description`,
   `priority`, and resolved `project`, `milestone`, `links`, `labels`,
   `assignee`. For an update, pass `id` with the identifier. Save upstream
   blockers first so their identifiers exist.
7. **Link**: after the whole batch is saved, set relations — prefer
   `blockedBy` on the downstream issue. Apply any priority raises to existing
   issues found in step 4.
8. **On failure** mid-batch: stop, report what saved and what did not.
   Before a retry, search for the title (`list_issues`) so you do not create
   a duplicate.

## Verification (before reporting)
- Every `save_issue` call returned an issue object/URL; nothing is reported
  as saved without one.
- Every acceptance criterion is checkable by someone other than the author.
- No user-story phrasing, no implementation plan; Design ≤ 8 lines and links
  out.
- No decision, issue mention, or dependency was lost in a rewrite.
- Each engineering ticket has exactly one repo link.
- Project/milestone set only at high confidence; unset ones are named.
- Every blocker's priority ≥ all issues it blocks; no cycles.

## Report
One compact list, one line per issue:
`<ID> <title> — P<n> — project/milestone (or "unset") — blockedBy: <IDs>`
Then any priority raised on an existing issue, and any field left unset.
