# Agents

The plugin provides custom subagents that can be invoked during Claude Code
sessions.

## Bootstrap Agent

**Model**: haiku
**Tools**: Read, Glob, Grep, Bash

The bootstrap agent runs at the start of every work session to validate the
development environment and emit a preflight status report. It runs before any
code changes are made.

### Checks Performed

1. **Repository Profile** — reads `docs/repository-standards.md` and extracts
   `repository_type`, `branching_model`, `primary_language`, and
   `canonical_local_validation_command`

2. **Branch State** — reports the current branch and warns if on a protected
   branch (`main` or `develop`)

3. **Host Dispatcher** — verifies `st-docker-run` is available on PATH
   (the host-side dispatcher for container-routed validation)

4. **Standards and Conventions** — checks if the standards repo is available
   locally at `../standards-and-conventions`

5. **Git Hooks** — verifies `core.hooksPath` is configured

### Status Report

The agent emits a structured report:

```text
=== Session Bootstrap ===
Repository:    <repo name>
Profile:       <repository_type> | <branching_model> | <primary_language>
Branch:        <current branch> [WARNING if protected]
Validation:    <validation command or "not configured">
st-docker-run: <available or "NOT FOUND">
Standards:     <local or web fallback>
Git hooks:     <hooks path or "NOT CONFIGURED">
=========================
```

Any warnings are collected and listed in a separate section after the status
block.
