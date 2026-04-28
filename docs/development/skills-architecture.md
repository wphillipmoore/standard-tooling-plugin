# Skills architecture — audit and rationalization

This document captures a deliberate, process-first design for the
skills exposed by this plugin. It exists because the catalog grew
emergently — `branch-workflow` → `pr-workflow` → `publish` →
`dependency-update` happens to compose, but no one designed it as
a chain. Several skills predate the architectural changes shipped
in v1.4.3 / v1.4.4 (host-vs-container split, managed-repo gating,
worktree convention, plugin-update sequence).

The audit is deliberate: define the actual development+deployment
process first, then map it to skills. Tracking issue:
[#114](https://github.com/wphillipmoore/standard-tooling-plugin/issues/114).

## Part 1 — Process map

The end-to-end process spans four distinct lifecycles. Each has
its own cadence and entry point. Skills should encapsulate phases
within a lifecycle and surface explicit hand-offs across lifecycles.

### Lifecycle A: Issue lifecycle

Cadence: continuous. Trigger: a need surfaces (a bug observed, a
feature requested, a deprecation warning, a release follow-up).

| Phase | Purpose | Hand-off |
|---|---|---|
| A1. File a structured issue | Capture the need with all required fields, classify, prioritize, link to a project | → B1 (when picked up for work) |
| A2. Triage incoming signals | Specific signal sources (deprecation warnings, CI failures, etc.) feed into A1 with pre-filled context | → A1 |

### Lifecycle B: Work cycle

Cadence: per-issue, from start of work through merge. Trigger: an
agent or human picks up an issue.

| Phase | Purpose | Hand-off |
|---|---|---|
| B1. Set up workspace | Resolve issue → branch name → **worktree** on a feature branch tied to the issue. One worktree per issue, never on `develop`/`main`. | → B2 |
| B2. Develop | Edit, validate (`st-validate-local`), iterate, commit (`st-commit`). Multiple commits OK. | → B3 |
| B3. Submit | Push, create PR via `st-submit-pr`, link issue with `Fixes`/`Closes`/`Resolves`/`Ref`. Wait for CI green. **Human reviews and merges feature/bugfix PRs.** | → B4 (after merge) |
| B4. Finalize | `st-finalize-repo`: pull develop, delete merged feature branch, prune worktrees and remotes. | → exit work cycle |

### Lifecycle C: Release cycle

Cadence: periodic (per maintainer's tempo). Trigger: enough merged
work on `develop` to justify a release.

| Phase | Purpose | Hand-off |
|---|---|---|
| C1. Prepare release | Open release tracking issue. Run `st-prepare-release` (host-direct). Creates release branch + PR to `main` + changelog. | → C2 |
| C2. Merge release PR | `st-merge-when-green` polls CI and merges (the release-workflow exception to "humans merge human PRs"). | → C3 |
| C3. Merge bump PR | `publish.yml` opens a `chore/bump-version-<next>` PR. `st-merge-when-green` it. | → C4 (parallel with publish.yml's slow async work) |
| C4. Confirm publish | Wait for `publish.yml` on `main` to succeed. Verify tag, develop tag, GitHub Release, package artifact, **`docs.yml`** completion (#84). | → C5 |
| C5. Dependency refresh | Optional: Branch off develop, sweep dependencies, validate, submit via B-cycle (bare or via `dependency-update`). | → C6 |
| C6. Close & finalize | Close the tracking issue with summary (#83). `st-finalize-repo`. **Tell user to run `/plugin marketplace update` → `/plugin update` → `/reload-plugins`** (#105). | → exit release cycle |

### Lifecycle D: Cross-cutting

Always available, not lifecycle-bound:

- **Summarization** — capture decisions, operations, or
  stream-of-consciousness in canonical structured form.

### Hand-offs that need to be explicit

The seams between phases are where skills fail today:

1. **A1 → B1**: When `project-issue` creates an issue, the natural
   next step is `branch-workflow`. Today the user invokes them
   separately.
2. **B3 → B4**: After merge, `st-finalize-repo` runs. PR-workflow
   says this; agents sometimes forget.
3. **B4 → A1 (cross-repo)**: Sub-issues created by `branch-workflow`
   tie back to the parent issue's project. Hand-off only happens
   correctly because `branch-workflow` is verbose about it.
4. **C1 → C2 → C3 → C4**: The release skill drives all four
   internally. The seam with B-cycle (people doing B-work while
   release is in flight) is not protected.
5. **C5 → B-cycle**: Phase 5 of publish says "submit via
   pr-workflow" — that's a chain the audit needs to either
   formalize or remove.
6. **C6 → consumers**: The post-publish `/reload-plugins`
   instruction (#105) is the producer-to-consumer hand-off the
   release skill currently does not surface.
7. **A2 (deprecation) → A1**: The `detect-deprecation-warnings`
   PostToolUse hook fires; the agent should invoke
   `deprecation-triage`. The hook→skill seam is implicit.

## Part 2 — Skills inventory

For each skill, what it does today, what's changed since it was
last meaningfully updated, runnability, status, and which open
issues it folds in.

### branch-workflow

**What it does today.** Resolves an issue (repo URL, project URL,
or number), creates sub-issues for cross-repo work, checks for
existing branches, creates a new `feature|bugfix|hotfix` branch
named `<type>/<N>-<slug>`, pushes it.

**What's changed since.**

- The worktree convention (every branch lives in
  `.worktrees/issue-<N>-<slug>/`) is now policy. The skill still
  uses `git checkout -b` + `git push -u origin`, which fights
  the convention.
- Host-vs-container framing intro (#96) is outdated — claims
  "almost all commands run inside the dev container," contradicted
  by the body which correctly invokes `gh` host-direct.
- Extensive sub-issue / project-resolution logic is unchanged and
  works correctly.

**Slash-command runnability.** Partial. A user can type
`/standard-tooling:branch-workflow` with an issue reference, but
the result is a non-worktree branch — incompatible with how
parallel work has to flow under the worktree convention. Cold-call
needs the worktree-aware flow before this is fully runnable.

**Status (audit): MAJOR REWRITE.**

**Updated decision (post-audit, 2026-04-27): ELIMINATED.** The
user pushed back on whether this skill earns its independent
existence — it was rarely invoked as a slash-command, and its
substantive content is mostly agent-instruction reference. The
skill has been removed; the substance now lives at
[`docs/development/starting-work-on-an-issue.md`](starting-work-on-an-issue.md),
referenced from `CLAUDE.md` and `pr-workflow`'s preflight. Catalog
gets one smaller; the agent reference lives where it's
consulted.

**Resolved:**
[#55](https://github.com/wphillipmoore/standard-tooling-plugin/issues/55).

### pr-workflow

**What it does today.** Pre-submission validation, push, create PR,
**enable auto-merge**, finalize via `st-finalize-repo`.

**What's changed since.**

- Auto-merge was disabled fleet-wide. Current policy: humans review
  and merge feature/bugfix PRs; only release-workflow PRs get
  agent-merged via `st-merge-when-green`. **The skill's
  "Enable auto-merge immediately" step is wrong.**
- No worktree-convention awareness: doesn't acknowledge that the
  branch lives in `.worktrees/<...>/`, doesn't drive PR creation
  or finalization from that directory.
- No CI-green-wait notification gating (#85): skill returns control
  to the user after submission without indicating CI status.
- Submission step says "Push and create the PR" without naming
  `st-submit-pr`. Indirection that opens the door to bypass.
- Host-vs-container framing intro outdated (same as
  `branch-workflow`).
- Finalization step was patched in
  [PR #97](https://github.com/wphillipmoore/standard-tooling-plugin/pull/97)
  to drop the `st-docker-run --` prefix; the rest is stale.

**Slash-command runnability.** No. The skill's current text would
have an agent enable auto-merge — directly violating the current
"humans merge" policy. Cannot be cold-invoked without an immediate
correction from the user.

**Status (audit): MAJOR REWRITE.**

**Status (post-audit): COMPLETE.** Rewritten in this PR series
(step 2 of the attack order). New scope: submit + wait for CI
green + hand off to user; finalization is a "after the merge"
follow-on triggered by the user's merge confirmation. The
obsolete `stop-guard-finalization.sh` Stop hook (which would
have fired on every correct exit under the new posture) was
deleted as part of the same change. The catalog still contains
`pr-workflow`; only its scope shifted.

**Resolved:**
[#56](https://github.com/wphillipmoore/standard-tooling-plugin/issues/56),
[#85](https://github.com/wphillipmoore/standard-tooling-plugin/issues/85).

### publish

**What it does today.** Drives the full release cycle (Phases 1–6)
for library/tooling repos and a docs-only mode for documentation
repos. Includes preflight, version override, failure handling,
and dependency-update hand-off.

**What's changed since.** The host-vs-container split landed in
[PR #97](https://github.com/wphillipmoore/standard-tooling-plugin/pull/97);
that section is current. Outstanding issues:

- **Phase 6 doesn't auto-close the tracking issue** with a phase
  summary (#83). Today the agent does this manually if it
  remembers — cf. the v1.4.3 and v1.4.4 release tracking issues
  this session.
- **Phase 4 doesn't sanity-check `docs.yml`** completion (#84).
  Only verifies `publish.yml`. The docs deploy is a separate
  workflow that can fail independently.
- **No post-publish reload-plugins step** (#105). The release
  isn't "done" from the consumer's perspective until consumers
  run the three-step refresh — and the skill doesn't tell the
  agent to surface this.
- **Phase 5 dependency refresh** is currently described as "submit
  via `pr-workflow`" — a brittle chain when `pr-workflow` is itself
  in rewrite.

**Slash-command runnability.** Yes for the happy path (the v1.4.3
and v1.4.4 releases this session ran cleanly under it). Three
gaps above are tracked patches, not blocking.

**Status: PATCHES.**

**Folds in:**
[#83](https://github.com/wphillipmoore/standard-tooling-plugin/issues/83),
[#84](https://github.com/wphillipmoore/standard-tooling-plugin/issues/84),
[#105](https://github.com/wphillipmoore/standard-tooling-plugin/issues/105).

### dependency-update

**What it does today.** Lists six high-level steps (collect signals,
update, regenerate, validate, submit PR, handle failures via
anchored records). Mostly references external docs.

**What's changed since.** The host-vs-container split affects
which validators the workflow invokes. The skill predates
`st-validate-local` being canonical.

**Slash-command runnability.** No. The skill is too thin to drive a
session — it doesn't say *how* to update Python deps vs. CI action
versions vs. doc-toolchain pins. Each category needs its own
concrete commands.

**Status: REWRITE / EXPANSION.** The skill needs to actually
encode what to run for each dependency category named in the
`publish` skill's Phase 5 ("Dependency update categories"). Right
now it documents a process by reference; it should drive it.

**Folds in:** none currently filed; the audit surfaces this.

### deprecation-triage

**What it does today.** Defines a triage workflow for deprecation
warnings: search for existing issue, defer-or-fix decision,
suppression rules, issue template.

**What's changed since.** The
`detect-deprecation-warnings.sh` PostToolUse hook surfaces
warnings into agent context. The hook→skill seam is implicit; no
explicit pointer in either direction. Otherwise unchanged.

**Slash-command runnability.** Yes for the core triage flow when
invoked with a warning in hand.

**Status: MINOR POLISH.** Make the hook→skill seam explicit (a
sentence in the skill's "When to use," and a corresponding
mention in the hook's docstring or hooks reference doc).

**Folds in:** none currently filed.

### project-issue

**What it does today.** Walks the user through structured issue
creation (project, repo, type, priority, work type, summary,
problem/goal, acceptance, validation), then files via `gh issue
create`, adds to the project, sets fields.

**What's changed since.** Same outdated host/container framing
as the other skills (the `gh` and `st-*` commands in the body are
already correct host-direct invocations after #97; only the
intro is wrong). Otherwise unchanged.

**Slash-command runnability.** Yes. This is the skill that has
held up best.

**Status: FRAMING PATCH.** Update the "Tooling" intro section to
match the host/container split.

**Folds in:** none currently filed.

### summarize

**What it does today.** Three modes: `decisions`, `operations`,
`soc`. Each has a structured output template.

**What's changed since.**
[#58](https://github.com/wphillipmoore/standard-tooling-plugin/issues/58):
unclear relationship with a project-local `soc-capture` skill in
`the-infrastructure-mindset`. Per the issue body, the user's
primary use case is the SOC voice→text→article pipeline; decisions
and operations modes may be unused.

**Slash-command runnability.** Yes for SOC mode (the load-bearing
use case). Decisions and operations modes are functional but
unused.

**Status: INVESTIGATE + DECIDE.** The candidate outcomes in #58:

- **A.** Keep all three modes; retire project-local `soc-capture`.
- **B.** Split SOC out into a dedicated skill.
- **C.** Trim — delete unused modes.
- **D.** Project-local `soc-capture` stays canonical; this skill
  serves a different purpose.

This is a small skill; the investigation belongs to its own
focused PR.

**Folds in:**
[#58](https://github.com/wphillipmoore/standard-tooling-plugin/issues/58).

## Part 3 — Coverage gaps

Phases or hand-offs the current catalog doesn't cover.

### Gap 1 — B2 (develop loop)

There is no skill that encodes "edit, validate, iterate, commit"
as a structured cycle. Today this is the agent's default behavior;
the question is whether to leave it implicit or formalize it.

**Recommendation:** leave implicit. Trying to encode a
"development" skill would either be too thin (re-stating "edit
files until tests pass") or too prescriptive (locking in a TDD
cadence that some changes don't need). The PAAD `vibe` and
`agentic-review` skills cover specific subsets when needed.

### Gap 2 — A1→B1 chaining

`project-issue` ends with "the issue exists." Starting work on
that issue now requires the user to follow
[`docs/development/starting-work-on-an-issue.md`](starting-work-on-an-issue.md)
(the doc that replaced the former `branch-workflow` skill). There's
no automatic hand-off.

**Recommendation:** add an explicit "next step" pointer in
`project-issue` that links to that doc. Don't auto-chain; the user
might be filing for the backlog, not for immediate work.

### Gap 3 — Pre-flight DRY

Every skill duplicates a similar preflight: locate `st-docker-run`
(or host venv), check `GH_TOKEN`, etc. Different skills check
slightly different things; some are out of date.

**Recommendation:** factor into a shared `skills/_common/preflight.md`
or similar, referenced by each skill's preflight section. Keeps
the canonical list in one place. Or accept the duplication on the
grounds that each skill should self-document. **Defer the call.**

### Gap 4 — Release tracking issue creation

Phase 1 of `publish` creates a tracking issue ad-hoc (not via
`project-issue`). The two issue-creation paths drift.

**Recommendation:** decide whether release tracking issues should
go through `project-issue` (consistent UX, structured fields) or
stay separate (lightweight, no project assignment needed).
**Probably keep separate** — release tracking issues have their
own lifecycle and shouldn't pollute the project board.

### Gap 5 — General incoming-signal triage

`deprecation-triage` is one specific signal source. There's no
general "I see a warning / failure / surprise in output, what do
I do" skill. Today the agent makes ad-hoc decisions.

**Recommendation:** not a skill problem. Ad-hoc judgment is
appropriate here.

### Gap 6 — Bootstrap → first-action chain

`agents/bootstrap` runs at session start (preflight, PATH check,
warnings). It doesn't suggest "now follow
`docs/development/starting-work-on-an-issue.md` to set up your
worktree" even when an issue is in scope.

**Recommendation:** add an explicit suggestion in bootstrap when
the user's first message references an issue. Out of scope for the
skills audit; tracks as a separate bootstrap-agent enhancement
issue.

## Part 4 — Attack order

Recommended sequence. Each step is a focused PR closing one or
more existing issues and referencing #114.

### 1. ~~`branch-workflow` rewrite~~ → eliminate `branch-workflow`, extract to doc (closes #55) — DONE

**Status update (post-audit, 2026-04-27): completed.** After
discussion the user pushed back on whether `branch-workflow`
deserved its own skill. It was rarely invoked as a slash-command;
its substance is mostly agent-instruction reference. The skill was
removed; the substance now lives at
[`docs/development/starting-work-on-an-issue.md`](starting-work-on-an-issue.md),
referenced from `CLAUDE.md` and `pr-workflow`'s preflight.

This unblocks step 2 — `pr-workflow` no longer waits on a
`branch-workflow` rewrite to land first.

### 2. `pr-workflow` rewrite (closes #56, #85) — DONE

**Status update (post-audit, 2026-04-28): completed.** Skill
rewritten end-to-end. New scope: submit via `st-submit-pr` from
inside the worktree, wait for CI green via `gh pr checks --watch`,
fix agent-fixable failures and re-poll, hand off to the user when
green, finalize via `st-finalize-repo` only after the user
reports the merge.

The obsolete `stop-guard-finalization.sh` Stop hook was deleted
in the same PR (it would have fired on every correct exit under
the new posture, blocking the desired hand-off behavior).

Removed: "enable auto-merge" wording, in-session-mandatory
finalization, outdated host/container framing intro. Added:
explicit "humans review and merge feature/bugfix PRs" policy,
CI-green-wait per #85, worktree-aware finalization, pointer to
`starting-work-on-an-issue.md` from the preflight.

### 3. `publish` skill patches (closes #83, #84, #105)

Smaller scope; can run in parallel with #1 / #2 since publish is at
the C-phase.

Scope:

- Phase 6 auto-close tracking issue with summary template.
- Phase 4 sanity-check `docs.yml` alongside `publish.yml`.
- New post-Phase-6 hand-off: tell the user to run the
  three-step refresh.

### 4. `summarize` decision (closes #58)

Small. Investigate + pick one of the four candidate outcomes;
implement.

### 5. `project-issue` framing patch

Small. Fix the host/container intro section.

### 6. `deprecation-triage` polish

Small. Make the hook→skill seam explicit.

### 7. `dependency-update` rewrite/expansion

Last among the existing skills. Needs the work-cycle skills to be
canonical first, so the "submit via PR" hand-off is clean.

Scope:

- Encode concrete commands per dependency category (Python deps,
  CI action pins, doc toolchain, linters, runtime versions).
- Reference `st-validate-local` as the canonical validation step.
- Tighten the failure-handling around anchored records.

### 8. New-skill TODOs (filed during the work, not implemented in this PR)

- Bootstrap → first-action issue-pickup pointer (out of scope for
  skills; tracked against `agents/`).
- Optional: shared preflight factoring (gap #3, deferred).

## Working agreements for the implementation phase

While executing the attack order:

1. Each skill PR closes the issues it addresses with comments
   linking back to #114.
2. Each skill PR's summary includes a short "what changed for the
   user" paragraph — not just "rewritten per #56."
3. Cross-skill seams identified in Part 1 are made explicit in the
   skills they touch (e.g., when `branch-workflow` finishes, its
   final report points at `pr-workflow` as the next step).
4. The host/container framing patch becomes a bulk find-and-replace
   across skills as part of whichever PR touches each one — not a
   separate "framing-only" PR.
5. After each skill PR merges, this audit document is updated to
   mark the corresponding Part 2 entry's status as "done" with a
   pointer to the PR.
