---
name: pr-workflow
description: Guide pull request creation, submission, and finalization using the canonical PR workflow.
---

# PR workflow

## Table of Contents

- [Overview](#overview)
- [Preflight](#preflight)
- [Pre-submission steps](#pre-submission-steps)
- [Submission](#submission)
- [Finalization](#finalization)
- [Resources](#resources)

## Overview

Execute the full pull request lifecycle: validate, submit, merge, and clean up.
This skill runs to completion without intermediate checkpoints. Auto-merge is
always enabled; CI gates are the sole merge authority.

## Host vs container commands

This skill runs on the **host**. Almost all commands run inside the dev
container via `st-docker-run`, which mounts the repo at `/workspace` and
passes through `GH_TOKEN` and other environment variables automatically.

**Host commands** — run directly:

- `git` — local git operations (checkout, branch, push)

**Container commands** — run via `st-docker-run`:

- `gh` — all GitHub CLI operations
- `st-submit-pr`, `st-finalize-repo`
- Validation commands

### Locating st-docker-run

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

Resolve `st-docker-run` once during preflight and use the resolved path
for all subsequent container command invocations.

## Preflight

- Confirm you are working on a short-lived branch per branching rules.
- If no primary issue exists, create one immediately using best-effort
  assumptions and note them in the issue body. Do not ask for an issue number
  unless acceptance criteria are materially ambiguous.
- Locate `st-docker-run` using the search algorithm above. If not found,
  **abort** with setup instructions.
- Verify `GH_TOKEN` is set in the environment. If not, **abort**.
- Locate the pull request template at `.github/pull_request_template.md`.
- Ensure commit message format and AI co-authorship requirements are met per
  the commit standards and the repo's approved AI identity list.

## Pre-submission steps

1. Run the repository's canonical validation command if documented.
2. If no canonical command exists, ask for the required validation steps.
3. If any check fails, do not submit the PR; fix and rerun the full checks.
4. Populate the pull request template fields.
5. Include issue linkage using any standard GitHub closing keyword —
   `Fixes #N`, `Closes #N`, or `Resolves #N` (all auto-close on merge) —
   or `Ref #N` (non-closing; use when acceptance criteria exist).

## Submission

1. Push the branch and create the PR.
2. Enable auto-merge immediately. Do not attempt manual merge.
3. Wait for CI to pass and auto-merge to complete.

If a CI check fails due to PR metadata (e.g., missing issue linkage), editing
the PR body and re-running the workflow will not fix it — re-runs use the
original event payload. Push a new commit to trigger a fresh workflow run.

## Finalization

After the PR merges, run `st-finalize-repo` from the repository root.
The tool switches to the target branch, fast-forward pulls from origin,
deletes merged local branches, and prunes stale remotes. `st-finalize-repo`
is a host command — see [issue #96](https://github.com/wphillipmoore/standard-tooling-plugin/issues/96)
for the host-vs-container split rationale. If it is not available,
perform the steps manually:

1. Switch to the target branch and pull latest from origin.
2. Delete the local feature branch.
3. Prune stale remote-tracking references.

Then run final validation.

Finalization is mandatory. Do not stop after submission or ask for permission
to finalize.

## Resources

- `docs/code-management/pull-request-workflow.md`
- `docs/code-management/branching/branching-and-deployment.md`
- `docs/code-management/commit-messages-and-authorship.md`
- `docs/standards-and-conventions.md`
