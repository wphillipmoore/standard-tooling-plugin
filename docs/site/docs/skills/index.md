# Skills

Skills are shared workflow definitions that Claude Code loads from
the plugin. Each skill is a directory under `skills/` containing a
`SKILL.md` file with frontmatter and structured instructions. All
skills are namespaced under `standard-tooling` and invoked as
`/standard-tooling:<skill-name>`.

Each entry below covers what the skill does, when to use it, and
its current status — including any tracked work that will
substantially change it.

## Skill catalogue (at a glance)

| Skill | Purpose | Status |
|---|---|---|
| [pr-workflow](#pr-workflow) | Submit a PR, wait for CI green, hand off to user; finalize after merge | Current |
| [publish](#publish) | Drive library / tooling / documentation release flow | Needs review; rethink tracked in [#57](https://github.com/wphillipmoore/standard-tooling-plugin/issues/57) |
| [project-issue](#project-issue) | Create a well-structured GitHub issue via guided questions | Current |
| [dependency-update](#dependency-update) | Run the dependency-update workflow | Current (reviewed 2026-04-23, no changes) |
| [deprecation-triage](#deprecation-triage) | Triage deprecation warnings into tracking issues | Current (reviewed 2026-04-23, no changes) |
| [summarize](#summarize) | Decision / operation / stream-of-consciousness summaries; SOC mode is the canonical capture for the fleet | Current |

## pr-workflow

**What it does.** Submits a PR via `st-submit-pr` from inside the
issue's worktree, waits for CI to go green, fixes any agent-fixable
red checks, and hands off to the user for review and merge. After
the user reports the merge, runs `st-finalize-repo` from the
worktree to clean up local state.

**When to use.** When work on a branch is complete and ready for
review. Covers "open a PR for this branch" through "PR merged,
clean up local state" — but the agent stops between submission
and merge; humans review and merge feature/bugfix PRs.

**Status.** Current. Reflects the worktree convention and the
fleet-wide "humans review human PRs" posture as of 2026-04-22.
The release-workflow exception (agent merges release PRs via
`st-merge-when-green`) lives in the
[`publish` skill](#publish), not here.

## publish

**What it does.** Drives end-to-end release publishing for
library / tooling / documentation repositories. Covers the
multi-phase flow: prepare release branch, review + merge, confirm
publish, post-publish version bump, dependency-consumer updates,
and local finalization. Includes failure handling with issue
tracking.

**When to use.** When preparing and executing a versioned release
of a repository that uses the `library-release` or
`tagged-release` model.

**Status.** Needs review. The dockerized validation model
(everything runs via `st-docker-run`) and the recent publish-
workflow changes in individual repos may have drifted from what
this skill describes. Rethink tracked in
[plugin#57](https://github.com/wphillipmoore/standard-tooling-plugin/issues/57)
— applies lessons from the first-ever
standard-tooling-plugin release exercise.

## project-issue

**What it does.** Guided issue creation that collects issue type,
priority, work type, summary, problem/goal, acceptance criteria,
and validation steps. Creates the issue in the target repo and
adds it to the appropriate GitHub Project with the right field
values set.

**When to use.** When creating a new tracked issue, especially
when it belongs on a GitHub Project board and needs standard
fields populated.

**Status.** Current.

## dependency-update

**What it does.** Repeatable dependency-update workflow covering
signal collection (security alerts, audits, planned upgrades),
updating at sources of truth, regenerating lockfiles / exports /
generated manifests, running validation, and progressing through
the standard PR workflow. Includes failure handling with anchored-
dependency records for cases where a dependency must be pinned
below the latest acceptable range.

**When to use.** When updating project dependencies — whether in
response to a CVE, a scheduled cycle, or as part of normal
maintenance.

**Status.** Current. Reviewed for currency on 2026-04-23 as part
of [plugin#59](https://github.com/wphillipmoore/standard-tooling-plugin/issues/59);
no changes needed. References `docs/repository/dependency-update-workflow.md`
and sibling docs that may not exist in every consuming repo — those
references are informational (consult if present) rather than
required.

## deprecation-triage

**What it does.** Applies the deprecation-warning triage policy:
search for an existing issue matching the warning, create a
tracking issue if none exists using the standard template,
attempt a code-only fix, decide fix-now vs defer-to-next-cycle,
and document any suppression with removal criteria. Paired with
the `detect-deprecation-warnings` PostToolUse hook.

**When to use.** When a deprecation warning surfaces during test
output, CI, or regular work. The partner hook triggers this
flow automatically when it catches warnings.

**Status.** Current. Reviewed for currency on 2026-04-23 as part
of [plugin#59](https://github.com/wphillipmoore/standard-tooling-plugin/issues/59);
no changes needed.

## summarize

**What it does.** Produces a concise, structured summary in one of
three modes:

- **decisions** — summary of decisions made during a session
  (what, why, alternatives considered, next step)
- **operations** — summary of operations performed (what was
  touched, what happened, what remains)
- **soc** — stream-of-consciousness capture for context offloading
  between sessions (triggered by `Enter SOC` / `End SOC`)

**When to use.** When the user explicitly asks for a structured
summary, invokes SOC capture, or the skill is invoked via
handoff protocols.

**Status.** Current. Decision A from
[plugin#58](https://github.com/wphillipmoore/standard-tooling-plugin/issues/58):
this skill's SOC mode is the canonical SOC capture mechanism for
the fleet. Repo-local references to `soc-capture` or
`summarize-soc` as skill names are stale pointers — splitting
SOC into its own skill was rejected because capture and summary
are intertwined here (`End SOC` triggers the structured summary).
The cross-repo references in `the-infrastructure-mindset` are
tracked for cleanup in
[the-infrastructure-mindset#165](https://github.com/wphillipmoore/the-infrastructure-mindset/issues/165).

## How skills work — technical

Each skill is a directory under `skills/` containing:

- **`SKILL.md`** — required. Frontmatter with `name` and
  `description`, followed by the skill's body (context, workflow,
  templates, etc.).
- Optional supporting files (templates, examples) referenced from
  `SKILL.md`.

The plugin's `skills/` directory is loaded on session start. The
skill `name` in the frontmatter plus the plugin's namespace
(`standard-tooling`) determines the invocation: a skill named
`pr-workflow` in this plugin is invoked as
`/standard-tooling:pr-workflow`.

Skills are documentation-as-config, not executable scripts. They
tell Claude Code *how* to run a workflow; Claude Code executes
the flow using whatever tools the user has granted.
