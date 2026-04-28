# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Auto-memory policy

**Do NOT use MEMORY.md.** Never write to MEMORY.md or any file under the
memory directory. All behavioral rules, conventions, and workflow instructions
belong in managed, version-controlled documentation (CLAUDE.md, AGENTS.md,
skills, or docs/). If you want to persist something, tell the human what you
would save and let them decide where it belongs.

## Parallel AI agent development

This repository supports running multiple Claude Code agents in parallel via
git worktrees. The convention keeps parallel agents' working trees isolated
while preserving shared project memory (which Claude Code derives from the
session's starting CWD).

**Canonical spec:**
[`standard-tooling/docs/specs/worktree-convention.md`](https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/specs/worktree-convention.md)
— full rationale, trust model, failure modes, and memory-path implications.
The canonical text lives in `standard-tooling`; this section is the local
on-ramp.

### Structure

```text
~/dev/github/standard-tooling-plugin/     ← sessions ALWAYS start here
  .git/
  CLAUDE.md, hooks/, skills/, …           ← main worktree (usually `develop`)
  .worktrees/                             ← container for parallel worktrees
    issue-42-adopt-worktree-convention/   ← worktree on feature/42-...
    …
```

### Rules

1. **Sessions always start at the project root.**
   `cd ~/dev/github/standard-tooling-plugin && claude` — never from inside
   `.worktrees/<name>/`. This keeps the memory-path slug stable and shared.
2. **Each parallel agent is assigned exactly one worktree.** The session
   prompt names the worktree (see Agent prompt contract below).
   - For Read / Edit / Write tools: use the worktree's absolute path.
   - For Bash commands that touch files: `cd` into the worktree first,
     or use absolute paths.
3. **The main worktree is read-only.** All edits flow through a worktree
   on a feature branch — the logical endpoint of the standing
   "no direct commits to develop" policy.
4. **One worktree per issue.** Don't stack in-flight issues. When a
   branch lands, remove the worktree before starting the next.
5. **Naming: `issue-<N>-<short-slug>`.** `<N>` is the GitHub issue
   number; `<short-slug>` is 2–4 kebab-case tokens.

### Agent prompt contract

When launching a parallel-agent session, use this template (fill in the
placeholders):

```text
You are working on issue #<N>: <issue title>.

Your worktree is: /Users/pmoore/dev/github/standard-tooling-plugin/.worktrees/issue-<N>-<slug>/
Your branch is:   feature/<N>-<slug>

Rules for this session:
- Do all git operations from inside your worktree:
    cd <absolute-worktree-path> && git <command>
- For Read / Edit / Write tools, use the absolute worktree path.
- For Bash commands that touch files, cd into the worktree first
  or use absolute paths.
- Do not edit files at the project root. The main worktree is
  read-only — all changes flow through your worktree on your
  feature branch.
```

All fields are required.

## Starting work on an issue

When the user references a GitHub issue and wants work to begin on
it, follow the procedure in
[`docs/development/starting-work-on-an-issue.md`](docs/development/starting-work-on-an-issue.md).
It covers: resolving project / cross-repo / repo-local issue
inputs to a repo-local issue number, sub-issue creation when work
spans repos, existing-worktree and existing-remote-branch
detection, and the canonical `git worktree add` invocation that
honors the worktree convention.

This replaces the former `branch-workflow` skill. The substance is
the same; the format is now agent-instruction documentation rather
than a slash-command, since the procedure was rarely invoked
cold and is most useful as a reference at the moment work begins.

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

| Repo                       | Delivers                  | Via    |
| -------------------------- | ------------------------- | ------ |
| `standard-tooling`         | Python CLIs, bash, hooks  | PATH   |
| `standard-tooling-plugin`  | Skills, agents, commands  | Plugin |

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

## Refreshing the plugin locally

When the user asks how to refresh / update / reinstall this plugin
after a new release, the canonical sequence is in the README's
[Update section](README.md#update). Do **not** guess or improvise —
the sequence is two steps (`marketplace update` → `reload-plugins`)
and both are required.

## Development and deployment of this repo

Working on the plugin itself (vs. consuming it) has its own
canonical procedure. See
[`README.md` → Development and deployment](README.md#development-and-deployment)
for: worktree setup, the `pr-workflow` skill for shipping a
change, the `publish` skill for cutting a release, and the
**post-publish Phase 7 hand-off** which is the producer-side
obligation to surface the consumer-refresh sequence to the user
at release time.

When you complete a publish, **the cycle is not done until you
have shown the user the three-step refresh sequence.** Listing
artifacts and stopping is a regression on
[#105](https://github.com/wphillipmoore/standard-tooling-plugin/issues/105).
