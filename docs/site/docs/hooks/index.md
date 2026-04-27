# Hooks

The plugin provides PreToolUse, PostToolUse, and Stop hooks that enforce
workflow guardrails mechanically. These replace duplicated documentation
rules across all consuming repos — rules that humans and agents
alike routinely drift from when enforcement is prose-only.

> **Looking for the overall workflow?** See
> [`standard-tooling` → Git Workflow](https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/site/docs/guides/git-workflow.md)
> for the big-picture guide covering branching, commit/PR/finalize
> cycle, worktrees, and how these plugin hooks compose with the
> pre-commit git hook. This page is the reference for the plugin's
> hooks specifically; the pre-commit git hook is documented in
> [`standard-tooling` → Git Hooks and Validation](https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/git-hooks-and-validation.md).

Each entry below covers what the hook catches, why it exists, and how
to achieve the intent correctly when the hook blocks you.

## PreToolUse Hooks — Bash

### block-raw-git-commit

**What.** Denies Bash tool invocations that call `git commit` (or
pipe-chained equivalents).

**Why.** `st-commit` constructs standards-compliant conventional
commit messages with the co-author trailer resolved from
`docs/repository-standards.md`. Hand-written `git commit -m`
invocations drift from the commit-message standard over time; raw
commits also bypass the co-author resolution entirely.

**Alternative.** Use
[`st-commit`](https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/site/docs/reference/dev/commit.md)
with the appropriate `--type`, `--scope`, `--message`, `--body`, and
`--agent` flags.

### block-raw-gh-pr-create

**What.** Denies Bash tool invocations that call `gh pr create`.

**Why.** `st-submit-pr` builds standards-compliant PR bodies with
proper issue linkage keywords (`Fixes`, `Closes`, `Resolves`, `Ref`)
that the `pr-issue-linkage` CI validator requires. Manual `gh pr
create` commands routinely ship without linkage and fail CI on the
first try.

**Alternative.** Use
[`st-submit-pr`](https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/site/docs/reference/dev/submit-pr.md)
with `--issue`, `--summary`, `--linkage`, and `--notes` flags.

### block-protected-branch-work

**What.** Denies Bash tool invocations that run `git commit` or
`st-commit` when the effective working directory falls outside the
worktree convention's allowed locations.

**Why.** Behavior depends on whether the target repo has adopted the
[worktree convention](https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/specs/worktree-convention.md).
The hook detects adoption by looking for a `.worktrees/` line in the
repo's `.gitignore`. On adopted repos, commits must originate from
inside `.worktrees/<name>/`; the main tree is read-only. On
non-adopted repos, the hook falls back to the legacy behavior of
blocking commits on `main` or `develop` regardless of directory.

**Alternative.** On adopted repos: create a worktree with
`git worktree add .worktrees/issue-N-<slug> -b feature/N-<slug>
origin/develop` and run all edits + commits from inside that
directory. On non-adopted repos: create and check out a feature
branch with a name matching the repo's `branching_model` prefixes.

