---
name: summarize
description: Multi-mode summarization for decisions, operations, or stream-of-consciousness capture. Use when the user asks for a structured summary or invokes SOC capture.
---

# Summarize

## Table of Contents

- [Overview](#overview)
- [Mode selection](#mode-selection)
- [Common rules](#common-rules)
- [Mode: decisions](#mode-decisions)
- [Mode: operations](#mode-operations)
- [Mode: soc](#mode-soc)
- [Output templates](#output-templates)
- [Resources](#resources)

## Overview

Produce a concise, structured summary using the canonical protocol for the
selected mode. Preserve outcomes, reasoning, and evidence without adding
external knowledge.

## Mode selection

Select the mode in this order:

1. If the user explicitly specifies a mode, follow it.
2. If the user uses `Enter SOC` or `End SOC`, use **soc** mode.
3. If the request centers on decisions, rationale, or alternatives, use
   **decisions** mode.
4. If the request centers on actions taken, system changes, or outcomes, use
   **operations** mode.
5. If multiple modes plausibly apply, ask the minimum clarification question:
   "Which mode: decisions, operations, or soc?"

## Common rules

- Base the summary only on the provided input record.
- Do not add external facts, assumptions, or inferred details.
- Call out missing or ambiguous information explicitly.
- Preserve sequence when the order of events matters.
- Keep the output concise and non-narrative.

## Mode: decisions

Follow the Summarize Decisions Protocol.

- Required section order: Results, Reasoning, Options Not Chosen.
- Label implicitly converged decisions as **implicit**.
- Include optional sections only when present in the input.

## Mode: operations

Follow the Summarize Operations Protocol.

- Required section order: Actions Taken, Outcomes and Status, Problems
  Encountered and Solved, Problems Unresolved, Changes and Artifacts, Follow-up
  Work and New Issues.
- Capture evidence for command-driven actions (commands + minimal output).
- Include timestamps when available; state when none were provided.
- Redact secrets or sensitive data and note the redaction.

## Mode: soc

Follow the Summarize Stream of Consciousness Protocol.

- `Enter SOC` begins capture mode; acknowledge capture activation.
- During SOC capture, record input verbatim and do not summarize or interpret.
- `End SOC` ends capture mode and triggers the structured summary.
- If SOC is not closed with `End SOC`, do not produce a summary.

## Output templates

Decisions:

```text
Results
- ...

Reasoning
- ...

Options Not Chosen
- Option: ...
  Reason: ...
  Status: rejected | deferred
  Revisit triggers: ...
```

Operations:

```text
Actions Taken
- ...

Outcomes and Status
- ...

Problems Encountered and Solved
- ...

Problems Unresolved
- ...

Changes and Artifacts
- ...

Follow-up Work and New Issues
- ...
```

SOC:

```text
Summary
- ...

Themes
- ...

Open Questions
- ...
```

## Resources

- `docs/ai-agents/protocols/summarize-decisions-protocol.md`
- `docs/ai-agents/protocols/summarize-operations-protocol.md`
- `docs/ai-agents/protocols/summarize-stream-of-consciousness-protocol.md`
