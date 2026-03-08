---
name: rtfm
description: Handle RTFM forced interruptions by capturing failure context, identifying violated standards, and creating a tracking issue.
---

# RTFM protocol

## Table of Contents

- [Overview](#overview)
- [Inputs](#inputs)
- [Workflow](#workflow)
- [Issue template](#issue-template)
- [Resources](#resources)

## Overview

RTFM is a forced interruption that indicates a standards violation or a missed
requirement that should have been clear from the governing documentation. Pause
all other work and complete this workflow before resuming normal work.

## Inputs

Collect from the triggering message and session context:

- Optional reason provided after `RTFM` (hint about the violated standards)
- Current branch and git status
- Files touched and action sequence that triggered the violation

## Workflow

1. Pause all other work immediately.
2. Capture the failure context with concrete evidence (branch, git status,
   files touched, and the action sequence that triggered the violation).
3. Identify the violated standards with exact document paths and section
   headings, and state how the response diverged.
4. Ask the user what was unclear or insufficient in the standards; use the
   optional reason to focus the question.
5. Create a GitHub issue in the current repository using the template below.
6. Propose and, when feasible, implement documentation updates that prevent
   recurrence before resuming normal work.

## Issue template

```text
Title: RTFM: <short failure summary>

Violated standard(s):
- document path:
- section:

Failure context:
- branch:
- git status:
- files touched:
- action sequence:

What was unclear:
<description of the documentation gap or ambiguity>

Missing or bypassed gate:
<the check or guardrail that should have prevented this>

Proposed documentation update:
<specific changes to prevent recurrence>
```

Label: `rtfm`

## Resources

- `docs/ai-agents/workflows/interaction-contract.md` (RTFM protocol section)
- `docs/ai-agents/behavior/agent-guardrails.md`
- `docs/ai-agents/behavior/agent-pre-response-checklist.md`
