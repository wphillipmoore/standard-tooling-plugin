# Hooks

The plugin provides PreToolUse and PostToolUse hooks that enforce
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

## Managed-repo gating

Every hook below **except `block-heredoc`** is gated on a
managed-repo check. A repo is "managed" when `standard-tooling.toml`
exists at the repo root.

When the marker is not present, the gated hooks short-circuit to a
no-op so the plugin doesn't interfere with ad-hoc git work in
unrelated repositories. Detection is a pure-shell walk up from the
bash session's CWD looking for the marker, terminating at a
`.git` boundary or the filesystem root. No `git` subprocess; the
gate's overhead is a handful of `stat()` calls.

`block-heredoc` is intentionally **not** gated — heredoc syntax in
CLI invocations breaks unpredictably regardless of which repo
you're in, so the rule is universal.

See [issue #87](https://github.com/wphillipmoore/standard-tooling-plugin/issues/87)
for the rationale.

## PreToolUse Hooks — Bash

### block-raw-git-commit

**What.** Denies Bash tool invocations that call `git commit` (or
pipe-chained equivalents).

**Why.** `st-commit` constructs standards-compliant conventional
commit messages with the co-author trailer resolved from
`standard-tooling.toml`. Hand-written `git commit -m`
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

### enforce-host-container-split

**What.** Checks the routing of every `st-*`, `gh`, `git`, and
language-toolchain command against the canonical host-vs-container
split from
[#96](https://github.com/wphillipmoore/standard-tooling-plugin/issues/96).

- **Denies** wrapping a host-only tool in `st-docker-run --`
  (e.g., `st-docker-run -- gh issue list`). The host tool needs
  SSH-agent, host git config, or host `gh` auth — the container
  can't satisfy those.
- **Warns** (via `additionalContext`, not deny) when a
  container-only tool is invoked directly — whether bare
  (e.g., `ruff check .`) or wrapped in `st-docker-run --`.
  Both bypass the `scripts/dev/*.sh` abstraction layer that
  each repo maintains. The correct entry point is
  `st-validate-local`, which delegates to those scripts.

The canonical tool lists live in
`hooks/scripts/lib/host-container-tools.sh` so the same source of
truth powers both the hook and any future docs/lint.

**Why.** The drift that produced #96 — 47 days of agents silently
wrapping host tools in the container — was caused by documentation
being the only enforcement mechanism. Issue
[#168](https://github.com/wphillipmoore/standard-tooling-plugin/issues/168)
extended this to also catch agents bypassing the `scripts/dev`
abstraction by calling linters directly (even correctly wrapped in
`st-docker-run`). The agent should never invoke individual
linters — `st-validate-local` handles tool routing internally.

**Alternative.** For denied commands: invoke the host tool
directly (drop the `st-docker-run --` prefix). For warned
commands: use `st-validate-local` instead of invoking individual
linters. See the
[`publish` skill's host-vs-container section](https://github.com/wphillipmoore/standard-tooling-plugin/blob/develop/skills/publish/SKILL.md#host-vs-container-commands)
for the canonical split and rationale.

### block-autoclose-linkage

**What.** Denies `st-submit-pr` invocations that pass `--linkage
Fixes`, `--linkage Closes`, or `--linkage Resolves`.

**Why.** These keywords auto-close the linked issue when the PR
merges. Our workflow has a mandatory post-merge finalization phase
(`st-finalize-repo`) that reconciles local state — an issue closed
at merge time signals "done" while the local environment is stale.
Using `Ref` linkage keeps the issue open until finalization
confirms the work cycle is complete, at which point the agent
closes the issue explicitly.

**Alternative.** Use `--linkage Ref` (or omit `--linkage` — `Ref`
is the intended default once `st-submit-pr` is updated in
`standard-tooling`). After `st-finalize-repo` succeeds, close the
issue with `gh issue close <N>`. The
[`pr-workflow` skill](../skills/index.md#pr-workflow)'s "Close the
issue" step documents this flow.

### block-agent-merge

**What.** Denies Bash tool invocations that call `gh pr merge`
or `gh pr review --approve` on non-release PRs.

**Why.** Agents must not merge feature or bugfix PRs — human
review and merge is required. Skill prose saying "do not merge"
is advisory; agents rationalize past it. This hook makes the
rule mechanical. See
[#162](https://github.com/wphillipmoore/standard-tooling-plugin/issues/162)
for the incident that motivated this.

**How it works.** The hook delegates branch verification to
`st-check-pr-merge`, which resolves the PR's head branch via the
GitHub API and checks it against the release-workflow allow-list
(`release/*`, `chore/bump-version-*`, and
`chore/*-next-cycle-deps-*`). Exit codes follow the
three-state convention
([standard-tooling#373](https://github.com/wphillipmoore/standard-tooling/issues/373)):
0 = allowed, 1 = denied, 2 = unknown. The unknown case still
blocks the merge, but the reason message distinguishes "denied by
policy" from "tool failed" so the user knows whether to investigate
a policy question or a tooling failure.

**Alternative.** Hand off the PR URL to the user for review and
merge. For release-workflow PRs (`release/*` and
`chore/bump-version-*`), use `st-merge-when-green` from the
[`publish` skill](../skills/index.md#publish).

## PreToolUse Hooks — Write|Edit

No hooks currently active in this category.

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

### Stop hook for finalization

The plugin no longer ships a Stop hook that blocks session exit
on "PR submitted but `st-finalize-repo` not run." That hook
(`stop-guard-finalization.sh`) was removed in
[#56](https://github.com/wphillipmoore/standard-tooling-plugin/issues/56).

**Why removed.** Under the current "humans review and merge
feature/bugfix PRs" posture, the agent submits a PR, waits for
CI green, hands off to the user, and **stops** — that's the
correct end of the work cycle. Finalization happens in a later
session, after the user reports the merge. The hook would have
fired on every correct exit, blocking the desired behavior.

**What replaces it.** The
[`pr-workflow` skill](../skills/index.md#pr-workflow)'s
"After the merge" section documents the user-prompted finalize
flow. The
[`remind-finalize`](#remind-finalize) PostToolUse hook still
emits a reminder after `st-submit-pr` so the agent knows to run
`st-finalize-repo` once the merge is reported.

**Don't re-add this.** Re-adding a session-end finalize gate
would block the standard PR submission workflow and force agents
into broken cleanup behavior just to satisfy the hook.

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
