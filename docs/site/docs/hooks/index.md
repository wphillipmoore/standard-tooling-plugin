# Hooks

The plugin provides PreToolUse, PostToolUse, and Stop hooks that enforce
workflow guardrails mechanically. These replace duplicated documentation
rules across all consuming repos.

## PreToolUse Hooks

### Bash Hooks

**block-raw-git-commit**
:   Blocks raw `git commit` commands.
    Enforces use of `st-commit`.

**block-raw-gh-pr-create**
:   Blocks raw `gh pr create` commands.
    Enforces use of `st-submit-pr`.

**block-protected-branch-work**
:   Blocks commits on protected branches (`main`, `develop`).

**block-heredoc**
:   Blocks heredoc syntax (`<<EOF`) to prevent shell escaping
    failures.

### Write/Edit Hooks

**block-memory-writes**
:   Blocks writes to `MEMORY.md`.
    Enforces version-controlled documentation.

## PostToolUse Hooks

### Bash Hooks

**remind-finalize**
:   After `st-submit-pr` runs, reminds to run
    `st-finalize-repo`.

**detect-deprecation-warnings**
:   Detects deprecation warnings in test output and prompts
    triage.

## Stop Hooks

**stop-guard-finalization**
:   Prevents session exit if a PR was submitted without
    finalization.

## How Hooks Work

Hooks are defined in `hooks/hooks.json` and implemented as shell
scripts in `hooks/scripts/`. Each hook receives the tool input as
JSON on stdin and returns a JSON response indicating whether to
allow or deny the action.

### PreToolUse Response

A PreToolUse hook can deny an action by returning:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Reason."
  }
}
```

### PostToolUse Response

A PostToolUse hook can inject context by returning:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Reminder message."
  }
}
```

### Stop Response

A Stop hook can block session exit by returning:

```json
{
  "decision": "block",
  "reason": "Reason the session cannot exit."
}
```
