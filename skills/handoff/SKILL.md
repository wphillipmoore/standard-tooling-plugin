---
name: handoff
description: Session-to-session continuity — capture work state before stopping (/handoff stop) or resume from a previous session (/handoff start).
---

# Handoff

## Overview

Standardize session-to-session continuity when an agent must restart
mid-work (plugin updates, context limits, crashes). Replaces ad-hoc
memory files with a disciplined, template-driven handoff protocol.

Two modes:

- `/handoff stop` — Capture current work state before killing the session.
- `/handoff start` — Resume from the last handoff file after restarting.

**Memory policy exemption.** This skill writes to the memory directory
as part of its documented workflow. Because the human invokes `/handoff`
explicitly, the write has implicit approval and is exempt from the
global memory management policy's approval requirement.

## Mode: stop

Write a structured handoff file to the project memory directory:

```text
<memory-dir>/handoff_active.md
```

### Template

The agent fills in the template from conversation context. The agent
writes the content — this skill provides the structure.

```markdown
---
name: active handoff
description: Session handoff — <one-line summary of in-progress work>
type: project
---

## In-progress task

<What the agent was doing when stop was called. Phase, step, branch name,
PR numbers — enough to resume without re-deriving.>

## Completed this session

<Bulleted list of completed items with PR/issue URLs.>

## Remaining work queue

<Numbered list in execution order. Each item is one sentence.>

## Key context

<Anything non-obvious that the next session needs to know: workarounds in
effect, known failures, blocked items, environment state.>

## Restart command

<The exact slash command or instruction to resume, e.g. "/publish" or
"continue with Phase 5 of the publish workflow".>
```

### Behavior

1. Fill in the template from conversation context.
2. Write the file to `<memory-dir>/handoff_active.md`.
3. Add a pointer to `MEMORY.md` (or update the existing pointer):
   `- [Active handoff](handoff_active.md) — <one-line summary>`.
4. Confirm the handoff file was written and tell the user it is safe
   to kill the session.

### Constraints

- Only one active handoff at a time. Writing a new one overwrites
  the previous.
- Do not invent or guess state — if something is unknown, say so in
  the file.
- All issue and PR references must be full URLs, not short `#N`
  references.

## Mode: start

When invoked (or when the agent sees `handoff_active.md` in memory at
session start):

1. Read `<memory-dir>/handoff_active.md`.
2. Summarize it to the user in 3-5 lines: what was in progress, what
   is next.
3. Ask: "Continue from where the last session left off?"
4. If the user confirms, proceed with the restart command / remaining
   work queue.
5. After the user confirms and work resumes, rename the handoff file
   from `handoff_active.md` to `handoff_<date>.md` (archived, no
   longer active). Update the MEMORY.md pointer accordingly.

### Auto-detection

If the agent starts a session and finds `handoff_active.md` in the
memory directory, it should proactively mention it: "There is a
pending handoff from a previous session. Run `/handoff start` to
resume, or ignore it to start fresh."

## Edge cases

- **No active handoff on start**: Tell the user there is no pending
  handoff and exit.
- **Multiple restarts without completing work**: Each `/handoff stop`
  overwrites the active file. Old state is lost — this is intentional;
  only the most recent stop matters.
- **User does not run stop before killing**: No handoff file is
  written. The agent has no special recovery. This is the status quo
  and is acceptable.

## What this is NOT

- Not a task tracker. It captures a snapshot for session continuity,
  not a persistent backlog.
- Not a replacement for issue tracking. Work items belong in GitHub
  issues.
- Not a memory dump. It captures only what is needed to resume — not
  everything that happened.
