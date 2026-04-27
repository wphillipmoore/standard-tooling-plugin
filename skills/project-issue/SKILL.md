---
name: project-issue
description: Create a well-structured project issue by collecting required attributes through guided questions.
---

# New issue

## Table of Contents

- [Overview](#overview)
- [Workflow](#workflow)
  - [Select project](#select-project)
  - [Select target repository](#select-target-repository)
  - [Collect issue type](#collect-issue-type)
  - [Collect priority](#collect-priority)
  - [Collect work type](#collect-work-type)
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
Acceptance Criteria, Validation) and assigns the issue to a GitHub Project.

### Tooling

This skill runs on the **host**. Almost all commands run inside the dev
container via `st-docker-run`, which mounts the repo at `/workspace` and
passes through `GH_TOKEN` and other environment variables automatically.

**Host commands** — run directly:

- `git` — local git operations

**Container commands** — run via `st-docker-run`:

- `gh` — all GitHub CLI operations
- `st-list-project-repos`, `st-ensure-label`, `st-set-project-field`

Search for `st-docker-run` in this order:

1. `../standard-tooling/.venv-host/bin/st-docker-run` (sibling checkout
   with host venv)
2. `st-docker-run` on PATH (already installed)

If neither is found, **abort** with a message directing the user to set up
the host venv:

```text
st-docker-run not found. Run the following one-time setup:
  cd ../standard-tooling
  UV_PROJECT_ENVIRONMENT=.venv-host uv sync --group dev
```

Resolve `st-docker-run` once at the start of the workflow and use the
resolved path for all subsequent container command invocations. Also verify
`GH_TOKEN` is set in the environment before proceeding.

### Interaction modes

Each collection step uses one of two interaction modes:

- **Selection** — Use `AskUserQuestion` when the user picks from a fixed
  set of options (project, repository, issue type, priority, work type).
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

### Select project

> Interaction mode: **selection**

Determine the repository owner from the working directory:

```bash
gh repo view --json owner --jq '.owner.login'
```

List available GitHub Projects:

```bash
gh project list --owner <owner> \
  --format json \
  --jq '.projects[] | [.number, .title] | @tsv'
```

Ask the user to select one. Default to the project associated with the
current repository if identifiable. If only one project exists, select it
automatically and confirm.

**Captures**: `owner`, `project_number`, `project_name`.

### Select target repository

> Interaction mode: **selection**

List the repositories linked to the selected project:

```bash
st-list-project-repos --owner <owner> --project <project_number>
```

Output is one `owner/repo` per line. Ask the user which repository the
issue should be created in. Default to the current repository (determined
from the working directory) if it appears in the list.

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

### Collect priority

> Interaction mode: **selection**

Ask the user for the priority:

| Priority | Meaning                        |
| -------- | ------------------------------ |
| P0       | Now — immediate work           |
| P1       | Next — next up after current   |
| P2       | Later — backlog                |

This is set as a project field after the issue is added to the project.

**Captures**: `priority` (e.g. `P0`).

### Collect work type

> Interaction mode: **selection**

Ask the user for the work type:

| Work Type         | When to use                                  |
| ----------------- | -------------------------------------------- |
| feature           | New functionality                            |
| bugfix            | Fixing broken behavior                       |
| docs              | Documentation-only changes                   |
| research          | Investigation or spike                       |
| sync              | Cross-repo propagation                       |
| dependency-update | Dependency version bump                      |

This is set as a project field after the issue is added to the project.

**Captures**: `work_type`.

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
Project: <project_name>
Repository: <target_repo>
Title: <title>
Labels: <label>
Priority: <priority>
Work Type: <work_type>

## Problem / Goal

<problem_or_goal>

## Acceptance Criteria

<acceptance_criteria>

## Validation

<validation>
```

After user approval, execute the following steps in order.

**Step 1 — Create the issue.** Write the body to a temp file and create:

```bash
gh issue create --repo <target_repo> \
  --title "<title>" --label "<label>" \
  --body-file <tempfile>
```

Capture the issue URL from stdout.

**Step 2 — Add to project.** Add the issue and capture the item ID:

```bash
gh project item-add <project_number> \
  --owner <owner> --url <issue_url> \
  --format json --jq '.id'
```

**Step 3 — Set priority:**

```bash
st-set-project-field \
  --owner <owner> --project <project_number> \
  --item <item_id> --field Priority \
  --value <priority>
```

**Step 4 — Set work type:**

```bash
st-set-project-field \
  --owner <owner> --project <project_number> \
  --item <item_id> --field "Work Type" \
  --value <work_type>
```

### Report

Display the issue URL and project assignment confirmation.

## Resources

- `docs/code-management/github-issues.md`
- `docs/code-management/github-projects.md`
- `docs/code-management/commit-messages-and-authorship.md`
