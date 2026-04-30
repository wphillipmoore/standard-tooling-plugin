---
name: pr-workflow
description: Submit a pull request, wait for CI to go green, and hand off to the user for review and merge. Runs from inside the issue's worktree.
---

# PR workflow

## Table of Contents

- [Overview](#overview)
- [Preflight](#preflight)
- [Pre-submission](#pre-submission)
- [Submission](#submission)
- [Wait for CI green](#wait-for-ci-green)
- [Hand-off to the user](#hand-off-to-the-user)
- [After the merge](#after-the-merge)
- [Close the issue](#close-the-issue)
- [Resources](#resources)

## Overview

This skill covers the agent-side of the work cycle from "branch is
ready for review" through "PR is merged and local state is clean."
The flow is:

1. **Submit** the PR via `st-submit-pr`.
2. **Wait** for CI to go green. Fix red checks if fixable; surface
   to the user otherwise.
3. **Hand off** to the user — they review and merge. The agent
   does not enable auto-merge and does not merge the PR itself.
4. **Finalize** after the user reports the merge, by running
   `st-finalize-repo`.
5. **Close the issue** if this PR resolves it. Using `Ref`
   instead of `Fixes` defers the *timing* of closure, not the
   *responsibility*. The agent must close the issue explicitly
   after finalization succeeds.

### Critical policy: humans review and merge feature/bugfix PRs

Org-wide auto-merge is disabled. **Do not enable auto-merge.** Do
not merge the PR. Wait for a human reviewer, who will merge it
manually after review.

The single documented exception is release-workflow PRs (the
`release/<version>` PR and the `chore/bump-version-<next>` PR),
which the agent merges via `st-merge-when-green` from the
[`publish` skill](../publish/SKILL.md). That exception applies
only there; do not generalize it.

### Where this runs

Run all git operations and `st-*` invocations from inside the
issue's worktree at `.worktrees/issue-<N>-<slug>/`. Per the
worktree convention, the main checkout is read-only and PR work
flows through the worktree.

The release/git tools used here (`st-submit-pr`, `st-finalize-repo`,
`gh`, `git`) are **host commands** — invoke them directly without
`st-docker-run --` wrapping. See the
[`publish` skill's host-vs-container section](../publish/SKILL.md#host-vs-container-commands)
for the canonical split.

## Preflight

- Confirm a worktree+branch exists for the issue you're working on.
  If not, follow
  [`docs/development/starting-work-on-an-issue.md`](../../docs/development/starting-work-on-an-issue.md)
  before invoking this skill.
- Confirm you are inside that worktree (`pwd` should resolve to a
  path under `.worktrees/issue-<N>-<slug>/`).
- If no primary issue exists, create one immediately using
  best-effort assumptions and note them in the issue body. Do not
  ask for an issue number unless acceptance criteria are
  materially ambiguous.
- Verify `GH_TOKEN` is set in the environment. If not, **abort**
  with the install pointer.
- Locate the pull-request template at
  `.github/pull_request_template.md` if present; use its fields.
- Ensure commit-message format and AI co-authorship requirements
  are met per the commit standards (handled by `st-commit`; this
  skill does not commit).
- If `st-docker-cache` is available, run `st-docker-cache build`
  to ensure the cached dev container image is warm for validation.
  This is a no-op if the cache is already current.

## Pre-submission

1. Run the repository's canonical validation command if documented
   (typically `st-validate-local`).
2. If no canonical command exists, ask the user for the required
   validation steps.
3. If any check fails, **do not submit** the PR. Fix the failures
   and re-run validation. Loop until clean.
4. Populate the PR template fields. Required:
   - Issue linkage using `Ref #N`. **Do not use `Fixes`, `Closes`,
     or `Resolves`** — those keywords auto-close the issue on
     merge, bypassing finalization. Using `Ref` instead defers the
     *timing* of closure, not the *responsibility*: if this PR
     resolves the issue, the agent must close it explicitly after
     finalization (see [Close the issue](#close-the-issue)).
     The `block-autoclose-linkage` hook enforces the keyword ban
     mechanically.

## Submission

Submit via `st-submit-pr` from inside the worktree. The tool
constructs a standards-compliant PR body, pushes the branch, and
opens the PR. Example invocation shape:

```bash
st-submit-pr \
  --issue <N> \
  --summary "<one-line summary>" \
  --linkage Ref \
  --notes "<PR body content; pass multi-line via $(cat <file>) per the
           shell command policy in CLAUDE.md>"
```

After `st-submit-pr` returns the PR URL, **do not enable
auto-merge** and **do not attempt to merge**.

If a CI check fails due to PR metadata (e.g., missing issue
linkage), editing the PR body and re-running the workflow does
not fix it — re-runs use the original event payload. Push a new
commit to trigger a fresh workflow run.

## Wait for CI green

This step is mandatory. **Do not hand off to the user with a PR
that has red or pending checks.** Most CI failures are agent-
fixable in seconds; round-tripping through the user adds hours
of latency for nothing.

Poll the PR's required checks:

```bash
st-wait-until-green <pr-url>
```

`st-wait-until-green` blocks until all required checks complete
and exits non-zero if any required check failed.

### If checks pass

Continue to [Hand-off](#hand-off-to-the-user).

### If checks fail

Read the failure logs:

```bash
gh pr checks <pr-url> --json name,state,link \
  --jq '.[] | select(.state == "FAILURE")'
```

Then decide whether the failure is agent-fixable:

- **Agent-fixable** (lint regression, missing format, simple test
  break, etc.): fix the issue locally, commit the fix via
  `st-commit`, push, and re-poll. Loop until the checks go green
  or the failure surfaces as not-fixable.
- **Not agent-fixable** (genuine ambiguity, missing context,
  unclear requirement, infrastructure failure): hand off to the
  user with the failure captured. Do **not** hand off with a bare
  "PR ready for review" — name the failed check, the failure
  reason, and what's needed.

## Hand-off to the user

Only after CI is green, surface to the user:

- The PR URL.
- The fact that CI is green and the PR is ready for review.
- Any context the user needs to make the review call efficient
  (key files changed, decisions to validate, etc.).

After hand-off, **stop the work cycle**. Do not poll for the
merge. The user reviews, merges, and notifies the agent when
that's complete (typically just by saying "merged" or pasting
the merge confirmation).

## After the merge

When the user reports the merge — usually a short message like
"merged," "104 merged," or a paste of the merge confirmation —
run `st-finalize-repo` from inside the worktree:

```bash
cd <absolute-worktree-path>
st-finalize-repo
```

`st-finalize-repo` is worktree-aware: it switches to the target
branch, fast-forward pulls origin, deletes the merged feature
branch and its worktree, and prunes stale remote-tracking refs.

If the script raises a non-fatal error on a sibling worktree
(e.g., another agent's in-flight work with uncommitted files),
verify the develop pull and merged-branch deletion succeeded
manually with `git log --oneline -3` and `git worktree list`. Do
not force-remove sibling worktrees.

### Verify post-merge async workflows

A PR is not "done" until every async workflow triggered by the
merge has succeeded. The repository's `docs/repository-standards.md`
lists the post-merge async workflows in its "Post-merge async
workflows" section. Verify each one.

For each workflow in the table:

1. **Identify the run.** Poll until a run for the merge commit
   appears (typically under 60 seconds):

   ```bash
   gh run list --workflow <workflow>.yml --branch develop \
     --limit 1 --json conclusion,status,url --jq '.[0]'
   ```

2. **Wait for completion.** If still in progress:

   ```bash
   gh run watch --exit-status <run-id>
   ```

3. **Evaluate the result.**
   - `conclusion == "success"`: pass. Move to the next workflow.
   - `conclusion == "failure"`: **surface to the user immediately.**
     Report the workflow name, run URL, and failing step. Do not
     auto-recover or retry — a failed post-merge workflow means
     the downstream artifact (docs site, container image, etc.)
     is stale until the failure is resolved.

If the repository profile lists no post-merge async workflows,
skip this step.

## Close the issue

**This step is mandatory when the PR resolves the issue.** Using
`Ref` instead of `Fixes` defers the timing of closure, not the
responsibility. If you would have used `Fixes` or `Closes` —
because this PR completes the work the issue tracks — you must
close the issue here. The `Ref` keyword and this explicit closure
step together replace what `Fixes` used to do automatically.

After finalization and post-merge workflow verification both
succeed:

```bash
gh issue close <N> --comment "Closed after finalization. PR: <pr-url>"
```

Issue closure happens here — not at merge time — because the work
cycle is not complete until `st-finalize-repo` has reconciled
local state and post-merge workflows have succeeded. Since
auto-close keywords are banned, this explicit step is the **only
path to closure**. Skipping it leaves the issue open indefinitely.

**Exception — multi-PR issues:** If the issue's acceptance
criteria span multiple PRs and this PR is not the final one,
do not close the issue. Only close when the last PR in the
series has been finalized.

This concludes the work cycle.

## Resources

- [`docs/development/starting-work-on-an-issue.md`](../../docs/development/starting-work-on-an-issue.md)
  — issue resolution + worktree+branch creation (the predecessor
  to invoking this skill)
- [`publish` skill](../publish/SKILL.md) — covers release-PR
  workflow including the `st-merge-when-green` exception
- `docs/code-management/pull-request-workflow.md`
- `docs/code-management/commit-messages-and-authorship.md`
