---
name: deprecation-triage
description: Triage deprecation warnings into a consistent workflow with issue tracking and suppression rules.
---

# Deprecation triage

## Table of Contents
- [Overview](#overview)
- [Inputs](#inputs)
- [Workflow](#workflow)
- [Issue template](#issue-template)
- [Resources](#resources)

## Overview
Apply the deprecation warning triage policy to prevent warning drift and ensure
issues are tracked and resolved in-cycle or deferred explicitly.

## Inputs
Collect or request:
- Full warning text
- Location (file/module and call site)
- Environment (dev/test/prod)
- First seen date and version
- Whether the warning is user-visible

## Workflow
1. Search for an existing issue that matches the warning text and location.
2. If an issue exists and the warning is mid-cycle, defer to the next
   dependency update.
3. If no issue exists, create one using the template below.
4. Attempt a code-only fix if no dependency upgrade is required.
5. If a dependency upgrade is required, defer to the start-of-cycle upgrade.
6. If user-visible and deferred, suppress and document the suppression.
7. Update the issue with each re-test and close when resolved.

## Issue template
```
Title: Deprecation: <dependency or component> - <short description>

Warning text:
<full warning message>

Location:
- file/module:
- call site:
- environment (dev/test/prod):

Reproduction:
- minimal command or steps:
- notes on reproducibility:

First seen:
- date:
- version:

Impact assessment:
- user-visible: yes/no
- behavior risk:

Attempted fixes:
- code changes tried:
- result:

Upgrade assessment:
- required dependency version:
- upgrade scope:

Decision:
- fix now / defer to next cycle
- rationale:

Suppression (if any):
- suppression method:
- removal criteria:
```

## Resources
- `docs/development/deprecation-warnings.md`
