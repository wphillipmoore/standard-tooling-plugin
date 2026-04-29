# Spec: Hard gate to prevent agent from merging non-release PRs

**Issue:** [#162](https://github.com/wphillipmoore/standard-tooling-plugin/issues/162)

## Problem

An agent merged a feature PR directly via `gh pr merge`, bypassing
human review. The pr-workflow skill says "do not merge the PR" but
skill prose is advisory — the agent rationalized past it. There is
no mechanical enforcement preventing `gh pr merge` on any PR.

## Design

A PreToolUse hook that intercepts Bash tool calls containing
`gh pr merge` or `gh pr review --approve` and denies them unless
the target is a release-workflow PR.

### What to block

| Command pattern | Reason |
|---|---|
| `gh pr merge` | Direct merge of any PR |
| `gh pr review --approve` | Self-approval (could satisfy a required-reviews gate) |

### What to allow

Release-workflow PRs that the agent is expected to merge via
`st-merge-when-green` from the publish skill. These are identified
by branch name:

- `release/*` — the release PR to main
- `chore/bump-version-*` — the post-publish version bump PR to develop

**Important:** `st-merge-when-green` does NOT need an exemption.
It calls `gh pr merge` internally via Python's subprocess module,
not through Claude Code's Bash tool. The hook only intercepts
commands that pass through the Bash tool boundary. This means:

- `st-merge-when-green <url>` — **not intercepted** (the `gh pr
  merge` happens inside the Python process, never visible to the
  hook)
- `gh pr merge <url>` typed directly — **intercepted and checked**

The allow-list for direct `gh pr merge` exists as a safety net
for cases where an agent calls `gh pr merge` directly on a
release PR instead of using `st-merge-when-green`. This should
not happen in normal operation but the hook should not create a
false-positive block if it does.

### How to determine the branch name

The hook receives only the Bash command string. It must extract
the PR identifier (URL or number) and resolve the branch name.
Two approaches:

**Option A — Extract and query (recommended):** Parse the PR
number or URL from the command, then run `gh pr view <pr>
--json headRefName --jq '.headRefName'` to get the branch name.
This is reliable regardless of how the PR is referenced.

**Option B — Require URL format and parse:** Assume the PR is
always passed as a URL and extract the repo/number, then query.
Less robust but simpler regex.

Option A is preferred because agents may pass PR numbers, URLs,
or variables. The query adds ~200ms latency but runs only when
`gh pr merge` or `gh pr review --approve` is detected — a rare
event.

### Hook behavior

1. Read stdin (JSON with `tool_input.command` and `cwd`).
2. Check managed-repo gate (`is_managed_repo`). Exit 0 if not
   managed.
3. Check if the command contains `gh pr merge` or
   `gh pr review --approve`. Exit 0 if neither.
4. Extract the PR reference from the command (the argument after
   `merge` or after `--approve` in the review case).
5. Query the branch name: `gh pr view <ref> --json headRefName
   --jq '.headRefName'`.
6. If the branch matches `release/*` or `chore/bump-version-*`,
   exit 0 (allow).
7. Otherwise, emit a deny decision with a message explaining:
   - What was blocked and why
   - That the agent should hand off to the user for review and
     merge
   - That `st-merge-when-green` is only for release-workflow PRs
     from the publish skill

### Deny message

```text
Blocked: agents may not merge non-release PRs. The pr-workflow
policy requires human review and merge for feature/bugfix PRs.
Hand off the PR URL to the user and stop the work cycle.

Only release-workflow PRs (release/* and chore/bump-version-*)
may be agent-merged, and only via st-merge-when-green from the
publish skill. See issue #162.
```

## File changes

### New file: `hooks/scripts/block-agent-merge.sh`

PreToolUse hook script following the same structure as
`block-autoclose-linkage.sh`:

- Shebang, `set -euo pipefail`
- Source `lib/managed-repo-check.sh`
- Read stdin, extract cwd, gate on `is_managed_repo`
- Match `gh pr merge` or `gh pr review --approve`
- Extract PR ref, query branch name via `gh pr view`
- Allow if branch matches release pattern, deny otherwise

### Modified: `hooks/hooks.json`

Add the new hook to the `PreToolUse` > `Bash` array:

```json
{
  "type": "command",
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/block-agent-merge.sh",
  "statusMessage": "Checking for unauthorized PR merge..."
}
```

### Modified: `docs/site/docs/hooks/index.md`

Add a section documenting the new hook with the standard
What / Why / Alternative format:

- **What:** Blocks `gh pr merge` and `gh pr review --approve`
  for non-release PRs.
- **Why:** Agents must not merge feature/bugfix PRs. Human review
  is required. Skill prose alone is not reliable — see incident
  in #162.
- **Alternative:** Hand off the PR URL to the user. For release
  PRs, use `st-merge-when-green` from the publish skill.

## Edge cases

### Agent passes PR number vs URL

The hook must handle both `gh pr merge 364` and
`gh pr merge https://github.com/owner/repo/pull/364`. The
`gh pr view` command accepts either form, so this is handled
naturally.

### Agent pipes or chains commands

The regex should match `gh pr merge` anywhere in a pipeline or
command chain (`;`, `&&`, `||`). The existing hooks use patterns
like `(^|[;&|]\s*)gh\s+pr\s+merge` for this.

### gh pr merge with flags before the PR ref

The agent might write `gh pr merge --squash 364` or
`gh pr merge --merge --delete-branch <url>`. The PR ref
extraction must skip flags (tokens starting with `-`).

### gh pr view fails

If `gh pr view` fails (bad PR ref, network error, auth issue),
the hook should **deny by default**. A merge the hook cannot
verify is not safe to allow. The deny message should include the
error for debugging.

### Cross-repo PRs

The agent might merge a PR in a different repo:
`gh pr merge --repo owner/other-repo 42`. The hook should still
intercept and verify. `gh pr view --repo owner/other-repo 42`
handles this.

## Testing

Manual testing by running the hook script directly with crafted
JSON input:

1. **Block case:** Input containing `gh pr merge 42` where PR 42
   is on a `feature/*` branch. Expect deny.
2. **Allow case:** Input containing `gh pr merge <url>` where the
   PR is on a `release/*` branch. Expect allow (exit 0).
3. **Non-managed repo:** Input with a cwd that has no
   `docs/repository-standards.md`. Expect allow (exit 0).
4. **No match:** Input containing `gh issue list`. Expect allow
   (exit 0).
5. **gh pr review --approve block:** Input containing
   `gh pr review --approve 42` on a feature branch. Expect deny.

## Not in scope

- **GitHub branch protection rules** (required reviewers, etc.)
  are defense-in-depth and should be configured separately. This
  spec covers only the agent-side hook.
- **Blocking `st-merge-when-green` on non-release PRs.** The tool
  is only invoked from the publish skill and already documents
  its scope. A hook on it would add complexity without meaningful
  safety gain. If this becomes a concern, file a separate issue.
