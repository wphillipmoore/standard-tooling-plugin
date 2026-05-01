---
name: dependency-update
description: Run the dependency update workflow with validation, failure handling, and anchor record requirements.
---

# Dependency update

## Table of Contents

- [Overview](#overview)
- [When to use](#when-to-use)
- [Host vs container commands](#host-vs-container-commands)
- [Preflight](#preflight)
- [Library dependencies](#library-dependencies)
- [Toolchain dependencies](#toolchain-dependencies)
- [Anchor review](#anchor-review)
- [Validation](#validation)
- [Failure handling](#failure-handling)
- [Submission](#submission)
- [Resources](#resources)

## Overview

Execute a repeatable dependency update process that prioritizes stability and
traceability. Each category follows the same pattern: update at the source of
truth, regenerate derived artifacts, run full validation. When a dependency
cannot be updated, the failure is recorded as an anchored dependency record
with exit criteria — never silently pinned.

## When to use

- **Post-publish (Phase 5):** The `publish` skill's Phase 5 hands off to this
  skill after a release ships. Develop is the safest place to absorb updates
  because it has the widest validation window before the next release.
- **Standalone:** Invoked directly via `/standard-tooling:dependency-update`
  when a dependency update is needed outside a release cycle (security alert,
  deprecation, planned upgrade).

## Host vs container commands

Most commands in this skill are **host commands** — invoke them directly
without `st-docker-run` wrapping. This includes `uv`, `gh`, `st-commit`,
`st-validate-local`, and all `st-*` workflow tools.

The only container-dispatched work happens inside `st-validate-local`,
which handles that routing internally. See the
[`publish` skill's host-vs-container section](../publish/SKILL.md#host-vs-container-commands)
for the canonical split and rationale
([#96](https://github.com/wphillipmoore/standard-tooling-plugin/issues/96)).

## Preflight

1. Confirm you are on a `chore/` branch off `develop` (e.g.,
   `chore/next-cycle-deps-<version>` for post-publish, or
   `chore/dep-update-<date>` for standalone).
2. Read `standard-tooling.toml` to identify:
   - `repository_type` — determines which categories apply.
   - The canonical validation command.
3. Verify `GH_TOKEN` is set.
4. Locate `st-docker-run` using the standard search algorithm (see the
   `publish` skill's preflight for the lookup order) — needed only for
   validation steps that dispatch into the container.

## Library dependencies

Applies to repos where `repository_type` is `library` or `tooling`.

### Direct dependencies

1. Read `pyproject.toml` — the `[project.dependencies]` and
   `[project.optional-dependencies]` tables are the sources of truth.
2. Run `uv lock --upgrade` to regenerate `uv.lock` with the latest
   compatible versions.
3. If a dependency has an upper bound (`<X.Y`), check whether the bound is
   still necessary. If the upstream release that caused the bound has been
   fixed, remove the bound and re-lock.

### Lockfile regeneration

After any change to `pyproject.toml` or after `uv lock --upgrade`:

```bash
uv lock
```

Verify the lockfile is consistent:

```bash
uv lock --check
```

## Toolchain dependencies

Applies to all managed repos.

### CI action version pins

1. Scan `.github/workflows/*.yml` for `uses:` directives.
2. For each pinned action (`owner/action@vN.M` or `owner/action@sha`), check
   the action's releases for newer versions.
3. Update pins in-place. Prefer tag pins (`@vN`) over SHA pins unless the
   action's documentation recommends otherwise.

### Runtime version pins

1. Read the runtime version support policy tier model from the repository
   profile.
2. Check whether any supported runtime versions have been end-of-lifed or
   whether new versions should be added to the test matrix.
3. Update `.github/workflows/*.yml` matrix entries and any runtime version
   pins in `pyproject.toml` (`requires-python`).

### Documentation toolchain

Update in `pyproject.toml` under the `[project.optional-dependencies]` docs
group (or equivalent):

- `mkdocs-material`
- `mike`
- `mkdocstrings` and language handlers

### Linters, formatters, and type checkers

Update in `pyproject.toml` under the dev dependency group:

- `ruff`
- `mypy` / `ty`
- `markdownlint-cli` (pinned in `.github/workflows/` or `package.json`)

### Test frameworks and coverage

- `pytest`
- `coverage`
- `pytest-cov` and any other test plugins

### Build tools

- `hatch`
- `setuptools`
- `uv`

## Anchor review

During every dependency update sweep, review existing anchored dependency
records:

1. Read each anchor record in the repository (typically in
   `docs/dependency-anchors/` or equivalent).
2. Check the exit criteria: has the upstream issue been fixed? Has the
   blocking version been released?
3. If exit criteria are met, remove the anchor, update the dependency, and
   note the resolution in the anchor's tracking issue.
4. If exit criteria are not met, leave the anchor in place and add a
   re-test comment to the tracking issue noting the date and current
   upstream status.

## Validation

After all updates in a category (or after all categories if batching):

```bash
st-validate-local
```

`st-validate-local` is a host orchestrator that dispatches its inner
validators into the container via `st-docker-run`. Invoke it directly —
do not wrap it in `st-docker-run`. Fix any failures before proceeding to
the next category or to submission.

## Failure handling

When a dependency update breaks validation:

1. **Diagnose** — determine the root cause. Is it a breaking change in the
   dependency, a bug in the new version, or a latent issue in the codebase?
2. **Fix if possible** — if the fix is a straightforward code change (API
   rename, import path change), apply it.
3. **Anchor if not** — if the dependency cannot be updated without
   significant work:
   - Revert to the last working version.
   - Create or update an anchored dependency record with:
     - The dependency name and anchored version.
     - The target version that failed.
     - The exact failure evidence (error messages, test output).
     - Exit criteria: what upstream change would unblock the update.
   - File a tracking issue for the anchor if one does not exist.
   - Link the anchor record to the tracking issue.
4. **Never silently pin.** Every version hold must have a record and a
   tracking issue.

## Submission

Once all applicable categories are updated and validation passes:

1. Commit via `st-commit` with a message summarizing what was updated
   (e.g., `chore(deps): sweep post-1.4.5 dependency updates`).
2. Submit via the `pr-workflow` skill. The PR description should list
   each category updated and any anchors created or resolved.

## Resources

- `docs/repository/dependency-update-workflow.md` (in `standard-tooling`)
- `docs/repository/overview.md` (in `standard-tooling`)
- `docs/development/python/dependency-management.md` (in `standard-tooling`)
- `docs/development/runtime-version-support-policy.md` (in `standard-tooling`)
- `docs/development/documentation-toolchain.md` (in `standard-tooling`)
- `skills/publish/SKILL.md` — Phase 5 and Dependency update categories
- `skills/pr-workflow/SKILL.md` — for the submission step
