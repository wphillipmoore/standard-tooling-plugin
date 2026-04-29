# v2.0 Skill Rearchitecture — Architectural Review

**Date:** 2026-04-29
**Issue:** [#187](https://github.com/wphillipmoore/standard-tooling-plugin/issues/187)
**Scope:** All six plugin skills reviewed against `superpowers:writing-skills` methodology

## Context

The plugin's six skills (`pr-workflow`, `publish`, `dependency-update`,
`deprecation-triage`, `project-issue`, `summarize`) were developed through
ad-hoc trial and error without the structured methodology defined in
`superpowers:writing-skills`. This document captures the initial
architectural review that identified systematic gaps and produced the
prioritized recommendations in issue #187.

## Skills Inventory

| Skill | ~Words | Type | Summary |
|---|---|---|---|
| `publish` | 2,200+ | Workflow/technique | 7-phase release lifecycle |
| `pr-workflow` | 1,500+ | Workflow/technique | PR submission through merge and cleanup |
| `dependency-update` | 1,000+ | Workflow/technique | Repeatable dependency update process |
| `project-issue` | 700+ | Workflow/technique | Guided GitHub issue creation |
| `summarize` | 500 | Workflow/technique | Multi-mode structured summarization |
| `deprecation-triage` | 400 | Workflow/technique | Deprecation warning triage and tracking |

## Finding 1: Descriptions — Every Skill Violates the CSO Anti-Pattern

The writing-skills guide explicitly warns that when a description summarizes
the skill's workflow, Claude may follow the description instead of reading the
full skill content.

All six descriptions summarize workflow rather than describing triggering
conditions:

| Skill | Current Description | Problem |
|---|---|---|
| `pr-workflow` | "Submit a pull request, wait for CI to go green, and hand off to the user for review and merge." | Agent may follow this 3-step summary and skip the full skill — missing `Ref` vs `Fixes` policy, post-merge verification, explicit issue closure |
| `publish` | "Drive the end-to-end publish workflow..." | Agent may wing it rather than following the 7-phase procedure |
| `project-issue` | "Create a well-structured GitHub issue by collecting required attributes through guided questions." | Process summary, not trigger |
| `dependency-update` | "Run the dependency update workflow with validation, failure handling, and anchor record requirements." | Process summary |
| `deprecation-triage` | "Triage deprecation warnings into a consistent workflow..." | Process summary |
| `summarize` | "Multi-mode summarization for decisions, operations, or stream-of-consciousness capture. Use when..." | Leads with process summary; the "Use when" is buried second |

Descriptions should start with "Use when..." and describe only triggering
conditions. Examples:

- `pr-workflow`: "Use when a feature branch is ready for review and needs to be submitted, monitored through CI, and handed off for merge. Runs from inside the issue's worktree."
- `publish`: "Use when cutting a release or deploying documentation, after all feature work for the version is merged to develop."
- `deprecation-triage`: "Use when deprecation warnings surface in test output, logs, or dependency changelogs — whether detected by the PostToolUse hook or noticed manually."

The `pr-workflow` case is the most dangerous. Its description is a three-step
recipe. An agent under time pressure will follow "submit, wait, hand off" and
skip the 275-line skill — missing the `Ref`-only linkage rule,
`st-finalize-repo`, post-merge workflow verification, and explicit issue
closure.

## Finding 2: No Evidence of TDD Testing

The writing-skills iron law: "No skill without a failing test first."

None of the skills show artifacts of the RED-GREEN-REFACTOR cycle:

