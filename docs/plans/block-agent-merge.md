# Implementation Plan: Block agent merge of non-release PRs

**Spec:** [`docs/specs/block-agent-merge.md`](../specs/block-agent-merge.md)
**Issue:** [#162](https://github.com/wphillipmoore/standard-tooling-plugin/issues/162)

## Overview

Three deliverables across two repos, with a dependency ordering
that determines the implementation sequence:

1. **`st-check-pr-merge`** (standard-tooling) — new host command
2. **`st-merge-when-green` branch check** (standard-tooling) —
   defense-in-depth modification
3. **`block-agent-merge.sh` hook** (standard-tooling-plugin) —
   PreToolUse hook + registration + docs

The hook depends on `st-check-pr-merge` being available on PATH,
so standard-tooling ships first.

## Sequence

### Phase 1: standard-tooling — `st-check-pr-merge`

**Repo:** `standard-tooling`
**Branch:** `feature/<N>-check-pr-merge` (issue TBD — file in
standard-tooling)

#### 1a. New module: `src/standard_tooling/bin/check_pr_merge.py`

Entry point that takes a raw Bash command string and determines
whether the merge/approval should be allowed.

**Input:** The raw Bash command string (the full `tool_input.command`
value from the hook's stdin JSON). Passed as a single positional
argument.

**Logic:**

1. Detect which command pattern is present: `gh pr merge` or
   `gh pr review --approve`. If neither (shouldn't happen — the
   hook pre-filters), exit 0.
2. Extract the PR reference (number or URL) from the command
   string. This is the non-trivial parsing step — must handle:
   - `gh pr merge 364`
   - `gh pr merge https://github.com/owner/repo/pull/364`
   - `gh pr merge --squash 364`
   - `gh pr merge --merge --delete-branch <url>`
   - `gh pr review --approve 42`
   - `gh pr review --approve --body "lgtm" <url>`
   - `--repo owner/other-repo` anywhere in the arg list
   - Commands chained with `;`, `&&`, `||` (extract the relevant
     segment first)
3. If `--repo` is present, extract it for the API call. Otherwise
   the API uses the local repo context.
4. Resolve the PR's head branch name via GitHub API:
   `gh pr view <ref> [--repo <repo>] --json headRefName --jq '.headRefName'`
5. Check the branch against the allow-list:
   - `release/*` — match
   - `chore/bump-version-*` — match
   - Anything else — deny
6. Exit codes follow the three-state convention
   ([standard-tooling#373](https://github.com/wphillipmoore/standard-tooling/issues/373)):
   - **Exit 0** — allowed (release-workflow branch)
   - **Exit 1** — denied (tool ran, branch does not match
     allow-list; deny message on stderr)
   - **Exit 2** — unknown (tool could not determine the answer;
     error details on stderr)

**Parsing approach:** Use Python's `shlex.split()` to tokenize
the command string, then walk the token list to find the `gh`
invocation and its arguments. This handles quoting, escaping,
and multi-command chains correctly without shell-level regex.
For chained commands (`; && ||`), split on the chain operators
first, then process only the segment containing `gh pr merge`
or `gh pr review`.

**Deny message on stderr:**

```text
Blocked: agents may not merge non-release PRs. The pr-workflow
policy requires human review and merge for feature/bugfix PRs.
Hand off the PR URL to the user and stop the work cycle.

Only release-workflow PRs (release/* and chore/bump-version-*)
may be agent-merged, and only via st-merge-when-green from the
publish skill. See issue #162.
```

#### 1b. Entry point registration

Add to `pyproject.toml` `[project.scripts]`:

```toml
st-check-pr-merge = "standard_tooling.bin.check_pr_merge:main"
```

#### 1c. Tests: `tests/standard_tooling/test_check_pr_merge.py`

Mock `subprocess.run` (the `gh pr view` call) to control the
returned branch name. Test cases from the spec:

| # | Scenario | Command string | Mocked branch | Expected |
|---|----------|---------------|---------------|----------|
| 1 | Allowed release branch | `gh pr merge 42` | `release/1.4.9` | exit 0 |
| 2 | Allowed bump branch | `gh pr merge 99` | `chore/bump-version-1.4.10` | exit 0 |
| 3 | Blocked feature branch | `gh pr merge 42` | `feature/42-foo` | exit 1, message on stderr |
| 4 | Flags before ref | `gh pr merge --squash 364` | `feature/1-x` | exit 1 (extracts 364) |
| 5 | URL format | `gh pr merge https://github.com/o/r/pull/364` | `release/2.0.0` | exit 0 |
| 6 | `--repo` flag | `gh pr merge --repo o/r 42` | `feature/1-x` | exit 1 (passes --repo to API) |
| 7 | API failure | `gh pr merge 42` | (subprocess error) | exit 2, error on stderr |
| 8 | `gh pr review --approve` | `gh pr review --approve 42` | `feature/1-x` | exit 1 |
| 9 | `gh pr review --approve` allowed | `gh pr review --approve 42` | `release/1.0.0` | exit 0 |
| 10 | Chained command (&&) | `echo hi && gh pr merge 42` | `feature/1-x` | exit 1 |
| 11 | Chained command (;) | `echo hi; gh pr merge 42` | `feature/1-x` | exit 1 |
| 12 | Piped command | `echo 42 \| gh pr merge` | `feature/1-x` | exit 1 |
| 13 | `--repo` with allowed branch | `gh pr merge --repo o/r 42` | `release/1.0.0` | exit 0 |
| 14 | No match (defensive) | `gh issue list` | — | exit 0 |

### Phase 2: standard-tooling — `st-merge-when-green` branch check

**Same repo, can be same branch/PR as Phase 1.**

#### 2a. Modify `src/standard_tooling/bin/merge_when_green.py`

Add a branch-name verification step between argument parsing and
the `wait_for_checks` call. The check resolves the PR's head
branch name via the GitHub API and verifies it matches the
allow-list before proceeding.

Insert after `args = parse_args(argv)`, before the
`wait_for_checks` call:

```python
branch = github.read_output(
    "pr", "view", args.pr, "--json", "headRefName",
    "--jq", ".headRefName"
)
if not _is_release_branch(branch):
    print(
        f"Error: st-merge-when-green is only for release-workflow PRs. "
        f"Branch '{branch}' does not match release/* or chore/bump-version-*.",
        file=sys.stderr,
    )
    return 1
```

Helper function:

```python
import fnmatch

_ALLOWED_PATTERNS = ("release/*", "chore/bump-version-*")

def _is_release_branch(branch: str) -> bool:
    return any(fnmatch.fnmatch(branch, p) for p in _ALLOWED_PATTERNS)
```

This `_is_release_branch` helper can also be used by
`st-check-pr-merge` — consider putting it in
`standard_tooling/lib/github.py` or a new
`standard_tooling/lib/release.py` shared module if both commands
need it.

#### 2b. Tests: update `tests/standard_tooling/test_merge_when_green.py`

Add three test cases:

| # | Scenario | Mocked branch | Expected |
|---|----------|---------------|----------|
| 1 | Release branch allowed | `release/1.4.9` | proceeds to merge |
| 2 | Bump branch allowed | `chore/bump-version-1.4.10` | proceeds to merge |
| 3 | Feature branch blocked | `feature/42-foo` | returns 1, does not call merge |

Existing tests need to be updated to mock the new `gh pr view`
call that resolves the branch name. Each existing test that
calls `main()` will need an additional mock returning a
release-branch name so they don't fail on the new gate.

### Phase 3: standard-tooling-plugin — hook and registration

**Repo:** `standard-tooling-plugin`
**Branch:** `feature/<N>-block-agent-merge` (can reuse #162 or
file a new issue)
**Depends on:** Phase 1 shipped and available on PATH (the hook
calls `st-check-pr-merge`)

#### 3a. New file: `hooks/scripts/block-agent-merge.sh`

Follow the established pattern from `block-autoclose-linkage.sh`:

```bash
#!/usr/bin/env bash
# block-agent-merge.sh — PreToolUse hook for Bash.
# Blocks gh pr merge and gh pr review --approve on non-release PRs.
# Delegates branch verification to st-check-pr-merge.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"

input=$(cat)
cwd=$(echo "$input" | jq -r '.tool_input.cwd // .cwd // "."')

if ! is_managed_repo "$cwd"; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command')

# Check for gh pr merge or gh pr review --approve
if ! echo "$command" \
     | grep -qE '(^|[;&|]\s*)gh\s+pr\s+(merge(\s|$)|review\s+.*--approve)'; then
  exit 0
fi

# Delegate to st-check-pr-merge for branch verification.
# Three-state exit codes (standard-tooling#373):
#   0 → allowed (release-workflow PR)
#   1 → denied (tool ran, definitive no)
#   2 → unknown (tool failed, cannot determine)
rc=0
stderr=$(st-check-pr-merge "$command" 2>&1 1>/dev/null) || rc=$?
if [ "$rc" -eq 0 ]; then
  exit 0
fi

if [ "$rc" -eq 1 ]; then
  reason="${stderr:-Denied by st-check-pr-merge (no details provided).}"
elif [ "$rc" -eq 2 ]; then
  reason="st-check-pr-merge could not determine whether this merge is allowed (exit 2). Error: ${stderr:-no details}. Resolve the tool failure before retrying."
else
  reason="st-check-pr-merge exited with unexpected code $rc. Error: ${stderr:-no details}. Cannot determine whether this merge is allowed."
fi

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
```

**Key design points:**

- **Three-state logic.** The hook branches on `st-check-pr-merge`'s
  exit code per the three-state convention
  ([standard-tooling#373](https://github.com/wphillipmoore/standard-tooling/issues/373)):
  exit 0 = allowed, exit 1 = denied, exit 2 = unknown. All three
  produce different messages. The unknown case still blocks the
  merge (a merge we can't verify is not safe to allow), but the
  reason is honest: "the tool failed," not "the tool said no."
  This matters for diagnosis — the user needs to know whether to
  investigate a policy question or a tooling failure.
- The grep pattern matches both `gh pr merge` (with any
  trailing args) and `gh pr review` with `--approve` anywhere
  in the review args. It handles command chains via the
  `(^|[;&|]\s*)` prefix.
- All parsing and API calls happen inside `st-check-pr-merge`.
  The hook is thin: detect pattern, delegate, emit result.
- If `st-check-pr-merge` is not on PATH, `set -euo pipefail`
  causes the hook to exit with a non-1, non-2 code (127 from
  bash), which hits the "unexpected code" branch. The user sees
  that the tool couldn't run — not a false denial reason.

#### 3b. Register in `hooks/hooks.json`

Add to the `PreToolUse` > `Bash` array, after the existing
entries:

```json
{
  "type": "command",
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/block-agent-merge.sh",
  "statusMessage": "Checking for unauthorized PR merge..."
}
```

#### 3c. Document in `docs/site/docs/hooks/index.md`

Add a new subsection under "PreToolUse Hooks — Bash", after
`block-autoclose-linkage`:

```markdown
### block-agent-merge

**What.** Denies Bash tool invocations that call `gh pr merge`
or `gh pr review --approve` on non-release PRs.

**Why.** Agents must not merge feature or bugfix PRs — human
review and merge is required. Skill prose saying "do not merge"
is advisory; agents rationalize past it. This hook makes the
rule mechanical. See
[#162](https://github.com/wphillipmoore/standard-tooling-plugin/issues/162)
for the incident that motivated this.

**Alternative.** Hand off the PR URL to the user for review and
merge. For release-workflow PRs (`release/*` and
`chore/bump-version-*`), use `st-merge-when-green` from the
[`publish` skill](../skills/index.md#publish). The hook
delegates branch verification to `st-check-pr-merge` — see
[`standard-tooling` reference](https://github.com/wphillipmoore/standard-tooling)
for that command's documentation.
```

Also update the "Managed-repo gating" paragraph's list of
exceptions if needed (this hook IS gated, so no change needed
there — just confirm it doesn't claim to be exhaustive).

#### 3d. Manual hook testing

No automated test framework for hook scripts in this repo.
Manual verification per the spec's test plan:

1. **Block case:** Pipe `{"tool_input":{"command":"gh pr merge 42","cwd":"/path/to/managed-repo"}}` to the script with `st-check-pr-merge` returning non-zero. Expect deny JSON.
2. **Allow case:** Same input with `st-check-pr-merge` returning 0. Expect exit 0, no output.
3. **Non-managed repo:** Input with a cwd lacking marker files. Expect exit 0.
4. **No match:** Input with `gh issue list`. Expect exit 0.
5. **`gh pr review --approve`:** Input with review command, `st-check-pr-merge` returning non-zero. Expect deny JSON.

## Cross-repo coordination

### Issue tracking

File two sub-issues in standard-tooling (linked from #162):

1. "Add `st-check-pr-merge` command" — covers Phase 1
2. "Add branch-name check to `st-merge-when-green`" — covers
   Phase 2

These can be a single issue if the changes are small enough to
ship in one PR. The implementation agent should make the call.

### Shipping order

1. **standard-tooling PR** (Phases 1 + 2) → merge, release,
   rebuild dev container image so the new `st-check-pr-merge`
   command is on PATH everywhere.
2. **standard-tooling-plugin PR** (Phase 3) → merge. The hook
   script calls `st-check-pr-merge`, which must already be
   installed.
3. **standard-tooling-plugin release** → ships the hook to all
   consuming repos.

### Shared helper: `_is_release_branch`

Both `st-check-pr-merge` and the `st-merge-when-green` branch
check need the same allow-list match. Factor this into a shared
location — either `standard_tooling/lib/github.py` or a new
`standard_tooling/lib/release.py`:

```python
import fnmatch

_RELEASE_BRANCH_PATTERNS = ("release/*", "chore/bump-version-*")

def is_release_branch(branch: str) -> bool:
    """Return True if the branch matches a release-workflow pattern."""
    return any(fnmatch.fnmatch(branch, p) for p in _RELEASE_BRANCH_PATTERNS)
```

Single source of truth — if the allow-list ever changes, one
edit covers both commands.

## TDD task breakdown

Rewrites of the implementation tasks in red/green/refactor format.
Phase 3 (hook script) has no automated test framework in this repo
so it is excluded — it uses manual verification per §3d.

### Task 1: Shared `is_release_branch` helper

**Requirement:** Spec §What to allow — branch allow-list matching.

#### RED

- Write tests in `tests/standard_tooling/test_release.py` (or
  wherever the helper lands) asserting:
  - `is_release_branch("release/1.4.9")` returns True
  - `is_release_branch("chore/bump-version-1.4.10")` returns True
  - `is_release_branch("feature/42-foo")` returns False
  - `is_release_branch("release")` returns False (no trailing slash/version)
  - `is_release_branch("chore/bump-version")` returns False
  - `is_release_branch("")` returns False
- Expected failure: `ImportError` — module doesn't exist yet.

#### GREEN

- Create the module with `is_release_branch()` using `fnmatch`.
- All tests pass.

#### REFACTOR

- Confirm the pattern tuple is a module-level constant.
- Confirm the function is importable from both `check_pr_merge`
  and `merge_when_green` without circular imports.

### Task 2: `st-check-pr-merge` — command parsing

**Requirement:** Spec §Architecture — extract PR ref from arbitrary
`gh pr merge` / `gh pr review --approve` command strings.

#### RED

- Write tests for an `extract_pr_ref(command_string)` function:
  - `gh pr merge 42` → ref=`42`, repo=None
  - `gh pr merge https://github.com/o/r/pull/364` → ref=URL, repo=None
  - `gh pr merge --squash 364` → ref=`364`
  - `gh pr merge --merge --delete-branch <url>` → ref=URL
  - `gh pr review --approve 42` → ref=`42`
  - `gh pr review --approve --body "lgtm" <url>` → ref=URL
  - `gh pr merge --repo o/r 42` → ref=`42`, repo=`o/r`
  - `echo hi && gh pr merge 42` → ref=`42`
  - `echo hi; gh pr merge 42` → ref=`42`
  - `gh issue list` → raises or returns None (no match)
- Expected failure: `ImportError` or `AttributeError` — function
  doesn't exist yet.
- If any test passes unexpectedly: the parsing logic may already
  exist somewhere (check `lib/github.py`).

#### GREEN

- Implement `extract_pr_ref()` using `shlex.split()` with chain
  splitting. Return a `(ref, repo)` tuple or raise on no match.
- All tests pass.

#### REFACTOR

- Look for: hardcoded `gh` subcommand lists that should be
  constants, duplicated chain-splitting logic that could be a
  helper, shlex error handling that could be consolidated.

### Task 3: `st-check-pr-merge` — main entry point

**Requirement:** Spec §Architecture — full pipeline: parse → API
→ allow-list check → exit code.

#### RED

- Write end-to-end tests for `main()` (test cases 1–14 from §1c
  table). Mock `subprocess.run` for the `gh pr view` call.
- Assert exit codes: 0 for allowed, 1 for denied, 2 for API
  failure.
- Assert stderr content for exit 1 and exit 2 cases.
- Expected failure: `main()` doesn't exist or doesn't call
  `extract_pr_ref` yet.

#### GREEN

- Wire `main()`: parse args → `extract_pr_ref()` → `gh pr view`
  → `is_release_branch()` → exit code.
- Catch `subprocess.CalledProcessError` for API failures → exit 2.
- All 14 tests pass.

#### REFACTOR

- Ensure the deny message is a constant, not inline.
- Confirm `sys.exit()` is not called directly — return the exit
  code so tests can assert without `SystemExit` exceptions.
- Check that `--repo` forwarding doesn't duplicate the argument
  construction logic.

### Task 4: `st-check-pr-merge` — entry point registration

**Requirement:** Spec §Implementation — command available on PATH.

#### RED

- Confirm `st-check-pr-merge --help` fails (command not found).

#### GREEN

- Add entry point to `pyproject.toml`.
- Reinstall package (`pip install -e .`).
- `st-check-pr-merge --help` succeeds.

#### REFACTOR

- Verify entry point ordering in `pyproject.toml` is alphabetical
  or grouped consistently with existing entries.

### Task 5: `st-merge-when-green` — branch check

**Requirement:** Spec §Defense in depth — refuse to merge
non-release branches.

#### RED

- Add three tests to `test_merge_when_green.py`:
  - `release/1.4.9` → proceeds to merge
  - `chore/bump-version-1.4.10` → proceeds to merge
  - `feature/42-foo` → returns 1, `github.merge` not called
- Update existing tests to mock the new `gh pr view` call
  (return `release/x.y.z` so they don't fail on the new gate).
- Expected failure: existing tests fail because the new
  `gh pr view` mock is missing; new tests fail because the branch
  check doesn't exist yet.

#### GREEN

- Add branch-name resolution and `is_release_branch()` check
  to `main()`, between `parse_args` and `wait_for_checks`.
- All tests pass (existing + new).

#### REFACTOR

- Confirm the error message goes to stderr, not stdout.
- Confirm the function uses the shared `is_release_branch`
  helper, not a local copy of the pattern.

## Risk notes

- **`st-check-pr-merge` not on PATH:** If the plugin is updated
  before standard-tooling, the hook will fail with a command-not-found
  error. This surfaces as a hook error (visible to user), not a
  silent pass. The shipping order above prevents this, but document
  the failure mode.
- **shlex edge cases:** Python's `shlex.split()` handles most
  shell quoting correctly, but may behave unexpectedly with
  complex nested quoting or process substitution. The input is
  Claude Code's Bash tool command string, which is typically
  straightforward. If edge cases surface, they'll manifest as
  deny-by-default (resolution failure), which is the safe
  direction.
- **Regex false positive on `gh pr review --approve`:** The grep
  pattern `gh\s+pr\s+review\s+.*--approve` could match a comment
  body containing `--approve` as text. In practice, `gh pr review`
  with `--approve` is always a mechanical approval — the risk of
  false positive is negligible.
