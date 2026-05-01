---
name: publish
description: Drive the end-to-end publish workflow for library, tooling, and documentation repositories, including post-publish dependency updates.
---

# Publish

## Table of Contents

- [Overview](#overview)
- [Preflight](#preflight)
- [Version override](#version-override)
- [Failure handling](#failure-handling)
- [Library-release mode](#library-release-mode)
  - [Policy: agent-driven merges for release-workflow PRs](#policy-agent-driven-merges-for-release-workflow-prs)
  - [Phase 1 — Prepare release](#phase-1--prepare-release)
  - [Phase 2 — Merge release PR](#phase-2--merge-release-pr)
  - [Phase 3 — Merge bump PR](#phase-3--merge-bump-pr)
  - [Phase 4 — Confirm publish](#phase-4--confirm-publish)
  - [Phase 5 — Next-cycle dependency updates](#phase-5--next-cycle-dependency-updates)
  - [Phase 6 — Close tracking issue and finalize](#phase-6--close-tracking-issue-and-finalize)
  - [Phase 7 — Consumer-refresh hand-off](#phase-7--consumer-refresh-hand-off)
- [Docs-only mode](#docs-only-mode)
  - [Phase 1 — Confirm deployment](#phase-1--confirm-deployment)
  - [Phase 2 — Toolchain dependency updates](#phase-2--toolchain-dependency-updates)
- [Dependency update categories](#dependency-update-categories)
- [Resources](#resources)

## Overview

Orchestrate the full publish lifecycle for a repository and initialize the next
development cycle. The key value is in the post-publish phase: after cutting a
release, develop is the safest place to absorb dependency updates across all
categories. This skill covers both the publish confirmation steps and the
subsequent dependency refresh.

Two modes are available, determined by `repository_type` in the repository
profile:

- **library-release** — For library and tooling repositories that publish
  versioned artifacts.
- **docs-only** — For documentation repositories that deploy via CI.

This skill is not applicable to application repositories.

**Arguments** (library-release mode only):

- `/publish` — Publish the current version in develop (default; patch).
- `/publish minor` — Bump to the next minor version before publishing.
- `/publish major` — Bump to the next major version before publishing.

## Host vs container commands

Tools fall into two families with different runtime locations. Honor the
split — silently bypassing it (or silently containerizing tools that
belong on the host) is what produced
[issue #96](https://github.com/wphillipmoore/standard-tooling-plugin/issues/96):
47 days of agents short-circuiting "container-first" guidance for release
tools, hiding three layered infrastructure failures until the first
agent followed the rule verbatim.

### Host commands — run directly

The release / git workflow family. These need the host's SSH agent for
`git push`, the host's git config, the host's `gh` token store, and
one-shot invocation patterns where container startup is wasted overhead.
Containerizing them required adding `openssh-client` and mounting
`~/.ssh` and would still need agent-socket passthrough — every layer is
a seam that can break.

- `git` — local git operations (checkout, branch, fetch, pull, push)
- `gh` — all GitHub CLI operations (issue/PR/release management)
- `st-prepare-release`, `st-commit`, `st-submit-pr`, `st-finalize-repo`,
  `st-merge-when-green`, `st-wait-until-green` — release/PR lifecycle
  drivers
- `st-docker-run` itself — the dispatcher that runs container commands
- `git-cliff` — changelog generation

### Container commands — run via `st-docker-run --`

The language toolchain validators. These are the heavyweight per-language
tools whose maintenance burden on macOS is exactly what `st-docker-run`
exists to eliminate, and whose per-edit invocation amortizes container
caching.

- `ruff`, `mypy`, `ty`, `black`, `isort` (Python)
- `markdownlint`, `st-markdown-standards` (Markdown)
- `yamllint`, `actionlint` (YAML / GitHub workflows)
- `shellcheck`, `shfmt` (shell)
- Any other linter / formatter / type-checker pinned to a project's
  toolchain

### Test for borderline cases

If you're unsure where a tool belongs: is it primarily a wrapper around a
containerized language toolchain (→ container), or a thin Python/shell
driver around git/gh/SSH-using operations (→ host)? `st-validate-local`
itself is a host orchestrator that dispatches its inner validators into
the container — host driver, container payloads.

### Examples

Host (no wrapping):

```bash
st-prepare-release --issue <N>
gh issue create --title "..." --body-file /tmp/release-notes.md
```

Container (always via `st-docker-run --`):

```bash
st-docker-run -- ruff check .
st-docker-run -- markdownlint .
```

## Preflight

- Read `docs/repository-standards.md` and locate the repository profile section.
- Read `repository_type` from the profile.
- If the type is `library` or `tooling`, follow **library-release mode**.
- If the type is `documentation`, follow **docs-only mode**.
- If the type is anything else, stop and inform the user that this skill does
  not apply.
- Confirm you are on the `develop` branch with a clean working tree.
- Identify the canonical validation command from the repository profile.
- Run host commands directly from PATH. If any required command is missing,
  the command will fail and the agent follows the failure handling procedure.
- Verify `GH_TOKEN` is set in the environment. If not, **abort** with a
  message directing the user to set it.
- **Library-release only**: Determine the current version by running the
  version extraction command from the repository's `publish.yml` workflow
  (the `Extract version` step). Execute the command and capture the output —
  **never infer the version from branch names, PR titles, conversation
  context, or any other source.** This is the authoritative version for all
  subsequent phases; store it and reuse it rather than re-reading or guessing.
  Compare the captured version to the latest `v*` tag. If it matches an
  existing tag, **abort** — the post-publish version bump did not run and the
  release tooling needs investigation. Report the mismatch to the user
  and stop — do not attempt to resolve this automatically.

## Version override

This section applies only to library-release mode when `minor` or `major` is
specified. Skip it for the default patch case.

The automated post-publish bump always increments the patch version, so develop
normally carries the next patch. When accumulated changes justify a minor or
major release, the version must be bumped on develop before the release is
prepared.

1. Use the version captured during preflight as the starting version.
2. Compute the target version by incrementing the minor or major component
   (resetting lower components to zero).
3. Update the version at the source of truth in the project manifest.
4. Commit the version bump to `develop` with a message following the
   commit standards (e.g., `chore: bump version to <target>`).
5. Proceed to Phase 1 with the updated version.

## Failure handling

**Stop and report — never stop and fix.** When any step in any phase fails — a
script error, a merge conflict, a CI failure, a missing artifact, a permissions
error — the agent must:

1. **Stop immediately.** Do not attempt to retry, work around, or assess the
   severity of the failure. The agent must never judge whether an error is
   "real" or "just environmental" — that assessment is itself the judgment
   call that produces silent failures.
2. **Comment on the tracking issue** with full diagnostics: the exact error
   message, the command that failed, the phase and step number, and any
   relevant context (branch name, PR number, CI run URL).
3. **Inform the user** and wait for instructions.

The purpose of this skill is to execute a documented, repeatable process.
Manual workarounds mask tooling defects and prevent them from being reported at
the source. Every failure is a signal that the tooling or documentation needs
improvement — surfacing failures is more valuable than completing the release.

## Library-release mode

### Policy: agent-driven merges for release-workflow PRs

Org-wide auto-merge is disabled. The normal convention is
"humans merge human PRs." The release workflow is the explicit
exception: **the agent is both author and reviewer** of release-
and-bump PRs, so the agent also merges them via
`st-merge-when-green`. This applies to three PRs per release
cycle:

- The `release/<version>` PR (Phase 2 below).
- The `chore/bump-version-<next>` PR (Phase 3 below).
- The `chore/<issue>-next-cycle-deps-<version>` PR (Phase 5
  below).

No other PR types are agent-merged. Feature, bugfix, and
non-release dependency-update PRs follow the normal
human-reviews-and-merges flow via the `pr-workflow` skill.

The release workflow is not complete until the bump PR and
dep-update PR have merged — those steps prepare the repository
for the next cycle and are part of this skill's responsibility.

### Phase 1 — Prepare release

1. Use the version captured during preflight. Do not re-read or
   re-derive it.
2. Create a GitHub issue titled `release: <version>` with a body
   summarizing the release. This issue serves as the tracking issue
   for the release and provides the issue linkage required by the
   standards-compliance gate. Log all subsequent phase completions,
   issues encountered, and resolutions as comments on this issue to
   maintain a complete record of the publish operation.
3. Run `st-prepare-release --issue <N>` from the
   repository root on `develop`, passing the tracking issue number.
4. The script creates a `release/<version>` branch, generates the
   changelog, pushes the branch, creates a PR to `main` (with
   `Ref #<N>` in the body), and prints the PR URL. It does not
   attempt to merge — that is Phase 2.
5. Confirm the release branch and PR were created successfully and
   capture the PR URL from the script's output.
6. Comment on the tracking issue with Phase 1 results (branch name,
   PR URL).

### Phase 2 — Merge release PR

1. Run `st-merge-when-green <release-pr-url>`.
   The tool polls CI and merges once all required checks pass
   (merge-commit strategy, delete branch on merge).
2. If any CI check fails, `st-merge-when-green` exits non-zero.
   Follow the failure-handling procedure — do not retry or merge
   manually.
3. Comment on the tracking issue with Phase 2 results (CI outcome,
   merge commit).

### Phase 3 — Merge bump PR

Merging the release PR in Phase 2 triggered `publish.yml` on
`main` asynchronously. Early in that workflow, the
`version-bump-pr` composite creates a `chore/bump-version-<next>`
PR to `develop` but does not merge it. This phase drives that
merge in parallel with the slower async publish work (registry
publication, docs deploy, etc.) handled in Phase 4.

Order matters: the bump PR is nearly always green within a minute
or two of the release merge, well before `publish.yml` finishes.
Handling the fast artifact first keeps the skill from serializing
behind external async work.

1. Poll for the bump PR URL. Run
   `gh pr list --head chore/bump-version-<next> --json url --jq '.[0].url'`
   and retry at ~10-second intervals until it returns a non-empty
   value (typically within ~60 seconds of Phase 2 completing).
   **Do not invent shell polling scripts** — use your environment's
   native polling mechanism (e.g., Claude Code's Monitor tool with
   an `until` loop) and keep the check to this single `gh pr list`
   command.
2. **Verify issue linkage.** Read the bump PR body and check for
   a `Ref #N`, `Fixes #N`, `Closes #N`, or `Resolves #N`
   reference. The `version-bump-pr` composite action auto-
   discovers the tracking issue by title, but auto-discovery can
   fail under edge conditions (indexing latency, title mismatch,
   token-scope limits). If the PR body has no issue linkage:
   1. Write a corrected body to a temp file that adds
      `Ref #<tracking-issue-number>` (the tracking issue from
      Phase 1).
   2. Update the PR: `gh pr edit <bump-pr-url> --body-file <file>`.
   3. Push an empty commit on the bump branch to retrigger CI
      (editing the PR body alone does not retrigger workflows —
      the `pr-issue-linkage` check evaluates the event payload
      from the push, not the live PR body).
3. Run `st-merge-when-green <bump-pr-url>`.
4. If CI fails, follow the failure-handling procedure — do not
   retry or merge manually.
5. Comment on the tracking issue with Phase 3 results (bump PR URL,
   next version now on `develop`).

### Phase 4 — Confirm publish

Block until **both** asynchronous workflows triggered by the
release-PR merge complete successfully:

1. `publish.yml` on `main` — tag, GitHub Release, package artifact
   to the registry.
2. `docs.yml` (or the repo's documentation deploy workflow) on
   `main` — versioned docs site deploy.

`docs.yml` is a separate async workflow from `publish.yml`. A
release that tagged and published the package but whose docs
failed to deploy is a half-shipped release that looks identical
to a working one until a user tries to read the docs. Do not
declare Phase 4 complete until both workflows succeed.

Block on each workflow:

```bash
gh run watch --exit-status \
  $(gh run list --workflow publish.yml --branch main --limit 1 --json databaseId --jq '.[0].databaseId')

gh run watch --exit-status \
  $(gh run list --workflow docs.yml --branch main --limit 1 --json databaseId --jq '.[0].databaseId')
```

Adjust the docs workflow filename if the repo uses a different
name (e.g., `pages.yml`, `mkdocs.yml`).

Then verify all publish artifacts:

- Both workflow run conclusions are `success`.
- Git tag `v<version>` on `main`.
- Develop tag `develop-v<version>` for changelog boundaries.
- GitHub Release created.
- Package artifact published to the registry.
- GitHub Pages documentation deployed for the new version
  (e.g., `mike list` shows the new version, or the docs site
  serves the new version under its versioned URL).

If either workflow failed, follow the failure-handling
procedure. A failed publish after successful PR merges leaves
the repository half-released; surface the failure and stop.

Comment on the tracking issue with Phase 4 results (all run
URLs, list of artifacts confirmed).

### Phase 5 — Next-cycle dependency updates

1. Create a `chore/<issue>-next-cycle-deps-<version>` branch from
   `develop`, where `<issue>` is the tracking issue number.
2. Update all applicable dependency categories (see
   [Dependency update categories](#dependency-update-categories)).
3. Run full validation.
4. Submit the PR via `st-submit-pr`.
5. Run `st-merge-when-green <dep-update-pr-url>`. This PR is an
   agent-authored, agent-reviewed release-workflow artifact — the
   same posture as the release and bump PRs.
6. Comment on the tracking issue with Phase 5 results (dependency
   update PR URL, categories updated).

### Phase 6 — Close tracking issue and finalize

**The release cycle is not complete until the tracking issue is
closed with a summary comment.** Same posture as Phase 4: the
repo's historical record is a release artifact, and an open
tracking issue is an unfinished release as far as future readers
can tell. Skipping this step is a failure to complete, not a
nice-to-have.

Order matters here. Close the tracking issue **before**
`st-finalize-repo` so the historical record is sealed first; if
finalize errors out (e.g., a sibling worktree blocks cleanup),
the bookkeeping is still done.

1. **Close the tracking issue with a final summary comment.**
   Required content in the summary:

   - All PR URLs (release PR, bump PR, any recovery PRs)
   - Tag, develop tag, GitHub Release URLs
   - `publish.yml` and `docs.yml` (or equivalent) run URLs from
     Phase 4
   - Any failures encountered and the resolutions

   All issue and PR references in the summary must be full URLs
   (not short `#N` references) so they are clickable in the
   terminal.

2. **Run `st-finalize-repo`** to return to a clean `develop`
   branch. The script updates local `develop`, deletes merged
   branches, and prunes stale remotes. Run final validation to
   confirm a clean state.

3. **Continue to Phase 7.** Phase 6 alone does not conclude the
   cycle; the producer-side hand-off in Phase 7 is the actual
   release boundary for consumers.

### Phase 7 — Consumer-refresh hand-off

The release artifacts are published, but **consumers haven't
picked them up yet.** Consumers need an explicit local action
to pick up the new version — the specific commands vary by
repository.

**Display only — do not execute.** The agent's job is to show
the user the exact commands to run, not to run them. The refresh
is a consumer-side action: the user controls when and in which
session they apply it. Running the commands silently or
inconsistently (sometimes executing, sometimes displaying) is
the behavior this rule exists to prevent.

Read the consumer-refresh sequence from the repository's
`standard-tooling.toml` under `[publish] consumer-refresh`.
Display the value verbatim as the hand-off message.

If `[publish] consumer-refresh` is not set, tell the user
explicitly that no consumer-refresh sequence is configured for
this repository and suggest filing an issue to add one. **Never
display a hardcoded example from a different repository** — that
is worse than no hand-off at all.

Phase 7 ends when the user has seen the refresh sequence in the
hand-off message. The user is not required to *run* the
sequence in this session; they are required to *see* it as
part of the producer's hand-off.

## Docs-only mode

### Phase 1 — Confirm deployment

1. Verify the docs CI workflow ran on `develop`.
2. Confirm the site deployed successfully via mike.

### Phase 2 — Toolchain dependency updates

1. Create a `chore/toolchain-deps` branch from `develop`.
2. Update all applicable toolchain dependency categories (see
   [Dependency update categories](#dependency-update-categories)).
3. Run full validation.
4. Submit via `pr-workflow`.
5. Run `st-finalize-repo` to return to a clean `develop`
   branch. The script updates local `develop`, deletes merged branches, and
   prunes stale remotes. Run final validation to confirm a clean state.

## Dependency update categories

Each category follows the same pattern: update at the source of truth,
regenerate derived artifacts, run full validation. Failures follow the
`dependency-update` skill's failure handling procedure.

**Library dependencies** (library repos only):

- Direct dependencies in the project manifest.
- Lockfile regeneration.
- Review anchored dependencies for release eligibility: check each anchor
  record's exit criteria and re-test where upstream fixes may have landed.
  Follow the dependency anchor records standard and the tracking issues
  linked from each record.

**Toolchain dependencies** (all repos):

- CI action version pins.
- Runtime version pins (per the runtime version support policy tier model).
- Documentation toolchain (mkdocs-material, mike, mkdocstrings).
- Linters, formatters, and type checkers (ruff, mypy, ty, markdownlint-cli).
- Test frameworks and coverage tools (pytest, coverage).
- Build tools (hatch, setuptools, uv).

## Resources

- `docs/code-management/branching/library-branching-and-release.md`
- `docs/code-management/branching/documentation-branching-model.md`
- `docs/code-management/versioning/release-versioning.md`
- `docs/code-management/versioning/library-versioning-scheme.md`
- `docs/repository/dependency-update-workflow.md`
- `docs/repository/overview.md`
- `docs/development/runtime-version-support-policy.md`
- `docs/development/documentation-toolchain.md`
- `docs/development/python/dependency-management.md`
- `skills/dependency-update/SKILL.md`
- `skills/pr-workflow/SKILL.md`
