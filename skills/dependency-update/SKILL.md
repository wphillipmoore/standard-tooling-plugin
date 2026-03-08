---
name: dependency-update
description: Run the dependency update workflow with validation, failure handling, and anchor record requirements.
---

# Dependency update

## Table of Contents

- [Overview](#overview)
- [Preflight](#preflight)
- [Workflow](#workflow)
- [Failure handling](#failure-handling)
- [Completion](#completion)
- [Resources](#resources)

## Overview

Execute a repeatable dependency update process that prioritizes stability and
traceability. Use language-specific standards when present.

## Preflight

- Identify the relevant dependency standards for the repository.
- Confirm sources of truth for dependency versions and lockfiles.
- If the repository defines a canonical validation command, capture it.

## Workflow

1. Collect update signals (security alerts, audits, planned upgrades).
2. Update dependencies at their sources of truth.
3. Regenerate derived artifacts (lockfiles, exports, or generated manifests).
4. Run the full validation and test suite.
5. Proceed through the standard pull request workflow.

## Failure handling

- Determine root cause before pinning or deferring.
- If a dependency is anchored below the latest acceptable range:
  - Create or update an anchored dependency record.
  - Document the failure evidence and exit criteria.
- If the dependency itself is the blocker, create a tracking issue and record
  the pin rationale at the source of truth.

## Completion

- Ensure the repository is in a clean, validated state.
- Record any new anchors, issues, or follow-up actions.

## Resources

- `docs/repository/dependency-update-workflow.md`
- `docs/repository/overview.md`
- `docs/development/python/dependency-management.md` (when applicable)
- `docs/code-management/pull-request-workflow.md`
