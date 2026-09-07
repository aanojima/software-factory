---
name: factory-setup
description: Initialize, update, or inspect Software Factory project configuration using the installed plugin. Use when setting up a repository, refreshing its managed rules, migrating away from legacy symlinks or vendored Codex files, or enabling the optional OpenCode adapter.
---

# Software Factory project setup

Run the bundled scripts from this installed plugin; never create a PATH or
home-directory symlink and never require a source checkout. When this skill is
invoked by Codex, prefix each `init` or `update` command with
`SOFTWARE_FACTORY_CODEX_PLUGIN_CONFIRMED=1`; when invoked by Claude, prefix it
with `SOFTWARE_FACTORY_CLAUDE_PLUGIN_CONFIRMED=1`. The installed plugin then
confirms that its workflow is available for legacy cleanup. Direct CLI
invocations omit both prefixes, so incomplete runtime migration is preserved
and reported for a later plugin-hosted run.

- **Initialize:** in Codex, run
  `SOFTWARE_FACTORY_CODEX_PLUGIN_CONFIRMED=1 ../../harness/init.sh init [--opencode] <repo>`;
  in Claude, use
  `SOFTWARE_FACTORY_CLAUDE_PLUGIN_CONFIRMED=1 ../../harness/init.sh init [--opencode] <repo>`;
  a direct CLI omits both prefixes.
- **Update or migrate:** in Codex, run
  `SOFTWARE_FACTORY_CODEX_PLUGIN_CONFIRMED=1 ../../harness/init.sh update [--to <ref>]
  [--opencode] <repo>`; in Claude, use
  `SOFTWARE_FACTORY_CLAUDE_PLUGIN_CONFIRMED=1 ../../harness/init.sh update [--to <ref>]
  [--opencode] <repo>`; a direct CLI omits both prefixes. Pass `--opencode`
  to install or refresh the optional adapter. During a pre-0.2.1 migration,
  host confirmation permits that host's cleanup; OpenCode and shared assets
  remain until `--opencode` is selected and its refresh succeeds.
- **Status:** run `../../harness/status.sh <repo>`.

Resolve those paths from this skill's directory. Default `<repo>` to the
current Git repository. Report the files changed and remind the user to commit
the project configuration. The scripts preserve task, routing-log, and golden
state during updates.
