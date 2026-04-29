# Pushback Review: block-agent-merge

**Date:** 2026-04-29
**Spec:** `docs/specs/block-agent-merge.md`
**Commit:** 388ea7a (pre-pushback version)

## Source Control Conflicts

None — no conflicts with recent changes.

## Issues Reviewed

### [1] GitHub API failure default-deny without error surfacing

- **Category:** Omissions
- **Severity:** Serious
- **Issue:** The spec said `st-check-pr-merge` denies by default on
  API failure but did not specify whether the error message is
  surfaced or swallowed. A silent deny leaves the user unable to
  diagnose the problem. `GH_TOKEN` is already required and things
  fail badly without it — any time we can surface an error message
  rather than hide it, that is the right call.
- **Resolution:** Accepted recommendation. Updated spec to require
  `st-check-pr-merge` to surface the full error message on stderr
  (not hide it) so the user can diagnose the failure.

### [2] st-merge-when-green bypass path

- **Category:** Omissions
- **Severity:** Serious
- **Issue:** `st-merge-when-green` calls `gh pr merge` via Python
  subprocess, not through the Bash tool boundary, so the hook
  cannot intercept it. An agent could call
  `st-merge-when-green <feature-pr-url>` and bypass the gate
  entirely.
- **Resolution:** Option 3 selected: add a branch-name sanity check
  inside `st-merge-when-green` itself. If the target branch does
  not match `release/*` or `chore/bump-version-*`, the script
  refuses to merge and exits non-zero. This is defense-in-depth
  that closes the subprocess bypass without adding a second hook or
  a separate wrapper.

### [3] PR reference extraction ambiguity

- **Category:** Ambiguity
- **Severity:** Moderate
- **Issue:** The hook script would need to extract a PR reference
  from arbitrary `gh pr merge` invocations with varying flag
  positions, URL formats, `--repo` arguments, and pipeline chains.
  Doing this in shell is fragile and error-prone.
- **Resolution:** Delegate all PR reference parsing to a new
  `st-check-pr-merge` host command in standard-tooling. This
  follows the foundational architectural decision: mechanical tasks
  belong in Python `st-*` scripts, not in shell where agents or
  contributors get creative with parsing. The hook detects the
  command pattern and delegates; all parsing, API calls, and branch
  verification happen in Python. Two-repo implementation split:
  `st-check-pr-merge` and `st-merge-when-green` changes in
  standard-tooling; hook script and registration in
  standard-tooling-plugin.

### [4] Cross-repo PR handling

- **Category:** Omissions
- **Severity:** Minor
- **Issue:** The agent might merge a PR in a different repo via
  `gh pr merge --repo owner/other-repo 42`. The spec did not
  address whether the hook applies cross-repo.
- **Resolution:** Accepted recommendation to defer. The current
  scope covers PRs in the local repo. If cross-repo merge becomes
  a problem, it will be caught and addressed then — too small a
  corner case to over-engineer now. (Note: `st-check-pr-merge`
  was later scoped to handle `--repo` extraction, so this is
  partially covered.)

### [5] gh pr review --approve scope

- **Category:** Scope imbalance
- **Severity:** Minor
- **Issue:** The spec blocks `gh pr review --approve` but does not
  address softer approval patterns like `gh pr review --comment`
  with LGTM-like text.
- **Resolution:** Accepted recommendation. Only `--approve` has
  mechanical effect on branch protection gates. Soft approval
  patterns are not worth blocking — current setup is a team of one
  plus agents, and this will be revisited if velocity increases and
  the pattern becomes a real risk.

## Unresolved Issues

None — all issues were addressed.

## Summary

- **Issues found:** 5
- **Issues resolved:** 5
- **Unresolved:** 0
- **Spec status:** Ready for implementation
