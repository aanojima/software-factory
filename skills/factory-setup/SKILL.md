---
name: factory-setup
description: Initialize, update, or inspect Software Factory project configuration using the installed plugin. Use when setting up a repository, refreshing its managed rules, migrating away from legacy symlinks or vendored Codex files, or enabling the optional OpenCode adapter.
---

# Software Factory project setup

Run the bundled scripts from this installed plugin; never create a PATH or
home-directory symlink and never require a source checkout.

- **Initialize:** run `../../harness/init.sh init [--opencode] <repo>`.
- **Update or migrate:** run `../../harness/init.sh update [--to <ref>]
  [--opencode] <repo>`. Pass `--opencode` to install or refresh the optional
  adapter. During a pre-0.2.1 migration, omitting it removes the old adapter.
- **Status:** run `../../harness/status.sh <repo>`.

Resolve those paths from this skill's directory. Default `<repo>` to the
current Git repository. Report the files changed and remind the user to commit
the project configuration. The scripts preserve task, routing-log, and golden
state during updates.
