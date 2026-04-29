# Alignment Review: block-agent-merge

**Date:** 2026-04-29
**Commit:** f960ac8

## Documents Reviewed

- **Intent:** `docs/specs/block-agent-merge.md`
- **Action:** `docs/plans/block-agent-merge.md`
- **Design:** none (spec serves as both intent and design)

## Source Control Conflicts

None — no conflicts with recent changes.

## Issues Reviewed

### [1] Fallback message masks tool failure

- **Category:** Design gap
- **Severity:** Minor
- **Documents:** Spec §Hook behavior step 6 vs. Plan §3a
- **Issue:** The plan's hook script included a fallback deny
  message that mimicked a policy denial when `st-check-pr-merge`
  produced no stderr output. This conflates "the tool said no"
  with "the tool couldn't run" — a fundamental distinction. Any
  yes/no API has three possible outcomes: yes, no, and "I don't
  know." The fallback should honestly report the third state.
- **Resolution:** Restructured the hook to use three-state logic.
  When `st-check-pr-merge` exits non-zero with empty stderr, the
  hook reports that the tool failed to run, not that the merge was
  denied by policy. Led directly to issue [2].

### [2] Exit code semantics conflate denial with failure

- **Category:** Design gap (flows both directions)
- **Severity:** Important
- **Documents:** Spec §Architecture vs. Plan §1a
- **Issue:** Both spec and plan originally used a binary 0/non-zero
  exit code contract for `st-check-pr-merge`. This conflates a
  definitive "no" (blocked branch) with an inability to determine
  the answer (API failure, parse failure). Callers cannot
  distinguish policy denial from tool failure, producing misleading
  diagnostics.
- **Resolution:** Adopted a three-state exit code convention:
  exit 0 = allowed, exit 1 = denied, exit 2 = unknown/failure.
  Both spec and plan updated. Filed
  [standard-tooling#373](https://github.com/wphillipmoore/standard-tooling/issues/373)
  to audit all `st-*` commands for adoption of this convention
  fleet-wide.

### [3] Test coverage thin for command chains and --repo allow path

- **Category:** Missing coverage
- **Severity:** Minor
- **Documents:** Spec §Edge cases vs. Plan §1c test table
- **Issue:** The spec requires handling of piped commands, semicolon
  chains, and `--repo` with allowed branches. The plan's test table
  covered `&&` chains and `--repo` deny path but missed semicolons,
  pipes, and `--repo` allow.
- **Resolution:** Added test rows 11 (semicolon chain), 12 (pipe),
  and 13 (`--repo` with allowed branch) to the plan's test table.

### [4] `set -e` conflicts with exit code capture

- **Category:** Contradiction (internal to plan)
- **Severity:** Important
- **Documents:** Plan §3a hook script
- **Issue:** The hook uses `set -euo pipefail` but needs to capture
  `st-check-pr-merge`'s exit code to branch on 0/1/2. The original
  `&& exit 0` / `rc=$?` pattern was subtly correct but fragile —
  future edits could easily break the `set -e` interaction.
- **Resolution:** Replaced with the idiomatic `|| rc=$?` pattern
  which is unambiguous under `set -e`.

### [5] Spec not updated to reflect three-state convention

- **Category:** Design gap (plan ahead of spec)
- **Severity:** Important
- **Documents:** Spec §Architecture, §Hook behavior, §Testing vs.
  Plan §1a, §3a
- **Issue:** After issue [2] was resolved in the plan, the spec
  still described a two-state exit code model. An implementer
  reading only the spec would get the old contract.
- **Resolution:** Updated the spec to reflect the 0/1/2 convention
  with a reference to standard-tooling#373. Updated hook behavior
  steps to distinguish exit 1 (policy denial) from exit 2 (tool
  failure). Updated testing section to test both exit codes
  separately for the hook.

## Unresolved Issues

None — all issues were addressed.

## Alignment Summary

- **Requirements:** 15 spec requirements checked, 15 covered by
  plan tasks
- **Tasks:** 12 plan tasks checked, 12 trace to spec requirements
  (3 supplementary items — issue tracking, shared helper, risk
  notes — are legitimate organizational/DRY concerns, not scope
  creep)
- **Status:** Aligned. Both documents updated to reflect all
  resolutions.
