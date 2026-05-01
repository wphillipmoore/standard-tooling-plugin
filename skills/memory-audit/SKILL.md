---
name: memory-audit
description: Collaborative review of memory files — verify, assess staleness, and route each entry to the correct scope with human approval.
---

# Memory Audit

Structured walk-through of a project's memory files. For each file,
verify its claims against the codebase, suggest a disposition, and
wait for the human to decide before acting.

## Workflow

### 1. Inventory

Read `MEMORY.md` and list all `.md` files in the memory directory.
Report:

- File count and breakdown by type (feedback, project, reference,
  user, handoff).
- Last-modified date for each file.
- Orphan files — present in the directory but not indexed in
  `MEMORY.md`.
- Broken links — entries in `MEMORY.md` pointing to files that no
  longer exist.

### 2. Walk-through

Present each memory file one at a time. For each:

**Show:** Name, type (from frontmatter), and content. Summarize if
the file exceeds ~30 lines.

**Verify:** Actively check claims against the codebase:

- If the memory references a file path, check it exists.
- If it references a function, pattern, or convention, grep for it.
- If it references a tool or command, check if it is on PATH.

Present verification findings alongside the content.

**Assess:** Based on verification results, is this entry still
accurate?

**Suggest disposition** with reasoning — one of:

| Disposition | When to use |
|---|---|
| **Keep** | Still accurate, correctly scoped to this repo. |
| **Update** | Substance is right, content needs refreshing. |
| **Relocate → global CLAUDE.md** | Cross-repo preference, not repo-specific. |
| **Relocate → plugin/skill issue** | About standard-tooling suite behavior. |
| **Delete** | Stale, redundant, or no longer relevant. |

### 3. Human decides

Wait for the human to confirm or override the suggestion. Do not
proceed until the human responds. One file at a time — no batching.

### 4. Execute

After the human decides:

- **Keep:** No change.
- **Update:** Edit the file. Show the diff before and after.
- **Relocate → global CLAUDE.md:** Draft the addition to
  `~/.claude/CLAUDE.md`. Show the draft. Write on approval.
- **Relocate → plugin/skill issue:** Draft the issue body. Show the
  draft. Create the issue with `gh issue create` on approval.
- **Delete:** Remove the file and its index entry from `MEMORY.md`.

### 5. Reconcile index

After all files are reviewed:

- Update `MEMORY.md` to reflect the final state (removed entries,
  newly indexed orphans, etc.).
- Ensure the policy header is intact. If missing or outdated, restore
  it per the `memory-init` skill's canonical header.

## Constraints

- **One repo per audit.** Operates on the current project's memory
  directory only.
- **No batch mode.** Every disposition requires human confirmation.
- **Policy header is sacred.** Never remove or modify the policy
  header except to update it to the canonical version.
