---
name: project-issue
description: Create a well-structured GitHub issue by collecting required attributes through guided questions.
---

# New issue

## Table of Contents

- [Overview](#overview)
- [Workflow](#workflow)
  - [Determine target repository](#determine-target-repository)
  - [Collect issue type](#collect-issue-type)
  - [Collect summary](#collect-summary)
  - [Collect problem or goal](#collect-problem-or-goal)
  - [Collect acceptance criteria](#collect-acceptance-criteria)
  - [Collect validation](#collect-validation)
  - [Confirm and create](#confirm-and-create)
  - [Report](#report)
- [Resources](#resources)

## Overview

Create a single GitHub issue by walking the human through a series of
questions that collect all fields required by the GitHub issue standards.
The skill enforces the minimum required structure (Summary, Problem/Goal,
Acceptance Criteria, Validation) and applies a label.

### Tooling

This skill runs entirely on the **host**. All commands — `git`, `gh`,
and the `st-*` CLI tools below — are host commands invoked directly
without `st-docker-run` wrapping. See the
[`publish` skill's host-vs-container section](../publish/SKILL.md#host-vs-container-commands)
for the canonical split and rationale
([#96](https://github.com/wphillipmoore/standard-tooling-plugin/issues/96)).

**Commands used:**

- `git` — local git operations
- `gh` — GitHub CLI (issue creation)
- `st-ensure-label` — create a label if it doesn't exist

Verify `GH_TOKEN` is set in the environment before proceeding.

### Interaction modes

Each collection step uses one of two interaction modes:

- **Selection** — Use `AskUserQuestion` when the user picks from a fixed
  set of options (repository, issue type).
- **Free-text** — Ask via a plain conversational message and wait for the
  user's reply. Do NOT use `AskUserQuestion` for open-ended input such as
  the issue title, problem description, or acceptance criteria details.
  Simply prompt the user in your message and let them respond naturally.

### Ad-hoc code prohibition

Do NOT write ad-hoc code (inline Python, jq pipelines, etc.) to query
GitHub during this workflow. Every GitHub data lookup is handled by either
a pinned `gh` command documented in this skill or an `st-*` CLI command.
If a command is not documented here, it is not needed.

## Workflow

### Determine target repository

Default to the current repository (from the working directory):

```bash
gh repo view --json nameWithOwner --jq '.nameWithOwner'
```

If the user specifies a different repository, use that instead.

**Captures**: `target_repo` (as `owner/repo`).

### Collect issue type

> Interaction mode: **selection**

Ask the user for the issue type:

| Type         | GitHub label  | Title prefix |
| ------------ | ------------- | ------------ |
| Enhancement  | enhancement   | feat:        |
| Bug          | bug           | fix:         |
| Research     | research      | research:    |
| Chore        | chore         | chore:       |
| Docs         | documentation | docs:        |

After the user selects, ensure the label exists:

```bash
st-ensure-label --repo <target_repo> --label <label>
```

**Captures**: `label`, `title_prefix`.

### Collect summary

> Interaction mode: **free-text**

Ask the user for a short title describing the issue. Prefix the title
with the conventional type from the table above.

Example: `feat: add retry configuration to REST client`

**Captures**: `title`.

### Collect problem or goal

> Interaction mode: **free-text**

Ask the user to describe the problem being solved or the goal being
achieved. This becomes the **Problem / Goal** section of the issue body.

**Captures**: `problem_or_goal`.

### Collect acceptance criteria

> Interaction mode: **selection** for the initial question, then
> **free-text** if the user needs to provide explicit criteria.

Ask whether acceptance criteria are obvious from the summary.

- If obvious: record "Acceptance criteria are implicit from the summary."
- If not obvious: collect explicit criteria as a checklist (one item per
  line, each prefixed with `- [ ]`).

**Captures**: `acceptance_criteria`.

### Collect validation

> Interaction mode: **selection** (multi-select)

Ask how completion will be verified. Present the common options as a
multi-select list:

- CI passes
- Tests added
- Documentation updated
- Manual verification

The user may also provide a custom response via the "Other" option.

**Captures**: `validation`.

### Confirm and create

Assemble the issue and present it to the user for review:

```text
Repository: <target_repo>
Title: <title>
Labels: <label>

## Problem / Goal

<problem_or_goal>

## Acceptance Criteria

<acceptance_criteria>

## Validation

<validation>
```

After user approval, write the body to a temp file and create:

```bash
gh issue create --repo <target_repo> \
  --title "<title>" --label "<label>" \
  --body-file <tempfile>
```

Capture the issue URL from stdout.

### Report

Display the issue URL.

## Resources

- `docs/code-management/github-issues.md` (in `standard-tooling`)
- `docs/code-management/commit-messages-and-authorship.md` (in
  `standard-tooling`)
