# Skills

Skills are shared workflow definitions that Claude Code loads from
the plugin. Each skill is a directory containing a `SKILL.md` file
with frontmatter and structured instructions. All skills are
namespaced under `standard-tooling` and invoked as
`/standard-tooling:<skill-name>`.

## Skill Catalogue

**branch-workflow**
:   Ensure a correctly named branch exists for an issue
    before starting work.

**pr-workflow**
:   Guide pull request creation, submission, and
    finalization.

**publish**
:   Drive the end-to-end publish workflow for library,
    tooling, and documentation repositories.

**dependency-update**
:   Run the dependency update workflow with validation and
    failure handling.

**deprecation-triage**
:   Triage deprecation warnings with issue tracking and
    suppression rules.

**project-issue**
:   Create a well-structured project issue through guided
    questions.

**rtfm**
:   Handle RTFM forced interruptions by capturing failure
    context and creating tracking issues.

**summarize**
:   Multi-mode summarization for decisions, operations, or
    stream-of-consciousness capture.

## branch-workflow

Resolves an issue to a repo-level issue, checks for existing
branches, and creates a correctly named feature branch. Handles
project-to-repo issue resolution and sub-issue creation for
cross-repo work.

**When to use**: At the start of any work session that involves
code changes.

## pr-workflow

Guides the full PR lifecycle: validation, submission via
`st-submit-pr`, merge monitoring, and finalization via
`st-finalize-repo`. Auto-merge is always enabled; CI gates are
the sole merge authority.

**When to use**: When work on a branch is complete and ready for
review.

## publish

Drives end-to-end release publishing with two modes:

- **Library-release**: 6-phase process (prepare, review/merge,
  confirm publish, version bump, dependency updates, finalize)
- **Docs-only**: Simplified flow for documentation-only releases

Includes strict failure handling with issue tracking and
post-publish dependency cycle management.

**When to use**: When preparing and executing a versioned release.

## dependency-update

Repeatable dependency update process with validation, failure
handling, and anchor record requirements. Covers both direct
dependencies and lockfile updates.

**When to use**: When updating project dependencies to newer
versions.

## deprecation-triage

Triage policy to prevent deprecation warning drift. Creates
tracking issues with structured templates, supports fix-now vs.
defer-to-next-cycle decisions, and tracks suppression with
removal criteria.

**When to use**: When deprecation warnings are detected in test
output.

## project-issue

Guided issue creation workflow that collects issue type, priority,
work type, summary, problem/goal, acceptance criteria, and
validation steps. Creates the issue in the target repo and adds it
to the GitHub Project with appropriate field values.

**When to use**: When creating new issues for planned work.

## rtfm

Forced-interruption protocol for standards violations. Captures
failure context with concrete evidence, identifies violated
standards with exact document paths, and creates tracking issues
with proposed documentation updates.

**When to use**: When a standards violation is detected during
work.

## summarize

Three summarization modes:

- **decisions**: Structured summary of decisions made during a
  session
- **operations**: Summary of operations performed
- **soc** (stream-of-consciousness): Free-form capture of context
  and reasoning

Mode is auto-selected or user-specified.

**When to use**: When the user asks for a structured summary or
invokes SOC capture.
