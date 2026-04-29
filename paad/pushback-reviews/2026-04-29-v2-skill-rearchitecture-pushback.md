# Pushback Review: v2.0 Skill Rearchitecture

**Date:** 2026-04-29
**Spec:** [#187](https://github.com/wphillipmoore/standard-tooling-plugin/issues/187) and `docs/specs/v2-skill-rearchitecture.md`
**Commit:** 1e999eb (HEAD of develop at review time)

## Source Control Conflicts

None — no conflicts with recent changes. Three recent commits validated the
analysis rather than contradicting it:

| Commit | Date | Relevance |
|---|---|---|
| `4787974` | Apr 28 | Strengthened issue-closure step because agents were skipping it — validates finding #2 |
| `e04eec5` | Apr 29 | Added `block-agent-merge` PreToolUse hook — mechanically enforces no-auto-merge policy |
| `50c060b` | Apr 29 | Added `st-wait-until-green` to pr-workflow and host tools list |

## Issues Reviewed

### [1] Token budget may not apply to on-demand workflow runbooks

- **Category:** Feasibility
- **Severity:** Serious
- **Issue:** The spec adopts the writing-skills guide's <500 word budget as the
  target for all skills. But that budget targets personal skills that load
  frequently. Plugin workflow skills are on-demand — they load once per
  invocation (e.g., `publish` loads once per release cycle). Compressing
  `publish` to <500 words would require losing critical instructions or
  splitting into multiple skills that agents must invoke in sequence.
- **Resolution:** Combine two approaches: (1) Tiered budgets by loading
  frequency — always-loaded <200 words, frequently-loaded <500 words, on-demand
  workflow skills minimize redundancy but no hard cap. (2) Supporting files for
  edge cases — SKILL.md contains decision logic and "when to read more"
  pointers, supporting files stay out of context until triggered. Example:
  `publish` keeps Phase 4's cross-repo docker verification in a supporting file
  gated by "When publishing `standard-tooling`, read `docker-verification.md`."

### [2] No distinction between hook-enforced and documentation-enforced policies

- **Category:** Omission
- **Severity:** Serious
- **Issue:** The spec treats all discipline problems as documentation problems.
  But hooks already mechanically enforce some policies (`block-agent-merge`
  prevents `gh pr merge` on non-release PRs; `block-autoclose-linkage` prevents
  `Fixes`/`Closes` keywords). The heredoc blocker is the proof case: prose
  telling agents not to use heredocs has never been respected — the hook catches
  it every time and agents self-correct. Documentation that duplicates hook
  enforcement is ignored, unmaintainable, and adds context cost.
- **Resolution:** Hook-enforced policies get no skill prose — delete existing
  duplicates. The hook is the enforcement; the agent bumps into the gate, reads
  the error message, and self-corrects. TDD pressure testing focuses exclusively
  on judgment-dependent behaviors that have no hook backstop. Audit each
  discipline rule and classify as hook-enforced or judgment-dependent.

### [3] No testing maintenance or CI story

- **Category:** Omission
- **Severity:** Serious
- **Issue:** The spec requires TDD pressure testing but doesn't address where
  test scenarios live, how they're re-run, or how regressions are detected.
  The thesis is "treat skills like code" — code without CI is just code that
  used to work.
- **Resolution:** Adopt whatever conventions the writing-skills guide
  establishes for test artifact storage and format. Each v2.0 skill ships with
  its pressure scenarios alongside it. CI automation for skill testing is in
  scope but will be designed as the testing conventions take shape — not
  specified upfront. This is greenfield: no existing conventions to preserve.
  The plugin may need its own repository profile type (distinct from library,
  tooling, documentation) since it publishes skills, not packages.

### [4] Recommendation efforts vary from 30 minutes to weeks

- **Category:** Scope imbalance
- **Severity:** Moderate
- **Issue:** The seven recommendations range from 1-2 hours (rewrite
  descriptions) to 1-2+ weeks (TDD pressure testing). More importantly, the
  writing-skills iron law says you can't edit a skill without testing it first
  — so recommendations 1, 3, 4, 5, 6, and 7 all technically depend on
  recommendation #2 (establishing the testing methodology).
- **Resolution:** Reorder for implementation: testing methodology first. Pilot
  on `deprecation-triage` (smallest, simplest skill). Then apply the
  methodology to each remaining skill, giving each its full v2.0 treatment
  (description, structure, compression, testing) in one pass rather than
  sweeping one recommendation across all six skills. Build the machine that
  builds the skills — the machinery is more important than the skills
  themselves.

### [5] No migration plan from v1 to v2

- **Category:** Omission
- **Severity:** Moderate
- **Issue:** Six skills are currently deployed and consumed. The spec doesn't
  address how to transition without breaking consuming repos mid-transition,
  or what happens when v2 skills cross-reference v1 skills.
- **Resolution:** Rename skills as part of v2.0 — new names give clean
  coexistence. Old and new run in parallel during development. Cutover is a
  manual decision after the new skill passes TDD tests and demonstrates parity.
  The single-operator model allows this flexibility. No formal migration plan
  needed.

### [6] "Compress publish" has multiple conflicting options

- **Category:** Ambiguity
- **Severity:** Moderate
- **Issue:** Recommendation #6 lists three options (decompose, compress,
  restructure) without choosing. These have very different implications for
  agent invocation patterns.
- **Resolution:** Defer to the publish skill's sub-issue. Extracting
  host-vs-container to a shared reference (recommendation #3) and removing
  hook-enforced prose (Issue 2 resolution) will reduce publish's word count
  significantly before any structural decision is needed. The right answer
  depends on what's left after those reductions.

### [7] Host-vs-container extraction destination unclear

- **Category:** Ambiguity
- **Severity:** Minor
- **Issue:** Recommendation #3 says "standalone reference skill or doc" but
  doesn't choose. A reference skill is discoverable but adds context cost.
  A shared doc has zero discovery overhead but depends on referring skills.
- **Resolution:** Shared doc, referenced by path from skills that need it. The
  host/container split only matters during workflow execution — agents are
  always inside a skill when they need it. May become unnecessary as tools
  increasingly absorb the host/container decision-making. Revisit during the
  relevant sub-issue.

## Unresolved Issues

None — all issues were addressed.

## Summary

- **Issues found:** 7
- **Issues resolved:** 7
- **Unresolved:** 0
- **Spec status:** Ready for planning after resolutions are applied to the issue
