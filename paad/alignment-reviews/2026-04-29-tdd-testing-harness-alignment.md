# Alignment Review: TDD Testing Harness Pilot

**Date:** 2026-04-29
**Commit:** 6541559

## Documents Reviewed

- **Intent:** `docs/specs/v2-tdd-testing-harness.md`
- **Action:** `docs/plans/2026-04-29-tdd-testing-harness-pilot.md`
- **Design:** none (spec serves as both intent and design)

## Source Control Conflicts

None. The spec was revised in commit `6541559` with pushback
resolutions. The plan was written on the same branch and references
the spec.

## Issues Reviewed

### [1] Provider abstraction: plan builds custom, spec says use DeepEval's

- **Category:** Design gap
- **Severity:** Important
- **Documents:** Spec "Key design decisions" vs Plan Task 4
- **Issue:** The spec said "start with DeepEval's built-in model
  abstraction." The plan builds custom `ClaudeProvider` and
  `OpenAIProvider` classes using raw SDKs. Investigation revealed
  the plan is architecturally correct: DeepEval's model abstraction
  manages the judge (GEval evaluator), not the test subject (model
  under test). The spec was imprecise about this distinction.
- **Resolution:** Updated the spec to clarify the two-model
  distinction: DeepEval manages the judge via its built-in
  abstraction; the test subject uses a lightweight custom provider
  layer. Plan's implementation is correct as-is.

### [2] Python version mismatch

- **Category:** Missing coverage
- **Severity:** Minor
- **Documents:** Spec "Python Infrastructure Bootstrap" vs Plan
  header and Task 1
- **Issue:** Spec said "3.13+", plan said "3.12+". Both were stale.
  `standard-tooling` CI builds and tests against 3.14 only.
- **Resolution:** Updated both documents to 3.14+. The upstream
  `standard-tooling` spec that still says 3.13+ needs a separate
  fix in that repo.

### [3] Plan doesn't reference standard-tooling as bootstrap template

- **Category:** Missing coverage
- **Severity:** Minor
- **Documents:** Spec "Python Infrastructure Bootstrap" vs Plan
  Task 1
- **Issue:** Spec says "clone from standard-tooling's pyproject.toml,
  Makefile, and CI workflow." Plan writes everything from scratch,
  risking convention drift (the Python version mismatch was already
  evidence of this).
- **Resolution:** Added a note to Task 1 directing the implementing
  agent to cross-check against `standard-tooling`'s pyproject.toml
  as the source of truth.

### [4] GEval threshold hardcoded without explanation

- **Category:** Out of scope (plan adds undocumented parameter)
- **Severity:** Minor
- **Documents:** Plan Task 5 vs Spec (no mention)
- **Issue:** Plan hardcodes `threshold=0.5` for GEval metrics. This
  is a significant tuning parameter that determines pass/fail
  behavior. The spec doesn't address thresholds.
- **Resolution:** Added a calibration comment to the threshold value
  in the plan. The right threshold will be discovered during pilot
  validation runs.

## Alignment Summary

- **Requirements:** 13 checked, 13 covered, 0 gaps
- **Tasks:** 7 total, 7 in scope, 0 orphaned
- **Status:** Aligned after fixes applied
