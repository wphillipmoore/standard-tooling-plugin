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
  - [Phase 1 — Prepare release](#phase-1--prepare-release)
  - [Phase 2 — Review and merge](#phase-2--review-and-merge)
  - [Phase 3 — Confirm publish](#phase-3--confirm-publish)
  - [Phase 4 — Confirm version bump](#phase-4--confirm-version-bump)
  - [Phase 5 — Next-cycle dependency updates](#phase-5--next-cycle-dependency-updates)
  - [Phase 6 — Close and finalize](#phase-6--close-and-finalize)
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

This skill runs on the **host**. Almost all commands run inside the dev
container via `st-docker-run`, which mounts the repo at `/workspace` and
passes through `GH_TOKEN` and other environment variables automatically.

**Host commands** — run directly:

- `git` — local git operations (checkout, branch, fetch, pull, push)

**Container commands** — run via `st-docker-run`:

- `gh` — all GitHub CLI operations
- `st-prepare-release`, `st-commit`, `st-submit-pr`, `st-finalize-repo`
- Validation commands (e.g. `markdownlint .`)

To invoke a container command:

```bash
st-docker-run -- st-prepare-release --issue <N>
st-docker-run -- gh issue create --repo <repo> --title "..." --body-file /workspace/tmp.md
```

### Locating st-docker-run

Search for `st-docker-run` in this order:

1. `../standard-tooling/.venv-host/bin/st-docker-run` (sibling checkout
   with host venv)
2. `st-docker-run` on PATH (already installed)

If neither is found, **abort** with a message directing the user to set up
the host venv:

```text
st-docker-run not found. Run the following one-time setup:
  cd ../standard-tooling
  UV_PROJECT_ENVIRONMENT=.venv-host uv sync --group dev
```

Resolve `st-docker-run` once during preflight and use the resolved path
for all subsequent container command invocations.

## Preflight

- Read `docs/repository-standards.md` and locate the repository profile section.
- Read `repository_type` from the profile.
- If the type is `library` or `tooling`, follow **library-release mode**.
- If the type is `documentation`, follow **docs-only mode**.
- If the type is anything else, stop and inform the user that this skill does
  not apply.
- Confirm you are on the `develop` branch with a clean working tree.
- Identify the canonical validation command from the repository profile.
- Locate `st-docker-run` using the search algorithm above. If not found,
  **abort** with setup instructions.
- Verify `GH_TOKEN` is set in the environment. If not, **abort** with a
  message directing the user to set it.
- **Library-release only**: Read the current version from the project manifest
  and compare it to the latest `v*` tag. If the version matches an existing
  tag, **abort** — the post-publish version bump did not run and the release
  tooling needs investigation. Do not attempt to fix this automatically.

## Version override

This section applies only to library-release mode when `minor` or `major` is
specified. Skip it for the default patch case.

The automated post-publish bump always increments the patch version, so develop
normally carries the next patch. When accumulated changes justify a minor or
major release, the version must be bumped on develop before the release is
prepared.

1. Read the current version from the project manifest on `develop`.
2. Compute the target version by incrementing the minor or major component
   (resetting lower components to zero).
3. Update the version at the source of truth in the project manifest.
4. Commit the version bump to `develop` with a message following the
   commit standards (e.g., `chore: bump version to <target>`).
5. Proceed to Phase 1 with the updated version.

## Failure handling

**Do not work around failures.** When any step in any phase fails — a script
error, a merge conflict, a CI failure, a missing artifact, a permissions error —
the agent must:

1. **Stop immediately.** Do not attempt to fix, retry, or work around the
   failure.
2. **Comment on the tracking issue** with full diagnostics: the exact error
   message, the command that failed, the phase and step number, and any
   relevant context (branch name, PR number, CI run URL).
3. **Inform the user** and wait for instructions.

The purpose of this skill is to execute a documented, repeatable process.
Manual workarounds mask tooling defects and prevent them from being fixed at
the source. Every failure is a signal that the tooling or documentation needs
improvement — surfacing failures is more valuable than completing the release.

## Library-release mode

### Phase 1 — Prepare release

1. Read the current version from the project manifest.
2. Create a GitHub issue titled `release: <version>` with a body summarizing the
   release. This issue serves as the tracking issue for the release and provides
   the issue linkage required by the standards-compliance gate. Log all
   subsequent phase completions, issues encountered, and resolutions as comments
   on this issue to maintain a complete record of the publish operation.
3. Run `st-docker-run -- st-prepare-release --issue <N>` from the repository
   root on `develop`, passing the tracking issue number.
4. The script creates a `release/<version>` branch, generates the changelog,
   pushes the branch, creates a PR to `main` (with `Ref #<N>` in the body),
   and enables auto-merge.
5. Confirm the release branch and PR were created successfully.
6. Comment on the tracking issue with Phase 1 results (branch name, PR URL).

### Phase 2 — Review and merge

1. Wait for CI to validate the release branch.
2. Confirm the PR merges into `main` via regular merge (not squash).
3. Confirm the release branch is deleted after merge.
4. Comment on the tracking issue with Phase 2 results (CI outcome, merge
   confirmation).

### Phase 3 — Confirm publish

Verify all publish artifacts are present:

- Git tag `v<version>` on `main`.
- Develop tag `develop-v<version>` for changelog boundaries.
- GitHub Release created.
- Package artifact published to the registry.
- GitHub Pages documentation deployed for the new version.

Comment on the tracking issue with Phase 3 results (list of artifacts
confirmed).

### Phase 4 — Confirm version bump

1. Wait for the automated `chore/bump-version-<next>` PR to `develop`.
2. Confirm the bump PR auto-merges.
3. Update local `develop` to incorporate the merge.
4. Comment on the tracking issue with Phase 4 results (bump PR URL, next
   version).

### Phase 5 — Next-cycle dependency updates

1. Create a `chore/next-cycle-deps-<version>` branch from `develop`.
2. Update all applicable dependency categories (see
   [Dependency update categories](#dependency-update-categories)).
3. Run full validation.
4. Submit via `pr-workflow`.
5. Comment on the tracking issue with Phase 5 results (dependency update PR
   URL, categories updated).

### Phase 6 — Close and finalize

1. Close the tracking issue with a final summary comment covering all phases.
   All issue and PR references in the summary must be full URLs (not short
   `#N` references) so they are clickable in the terminal.
2. Run `st-docker-run -- st-finalize-repo` to return to a clean `develop`
   branch. The script updates local `develop`, deletes merged branches, and
   prunes stale remotes. Run final validation to confirm a clean state.

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
5. Run `st-docker-run -- st-finalize-repo` to return to a clean `develop`
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
