# Pushback Review: v2-tdd-testing-harness

**Date:** 2026-04-29
**Spec:** docs/specs/v2-tdd-testing-harness.md
**Commit:** 510f6a8

## Source Control Conflicts

None. PR #188 (v2 rearchitecture spec) merged to develop and is the
parent initiative for this spec. The `deprecation-triage` skill
exists at 346 words. No `tests/` directory or `pyproject.toml`
exists, which matches the spec's intent to build from scratch.

## Scope Shape

**Cohesion:** All features serve one goal (TDD infrastructure for
skills). No split needed.

**Size:** Document is long but pilot implementation is small (6
files). The bulk is architecture documentation for the full system,
with the pilot explicitly scoped down.

## Issues Reviewed

### [1] DeepEval named in goal but absent from architecture

- **Category:** Contradiction
- **Severity:** Serious
- **Issue:** The goal says "pytest-based testing harness using
  DeepEval" and the pilot lists `deepeval` as a dependency, but the
  entire architecture (evaluation model, scenario format, test
  runner, result storage) makes zero reference to DeepEval. The
  three evaluation layers are entirely custom. DeepEval would be a
  dead dependency as designed.
- **Resolution:** DeepEval was a deliberate framework choice (Python
  ecosystem, CI reuse, vs. TypeScript alternatives like promptfoo)
  that was insufficiently captured in the spec after review
  feedback. The spec's evaluation layers should be implemented on
  top of DeepEval's primitives (`LLMTestCase`, `GEval`, metric
  APIs). Update the spec to make DeepEval's role as the
  implementation framework explicit throughout, not just a name-drop
  in the goal.

### [2] String matching evaluation is brittle

- **Category:** Feasibility
- **Severity:** Serious
- **Issue:** The `must-contain`/`must-not-contain`/`fail.any-contain`
  string matching approach produces false passes and failures.
  Single-letter markers ("A", "B", "C") match everywhere. Negation
  defeats `must-not-contain` ("I would not suppress" fails on
  "suppress"). This is exactly the problem DeepEval's `GEval` metric
  solves via semantic evaluation.
- **Resolution:** Make DeepEval's `GEval` the primary evaluation
  mechanism. The existing `behavioral` field already reads like a
  `GEval` rubric. String markers are dropped as the primary
  evaluation gate. The scenario YAML evaluation fields will be
  restructured around DeepEval's metric inputs.

### [3] Test environment diverges from real agent execution

- **Category:** Feasibility
- **Severity:** Moderate
- **Issue:** Scenarios inject skill content into a bare system prompt
  via template substitution. In real usage, skills load through the
  Skill tool as part of a larger context (system prompt, CLAUDE.md,
  other skills, conversation history, tool definitions). Tests may
  pass in isolation but fail in practice.
- **Resolution:** Accept divergence for the pilot and document it as
  a known limitation. The spec will capture a concrete future
  milestone: an integration test repo that exercises skills in
  realistic deployment context (real PRs, real CI, simulated
  failures). This is the eventual goal, not a "nice to have."

### [4] Provider abstraction is premature for a Claude-only pilot

- **Category:** Scope imbalance
- **Severity:** Moderate
- **Issue:** The spec designs a full custom provider abstraction but
  the pilot is Claude-only.
- **Resolution:** Provider flexibility is elevated from "future
  extension" to a core architectural requirement. Motivation: cost
  (local LLMs for iteration, API for validation), imminent local LLM
  capability (hardware arriving within weeks), and deliberate
  provider-agnostic strategy. The implementation should start with
  DeepEval's built-in model abstraction and only build a custom
  layer if DeepEval cannot reach the local LLM setup. The pilot's
  "Claude only" exclusion is removed; the pilot should validate at
  least local LLM connectivity.

### [5] The `--no-skill` RED phase proves the obvious

- **Category:** Ambiguity
- **Severity:** Moderate
- **Issue:** The RED phase runs `--no-skill` (strips all skill
  content), proving "an agent with no guidance fails under
  pressure." This is expected and uninformative. The valuable RED
  test is: "the agent has the current skill and still fails" —
  revealing a gap in the skill itself.
- **Resolution:** Reframe the RED/GREEN cycle. The primary RED test
  runs with the skill loaded and expects failure on a new scenario
  targeting a gap. `--no-skill` becomes a scenario validation tool
  (confirming the scenario creates real pressure), run once when
  authoring a new scenario. The spec will clearly separate these two
  uses.

### [6] No Python infrastructure exists in this repo

- **Category:** Omissions
- **Severity:** Moderate
- **Issue:** The spec assumes `pyproject.toml` updates but the repo
  has no Python infrastructure (no pyproject.toml, no setup.py, no
  venv convention, no Python in CI). Adding pytest makes this a
  hybrid repo.
- **Resolution:** Add a bootstrap section to the spec. Python
  infrastructure follows `standard-tooling` conventions (same Python
  version, same venv/Makefile patterns, same CI shape). The
  implementing agent clones from `standard-tooling`'s setup.

### [7] Cycle termination criteria are unfalsifiable

- **Category:** Ambiguity
- **Severity:** Minor
- **Issue:** The spec says the cycle terminates when "no new
  rationalizations emerge from manual review." This is unfalsifiable
  given LLM non-determinism. Run 100 may surface patterns runs 1-99
  did not.
- **Resolution:** Name the non-determinism honestly. The
  rationalization feedback loop is asymptotic, not convergent:
  diminishing returns, never zero. The stopping rule is economic
  (cost of finding the next rationalization vs. value of countering
  it), not scientific. The spec will define practical thresholds:
  runs per scenario, pass-rate gates for CI, and explicit
  acknowledgment that CI cannot demand perfection from
  non-deterministic tests.

### [8] Result storage format is overspecified

- **Category:** Scope imbalance
- **Severity:** Minor
- **Issue:** The spec defines a detailed YAML schema for gitignored
  ephemeral files. With DeepEval adoption, its native reporting
  replaces custom result storage.
- **Resolution:** Remove the custom result storage schema. Results
  use DeepEval's native reporting, supplemented by raw responses
  saved for human review during REFACTOR phases. Let the format
  emerge from implementation.

### [9] Scenario YAML format needs rethinking

- **Category:** Ambiguity
- **Severity:** Minor
- **Issue:** The scenario YAML evaluation fields (`must-contain`,
  `must-not-contain`, `fail.any-contain`) were designed around
  custom string matching. With DeepEval adoption and string marker
  removal, these fields need restructuring.
- **Resolution:** Keep metadata and prompt fields (`name`, `skill`,
  `type`, `pressures`, `system`, `prompt`, `baseline`). Evaluation
  fields will be restructured around DeepEval's `LLMTestCase` and
  `GEval` metric inputs. The `behavioral` field becomes the central
  evaluation definition. The exact format will be discovered during
  implementation rather than prescribed now.

## Summary

- **Issues found:** 9
- **Issues resolved:** 9
- **Unresolved:** 0
- **Spec status:** Needs revision — all resolutions accepted, spec
  update to follow in the same commit