- No rationalization tables — what excuses do agents use to skip steps?
- No red flags lists — self-check signals that you're about to violate the skill
- No common mistakes sections (except `publish`'s host-vs-container, which is the closest thing)

This matters most for discipline-enforcing aspects. The `pr-workflow` skill has
several critical policies ("don't auto-merge," "use Ref not Fixes," "close the
issue explicitly") that agents routinely violate. Without pressure-tested
rationalization counters, these read as rules an agent acknowledges and then
quietly works around.

For example, `pr-workflow` says "do not enable auto-merge" three times.
Repetition suggests this has been a real problem — but the skill doesn't
capture why agents do it or provide explicit counters.

With TDD: run a subagent through a PR scenario without the skill, document that
it auto-merges or skips issue closure or uses `Fixes #N`, then write the skill
to address those specific failure modes with rationalization tables.

## Finding 3: Token Efficiency — `publish` is a Runbook, Not a Skill

| Skill | ~Words | Budget |
|---|---|---|
| `publish` | 2,200+ | <500 |
| `pr-workflow` | 1,500+ | <500 |
| `dependency-update` | 1,000+ | <500 |
| `project-issue` | 700+ | <500 |
| `summarize` | 500 | ~500 |
| `deprecation-triage` | 400 | <500 |

Options for `publish`:

- **Decompose**: Phase 1-4 (release mechanics) as one skill, Phase 5 (already
  a separate skill), Phase 6-7 (close and hand-off) as part of pr-workflow's
  lifecycle
- **Compress**: Move host-vs-container (referenced by 3 other skills) into its
  own reference, cutting ~500 words
- **Restructure**: Keep monolithic but move verbose sections to supporting files

## Finding 4: Host-vs-Container is Load-Bearing Documentation in the Wrong Place

The canonical host-vs-container split lives in `publish/SKILL.md` and is
cross-referenced by three other skills. Problems:

1. **Loading cost**: Any agent needing the rule must either load `publish`
   (2,200 words) or already know it. Three skills say "see publish for the
   canonical split."
2. **Conceptual coupling**: The split is infrastructure knowledge, not
   publish-specific. It belongs in a standalone reference.

## Finding 5: Duplication Across Skills

Several policies are explained in multiple places:

- **`Ref` vs `Fixes` linkage**: Explained in detail in `pr-workflow` and
  referenced in `publish`. Rationale given twice.
- **GH_TOKEN check**: Four skills independently check for it.
- **`st-finalize-repo` behavior**: Described in both `pr-workflow` and
  `publish`.
- **"Humans merge feature PRs" policy**: Stated in `pr-workflow` and restated
  in `publish`.

A shared policy reference or single canonical skill that others cite would
reduce token cost and eliminate drift risk.

## Finding 6: Missing "When NOT to Use" Guidance

Only `publish` has an exclusion ("not applicable to application repositories").
Others would benefit:

- `pr-workflow`: Not for release-workflow PRs (those use `publish` directly).
  Stated but buried, not in a "When to Use" block.
- `dependency-update`: Not clear whether security hotfixes bypass the chore
  branch convention.
- `project-issue`: Not clear whether cross-repo project-level tracking issues
  are in scope.

## Finding 7: No Decision Flowcharts Where They'd Help

None of the skills use flowcharts. Several have non-obvious decision points:

- `deprecation-triage`: Branching decision tree (existing issue? code-only fix
  possible? defer? suppress?)
- `pr-workflow`: CI failure triage (fixable vs. not-fixable)
- `publish`: Mode selection (library-release vs. docs-only) and Phase 3's
  issue-linkage repair logic

## Finding 8: Structural Homogeneity

All six skills are operational workflows (technique type). The skill set is
missing:

- **Reference skills**: Host-vs-container split, commit/PR standards, worktree
  convention
- **Pattern skills**: "When to defer vs. fix now" (used by deprecation-triage
  and dependency-update), "failure escalation" (used by publish, pr-workflow,
  dependency-update)

Extracting these would reduce workflow skill word counts and make shared
judgment calls explicit.

## Recommendations (Prioritized)

1. **Rewrite all six descriptions** — start with "Use when...", triggering
   conditions only, no workflow summaries
2. **Pressure-test discipline-enforcing aspects** with subagent TDD scenarios;
   add rationalization tables and red flags
3. **Extract host-vs-container** into a standalone reference skill or doc
4. **Consolidate duplicated policies** (Ref linkage, GH_TOKEN, finalize-repo,
   merge policy) into shared references
5. **Add decision flowcharts** to deprecation-triage and pr-workflow CI-failure
   triage
6. **Compress publish** — decompose or move verbose sections to supporting files
7. **Add "Common Mistakes" and "When NOT to use"** sections, especially to
   pr-workflow and publish
