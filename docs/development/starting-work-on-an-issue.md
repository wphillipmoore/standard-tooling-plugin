# Starting work on an issue

This doc describes how to set up a worktree and branch for work on
a GitHub issue, including resolution of project-board issues and
cross-repo sub-issues. It replaces the former `branch-workflow`
skill (eliminated in
[#55](https://github.com/wphillipmoore/standard-tooling-plugin/issues/55))
— the substance is the same; the format is now a guideline that
the consuming skills (`pr-workflow`, etc.) and `CLAUDE.md` reference
directly.

## When this applies

Use this procedure at the start of any work session that involves
code changes:

- "Work on issue `#42`"
- "Implement `<repo issue URL>`"
- "Begin work on `<project issue URL>`"
- Discovering mid-implementation that work is needed in a second
  repo

The procedure must complete before any code changes are made.

## Invariants

Two rules govern every branch / worktree this procedure produces:

1. Every work branch includes the **repo issue number** in its
   name (`<type>/<N>-<slug>`).
2. **At most one worktree per issue per repository** at any time.
   Re-use, don't stack.

## Quick path — simple repo issue

When the input is a repo-local issue (URL, `#N`, or a bare number)
and you are at the repo root with a clean main worktree:

```bash
# 1. Validate the issue exists and capture title for the slug
gh issue view <N> --json number,title,state --jq '.'

# 2. Decide branch type from issue context — feature is the
#    default; use bugfix for non-urgent defect fixes; hotfix only
#    for production-blocking issues branched from main
TYPE=feature   # or bugfix | hotfix

# 3. Construct a kebab-case slug from the issue title
#    (2–4 tokens, keep the full branch name under 60 chars)
SLUG=<short-slug>

# 4. Create the worktree on a fresh feature branch from develop
git fetch origin --quiet
git worktree add ".worktrees/issue-${N}-${SLUG}" \
  -b "${TYPE}/${N}-${SLUG}" origin/develop
```

Then either:

- **Continue in the current session.** Use the worktree's absolute
  path for all Read / Edit / Write tool calls. `cd` into the
  worktree before any Bash command that touches files.
- **Spawn a parallel agent.** Start a new Claude Code session at
  the project root and pass the agent the prompt template from
  [`CLAUDE.md` → Agent prompt contract](../../CLAUDE.md#agent-prompt-contract).

Do **not** start a session from inside `.worktrees/<name>/`. The
session's CWD must be the project root for memory-path stability.

## Full reference

### Resolving the input

The input can be one of three forms. Determine which, then resolve
to a repo-local issue number in the current repository.

#### Form 1 — repo issue URL or number

Examples: `https://github.com/owner/repo/issues/42`, `#42`, `42`.

If the issue is in the **current repository**, use it directly.
If it is in a **different repository**, treat it as a cross-repo
parent and follow the [Sub-issue flow](#sub-issue-flow).

Validate:

```bash
gh issue view <N> --repo <owner/repo> --json number,title,state
```

Capture: `issue_number`, `issue_repo`, `issue_title`.

#### Form 2 — project issue URL

Example:
`https://github.com/users/<owner>/projects/<number>/views/<view>?pane=issue&itemId=<id>`

Project issue URLs do not encode a repo issue number directly. The
`itemId` is a database ID; resolve it to the underlying issue:

```bash
gh api graphql -f query='
{
  user(login: "<owner>") {
    projectV2(number: <project_number>) {
      items(first: 100) {
        nodes {
          id
          databaseId
          content {
            ... on Issue {
              number
              title
              repository { nameWithOwner }
            }
          }
        }
      }
    }
  }
}'
```

Find the item whose `databaseId` matches the URL's `itemId`.
Extract `number`, `title`, and `repository.nameWithOwner` from its
`content`. If the resolved repo matches the current repository,
use the issue number directly. Otherwise treat it as a cross-repo
parent and follow the sub-issue flow below.

Capture: `parent_repo`, `parent_number`, `parent_title`.

### Sub-issue flow

When the resolved issue lives in a different repo than the current
working directory:

1. **Check for an existing sub-issue** in the current repo:

   ```bash
   gh api repos/<parent_owner>/<parent_repo>/issues/<parent_number>/sub_issues \
     --jq '.[] | select(.repository.full_name == "<current_repo>") | {number, title}'
   ```

2. **If a sub-issue exists**, use its number.

3. **If no sub-issue exists**, create one:

   ```bash
   gh issue create \
     --repo <current_repo> \
     --title "<parent_title>" \
     --body-file <tempfile>
   ```

   Body content:

   ```text
   Sub-issue of <parent_owner>/<parent_repo>#<parent_number>.

   See parent issue for full context and acceptance criteria.
   ```

4. **Link it as a sub-issue** of the parent:

   ```bash
   child_db_id=$(gh api \
     repos/<current_owner>/<current_repo>/issues/<child_number> \
     --jq '.id')

   gh api \
     repos/<parent_owner>/<parent_repo>/issues/<parent_number>/sub_issues \
     --method POST -F sub_issue_id="$child_db_id"
   ```

5. **Add to the parent's project** (if the parent is on a project):

   ```bash
   # Identify the parent's project
   gh api graphql -f query='
   {
     repository(owner: "<parent_owner>", name: "<parent_repo>") {
       issue(number: <parent_number>) {
         projectItems(first: 5) {
           nodes { project { number title } }
         }
       }
     }
   }'

   # Add the new sub-issue to the same project
   gh project item-add <project_number> \
     --owner <owner> \
     --url <child_issue_url> \
     --format json --jq '.id'
   ```

Capture: `issue_number` — the repo-local number to use for
worktree+branch creation.

### Existing-worktree detection

Before creating a new worktree, check whether one already exists
for this issue:

```bash
existing=$(ls -d ".worktrees/issue-${issue_number}-"* 2>/dev/null | head -1)
```

- **If `existing` is non-empty**: a worktree already exists. Reuse
  it — report its path. Do not create a duplicate.
- **If empty**: continue to existing-branch detection.

### Existing-remote-branch detection

Before creating a new branch, check whether the remote already has
one for this issue:

```bash
git fetch origin --quiet
remote_branch=$(git branch -r --list \
  "origin/feature/${issue_number}-*" \
  "origin/bugfix/${issue_number}-*" \
  "origin/hotfix/${issue_number}-*" \
  | head -1 | sed 's|.*origin/||')
```

- **If `remote_branch` is non-empty**: create a worktree that
  checks out the existing branch:

  ```bash
  slug="${remote_branch#*/${issue_number}-}"
  git worktree add ".worktrees/issue-${issue_number}-${slug}" \
    -B "${remote_branch}" "origin/${remote_branch}"
  ```

- **If empty**: create a fresh worktree+branch from `origin/develop`
  per the [Quick path](#quick-path--simple-repo-issue).

### Cross-repo work

When mid-implementation work reveals that another repo needs
changes:

1. Apply this procedure inside that other repo, with the same
   parent issue as input.
2. The sub-issue flow creates a repo-specific sub-issue
   automatically.
3. Each repo gets its own worktree+branch with its own issue
   number.

The one-worktree-per-issue invariant must hold in every repo
involved.

## Reporting back to the user

After the procedure completes, surface:

- Issue number and title.
- Whether a worktree was reused or a new one created.
- The full worktree absolute path.
- The full branch name.
- If a sub-issue was created: its URL and the parent issue link.
- The agent prompt template from
  [`CLAUDE.md` → Agent prompt contract](../../CLAUDE.md#agent-prompt-contract)
  if the user wants to spawn a parallel agent (skip if the current
  session is doing the work).

## What does *not* belong here

- Validation checks, commit message standards, PR submission, or
  any work that happens after the worktree is set up. Those are
  the responsibility of the
  [`pr-workflow` skill](../../skills/pr-workflow/SKILL.md) and the
  underlying `st-commit` / `st-submit-pr` tools.
- Worktree teardown after merge. That is `st-finalize-repo`'s job;
  see [`pr-workflow` → Finalization](../../skills/pr-workflow/SKILL.md#finalization).
