# Hooks

The plugin provides PreToolUse, PostToolUse, and Stop hooks that enforce
workflow guardrails mechanically. These replace duplicated documentation
rules across all consuming repos.

> **Looking for the overall workflow?** See
> [`standard-tooling` → Git Workflow](https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/site/docs/guides/git-workflow.md)
> for the big-picture guide covering branching, commit/PR/finalize
> cycle, worktrees, and how these plugin hooks compose with the
> pre-commit git hook. This page is the reference for the plugin's
> hooks specifically; the pre-commit git hook is documented in
> [`standard-tooling` → Git Hooks and Validation](https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/git-hooks-and-validation.md).

## PreToolUse Hooks

### Bash Hooks

**block-raw-git-commit**
:   Blocks raw `git commit` commands.
    Enforces use of `st-commit`.

**block-raw-gh-pr-create**
:   Blocks raw `gh pr create` commands.
    Enforces use of `st-submit-pr`.

**block-protected-branch-work**
:   Blocks commits that shouldn't happen at the project root.
    Behavior depends on whether the target repo has adopted the
    [worktree convention](https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/specs/worktree-convention.md)
    — the hook opts in when it sees a `.worktrees/` line in the
    repo's `.gitignore`. On adopted repos, commits must originate
    from inside `.worktrees/<name>/`; a commit initiated from the
    project root is denied with guidance to create a worktree.
    On non-adopted repos, the hook falls back to the legacy
    behavior of blocking commits on `main` or `develop`.
    Complements the pre-commit git hook's
    [protected-branch check](https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/git-hooks-and-validation.md#pre-commit)
    — this hook catches the agent-tool invocation; the pre-commit
    hook catches every `git commit` regardless of source.

**block-heredoc**
:   Blocks heredoc syntax (`<<EOF`) in CLI args to prevent shell
    escaping failures. Route multi-line content through a temp
    file instead (`--body-file`, `--file`, or `$(cat <path>)`).

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