This hook complements the pre-commit git hook's
[protected-branch check](https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/git-hooks-and-validation.md#pre-commit)
— this one catches the agent-tool invocation early; the pre-commit
hook catches every `git commit` regardless of how it was invoked.

### block-heredoc

**What.** Denies Bash tool invocations that contain heredoc syntax
(`<<EOF`, `<<'EOF'`, etc.) in CLI arguments.

**Why.** Heredocs routinely produce incorrect escaping when passed
through multiple shell layers (agent → Bash tool → subprocess →
CLI). Several CLIs (`gh`, `git commit`, `curl`) silently succeed
with malformed content, producing invalid commit messages, broken
PR bodies, or corrupt JSON bodies. Writing to a file and passing it
via `--body-file` / `--file` / `$(cat <path>)` avoids the entire
class of bug.

**Alternative.** Write the multi-line content to a temp file and
reference it: `--body-file /tmp/body.txt` or
`--body "$(cat /tmp/body.txt)"`.

### block-associative-arrays

**What.** Denies Bash tool invocations that use bash 4+ associative
arrays (`declare -A`, `typeset -A`).

**Why.** The hook scripts and `st-docker-run` dispatcher themselves
run on the host shell, which on macOS is bash 3.2 (Apple has not
shipped a newer bash since the GPL license change). Associative
arrays silently fail on macOS bash 3.2, producing hard-to-debug
behavior. Inside the dev container bash is modern, but the scripts
that *launch* the container cannot assume that environment.

**Alternative.** Use parallel indexed arrays, or switch to awk/jq
for key-value lookups. If you genuinely need associative arrays,
the code belongs inside the container, not in host scripts.

## PreToolUse Hooks — Write|Edit

*(none currently active — `block-memory-writes` was removed on
2026-04-23 when feedback memory was re-enabled fleet-wide.)*

## PostToolUse Hooks — Bash

### remind-finalize

**What.** After a successful `st-submit-pr` run, injects a reminder
to run `st-finalize-repo` once the PR merges.

**Why.** Finalization is easy to forget — the PR is created and
attention moves elsewhere. `st-finalize-repo` pulls the merged
change into local develop, deletes the merged feature branch, and
prunes remote refs. Without it, local state diverges from remote
and future PRs get confused.

**Alternative.** Do run `st-finalize-repo` once the PR merges.
There's no intent this hook blocks — it's a reminder, not a denial.

### detect-deprecation-warnings

**What.** Scans test output and command output for deprecation
warnings; surfaces them to the agent for triage.

**Why.** Deprecation warnings get silently tolerated for months
until the deprecated feature is removed. Surfacing them at the
moment they first appear makes them trackable via the
[deprecation-triage skill](../skills/index.md#deprecation-triage)
while the context is fresh.

**Alternative.** Triage the warning via the `deprecation-triage`
skill — either fix it now or capture it in a tracking issue with
clear resolution criteria.

## Stop Hooks

### stop-guard-finalization

**What.** Blocks session exit if a PR was submitted in this session
but `st-finalize-repo` was not run afterward. Checks the
transcript for `st-submit-pr` and `st-finalize-repo` invocations.

**Why.** Prevents the "submitted a PR, never finalized" failure
mode where local state stays on a merged feature branch and future
work starts from a stale base. This is a soft enforcement of the
same lifecycle the `remind-finalize` PostToolUse hook encourages.

**Override.** The hook honors `stop_hook_active=true` to prevent
infinite loops — if a Stop hook has already continued the session
once, it won't block again. In normal use: finalize the PR before
trying to end the session, or (if the PR has legitimately not
merged yet) check with `gh pr view` and wait.

## Hooks deliberately not provided

### Per-edit linting / validation

The plugin does **not** ship a `PostToolUse` Write|Edit hook that
runs ruff / mypy / yamllint / markdownlint / shellcheck on each
edited file. An earlier version did (`validate-on-edit.sh` plus
per-language `validate-*.sh` scripts); it was removed in
[#91](https://github.com/wphillipmoore/standard-tooling-plugin/issues/91).

**Why removed.** Each per-edit invocation paid the dev-container
startup cost (1–3 s on typical hardware) for one file's worth of
work — five container starts for a single Python edit (`ruff check
--fix`, `ruff format`, `ruff check`, `mypy`, `ty check`). Across a
session with dozens of edits, that's minutes of wall-clock overhead
per session, every session. The same checks already run in two
cheaper places: `st-validate-local` covers them in a single
container start before PR submission, and CI re-runs them on every
PR. The per-edit layer was the third copy with the worst
cost-per-value ratio.

**What replaces it.** Nothing per-edit. Validation runs at PR time
via [`st-validate-local`](https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/site/docs/reference/dev/validate-local.md),
which is the documented "only validation command" per every
consuming repo's CLAUDE.md. The
[`block-raw-git-commit`](#block-raw-git-commit) PreToolUse hook
already enforces commits going through `st-commit`, and `st-commit`
runs the pre-commit git hook — so there's a hard gate between
"edits land" and "edits ship."

**Don't re-add this.** A future contributor noticing the absence
should resist the impulse to re-add per-edit validation as a
"missing feature." The cost-per-value math doesn't work; the gap
is intentional.

## How hooks work — technical

Hooks are defined in `hooks/hooks.json` and implemented as shell
scripts in `hooks/scripts/`. Each hook receives the tool input as
JSON on stdin and returns a JSON response indicating whether to
allow, deny, or annotate the action.

### PreToolUse response

A PreToolUse hook can deny an action by writing JSON to stdout and
exiting 0:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Reason the action is being denied."
  }
}
```

Exit 0 with no JSON = allow. Exit 2 = hook errored; Claude Code
surfaces the error to the user.

### PostToolUse response

A PostToolUse hook can inject context by writing JSON and exiting 0:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Message surfaced to the agent."
  }
}
```

PostToolUse hooks cannot un-do the tool action; they can only add
context the agent sees in its next turn. Exit 2 is a fatal hook
error — useful when validation cannot run and the absence of
validation should be visible.

### Stop response

A Stop hook can block session exit by returning:

```json
{
  "decision": "block",
  "reason": "Reason the session cannot exit."
}
```
