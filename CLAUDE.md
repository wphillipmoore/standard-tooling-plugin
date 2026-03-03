# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Auto-memory policy

**Do NOT use MEMORY.md.** All behavioral rules, conventions, and workflow
instructions belong in managed, version-controlled documentation (CLAUDE.md,
AGENTS.md, skills, or docs/).

## Shell command policy

**Do NOT use heredocs** (`<<EOF` / `<<'EOF'`) for multi-line arguments to CLI
tools such as `gh`, `git commit`, or `curl`. Always write multi-line content
to a temporary file and pass it via `--body-file` or `--file` instead.

## Project Overview

This is a Claude Code plugin that delivers shared hooks, skills, agents, and
commands to all managed repositories in the standard-tooling ecosystem. It is
the behavioral counterpart to the `standard-tooling` Python package (which
delivers runtime CLI tools via PATH).

**Project name**: standard-tooling-plugin

**Plugin namespace**: `standard-tooling` (skills invoked as
`/standard-tooling:<skill-name>`)

**Status**: Pre-release (0.x)

## Architecture

### Plugin Manifest (`.claude-plugin/plugin.json`)

Defines the plugin identity, version, and metadata. The `name` field
(`standard-tooling`) determines the skill namespace prefix.

### Hooks (`hooks/hooks.json`)

PreToolUse and PostToolUse hooks that enforce guardrails mechanically rather
than relying on CLAUDE.md prose. These replace duplicated documentation rules
across all consuming repos.

### Skills (`skills/`)

Shared workflow skills migrated from `standards-and-conventions`. Each skill
is a directory containing a `SKILL.md` file with frontmatter and instructions.

### Agents (`agents/`)

Custom subagents including the bootstrap agent for session-start context
loading, PATH discovery, and preflight validation.

### Commands (`commands/`)

User-invokable slash commands (Markdown files).

## Two-Repo Model

| Repo | Delivers | Distribution |
|------|----------|-------------|
| `standard-tooling` | Python CLIs (`st-*`), bash validators, git hooks | PATH |
| `standard-tooling-plugin` | Hooks, skills, agents, commands | Claude Code plugin |

These are complementary: the plugin tells Claude how to behave; PATH makes the
tools available to run.

## Development Commands

### Validation

```bash
markdownlint .
```

## Branching and PR Workflow

- **Protected branches**: `main`, `develop` — no direct commits
- **Branch naming**: `feature/*`, `bugfix/*`, `hotfix/*`, `chore/*`, or
  `release/*` only
- **Feature/bugfix PRs** target `develop` with squash merge
- **Release PRs** target `main` with regular merge

## Commit and PR Scripts

**NEVER use raw `git commit`** — always use `st-commit`.
**NEVER use raw `gh pr create`** — always use `st-submit-pr`.
