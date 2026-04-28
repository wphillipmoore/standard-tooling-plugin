# Standard Tooling Plugin Agent Instructions

<!-- include: docs/standards-and-conventions.md -->
<!-- include: ./docs/repository-standards.md -->

## User Overrides (Optional)

If `~/AGENTS.md` exists and is readable, load it and apply it as a
user-specific overlay for this session. If it cannot be read, say so
briefly and continue.

## Canonical Standards

This repository follows the canonical standards and conventions in the
`standards-and-conventions` repository.

Resolve the local path (preferred):

- `../standards-and-conventions`

If the local path is unavailable, use the canonical web source:

- <https://github.com/wphillipmoore/standards-and-conventions>

If the canonical standards cannot be retrieved, treat it as a fatal
exception and stop.

## Shared Skills

Skills are delivered by the `standard-tooling` plugin (this repo) via
the Claude Code plugin system. Do **not** load skills from
`standards-and-conventions` — that repo's `skills/` directory contains
pre-migration copies that are stale or eliminated.

## Local Overrides

None.
