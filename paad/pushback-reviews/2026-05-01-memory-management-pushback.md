# Pushback Review: Memory Management — Human-Routed Writes

**Date:** 2026-05-01
**Spec:** docs/specs/2026-05-01-memory-management-design.md
**Commit:** 16f07d9

## Source Control Conflicts

None — no conflicts with recent changes.

## Issues Reviewed

### [1] Handoff skill already writes to memory under the current ban

- **Category:** Contradiction
- **Severity:** Serious
- **Issue:** The spec frames the exemption for user-invoked skills as forward-looking, but `/handoff stop` already writes to memory under the existing total-ban policy. The handoff skill is human-invoked by definition — the human triggers the skill, implicitly approving the write — so there is no actual collision with the human-routed model.
- **Resolution:** No reframing needed. The exemption clause is correct as written. Added explicit language that the agent must never self-invoke an exempt skill to bypass the policy — the exemption applies only when the human initiates the invocation.

### [2] No mechanical enforcement — entire model is prose-based

- **Category:** Feasibility / Omission
- **Severity:** Serious
- **Issue:** The spec's enforcement is entirely prose-based (global CLAUDE.md, MEMORY.md header, skill instructions). The hook mechanism (PreToolUse) is binary — it can only allow or block, not pause for human interaction. Since the desired behavior is "pause, propose to the human, wait for approval," a hook literally cannot implement the policy.
- **Resolution:** Withdrawn. The layered prose approach is the best available option given the hook mechanism's constraints. Three layers (global policy, point-of-write header, periodic audit) provide defense in depth. The audit skill is the backstop that catches whatever slips through, and is needed anyway because memory content goes stale.

### [3] `memory-init` path resolution is fragile and under-specified

- **Category:** Ambiguity / Feasibility
- **Severity:** Moderate
- **Issue:** The spec hand-rolled the CWD-to-slug derivation for the memory directory path. This reimplements a Claude Code internal that could change. Additionally, no handling for orphaned memory files (files exist but no MEMORY.md index).
- **Resolution:** Removed slug derivation — the skill uses whatever path Claude Code's runtime provides. Orphaned files: `memory-init` creates a header-only `MEMORY.md` and defers orphan indexing to `memory-audit`.

### [4] No definition of "outdated" for the MEMORY.md policy header

- **Category:** Ambiguity
- **Severity:** Minor
- **Issue:** The spec said to check if the header is "outdated" but provided no mechanism for determining that.
- **Resolution:** The skill carries the canonical header text and does an exact string comparison. If the text in `MEMORY.md` differs from the skill's built-in text, replace it. The skill itself is the source of truth — no version marker needed.

### [5] Fleet rollout lacks completion tracking

- **Category:** Omission
- **Severity:** Moderate
- **Issue:** With 15-20 repos, the spec provided no way to track which repos have completed the rollout steps.
- **Resolution:** Added a fleet tracking issue in `standard-tooling-plugin` with a checklist of all consuming repos, each linking to the per-repo rollout issue.

### [6] `memory-audit` staleness assessment is undefined

- **Category:** Ambiguity
- **Severity:** Moderate
- **Issue:** The audit skill says to "assess staleness" but doesn't specify whether the agent should actively verify claims against the codebase or just present content to the human.
- **Resolution:** The skill actively verifies — checks file paths exist, greps for referenced functions/patterns/conventions, and presents findings alongside the content. The human still decides the disposition.

### [7] Proactive init on repos with no memory history

- **Category:** Omission
- **Severity:** Minor
- **Issue:** Running `memory-init` on repos that have never used memory creates an otherwise empty directory and file. Running `memory-audit` on these repos is a no-op.
- **Resolution:** Keep proactive init (the cost is trivial and it prevents unguarded first writes). Skip the `memory-audit` step in rollout issues for repos with no existing memory files.

## Summary

- **Issues found:** 7
- **Issues resolved:** 7
- **Unresolved:** 0
- **Spec status:** Ready for implementation — all changes applied to spec file
