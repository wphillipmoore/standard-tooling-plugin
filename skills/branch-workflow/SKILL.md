---
name: branch-workflow
description: Ensure a correctly named branch exists for an issue before starting work. Handles project-to-repo issue resolution, sub-issue creation, and existing branch detection.
---

# Branch workflow

## Table of Contents

- [Overview](#overview)
- [When to use](#when-to-use)
- [Workflow](#workflow)
  - [Resolve the issue](#resolve-the-issue)
  - [Check for existing branches](#check-for-existing-branches)
  - [Create the branch](#create-the-branch)
  - [Report](#report)
- [Cross-repo work](#cross-repo-work)
- [Resources](#resources)

## Overview

Ensure that a correctly named, issue-linked branch exists in the current
repository before any work begins. This skill resolves the input (project
issue URL, repo issue URL, or issue number) to a repo-level issue, checks
for existing branches, and either checks out an existing branch or creates
a new one.

This skill enforces two invariants:

1. Every work branch includes the repo issue number in its name.
2. At most one branch per issue per repository exists at any time.

### Tooling

Helper scripts live in the `standard-tooling` sibling repository. Resolve
the path by checking these locations in order:

1. `../standard-tooling` (sibling checkout — preferred)
2. `.standard-tooling` (CI checkout)

```bash
if [ -d "../standard-tooling" ]; then
  TOOLING="../standard-tooling"
elif [ -d ".standard-tooling" ]; then
  TOOLING=".standard-tooling"
fi
```

If neither exists, stop and inform the user.

### Ad-hoc code prohibition

Do NOT write ad-hoc code (inline Python, jq pipelines, etc.) to query
GitHub during this workflow. Every GitHub data lookup is handled by either
a pinned `gh` command documented in this skill or a helper script in
`$TOOLING/scripts/gh/`. If a command is not documented here, it is not
needed.

## When to use

Run this skill **before starting any implementation work**. It must be the
first thing an agent does when given an issue to work on. Do not create
branches manually or skip this workflow.

Typical triggers:

- "Implement this issue" (with a URL)
- "Work on issue #42"
- Starting a new task from a project board
- Discovering mid-implementation that work is needed in another repo

## Workflow

### Resolve the issue

The input may be one of three forms. Determine which and resolve to a repo
issue number in the current repository.

#### Form 1: Repo issue URL or number

Example inputs:

- `https://github.com/owner/repo/issues/42`
- `#42`
- `42`

If the issue is in the **current repository**, use it directly.

If the issue is in a **different repository**, this is a cross-repo
reference. The issue is likely a project-level parent. Treat it as Form 2
(project issue in another repo) and follow the sub-issue flow below.

Validate the issue exists:

```bash
gh issue view <number> --repo <owner/repo> --json number,title,state --jq '.'
```

**Captures**: `issue_number`, `issue_repo`, `issue_title`.

#### Form 2: Project issue URL

Example input:

- `https://github.com/users/<owner>/projects/<number>/views/<view>?pane=issue&itemId=<id>`

Project issue URLs do not directly encode a repo issue number. Extract the
item ID from the URL query parameter and resolve it:

```bash
gh api graphql -f query='
{
  node(id: "<item_node_id>") {
    ... on ProjectV2Item {
      content {
        ... on Issue {
          number
          title
          repository {
            nameWithOwner
          }
        }
      }
    }
  }
}'
```

Note: The `itemId` in the URL is a **database ID** (integer), not the
GraphQL node ID. Convert it first:

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
              repository {
                nameWithOwner
              }
            }
          }
        }
      }
    }
  }
}'
```

Find the item whose `databaseId` matches the URL's `itemId`. Extract the
repo and issue number from its `content`.

If the resolved repo matches the current repository, use the issue number
directly. If not, this is a cross-repo parent — follow the sub-issue flow.

**Captures**: `parent_repo`, `parent_number`, `parent_title`.

#### Sub-issue flow

When the resolved issue lives in a different repo than the current working
directory:

1. **Check for an existing sub-issue** in the current repo. List sub-issues
   of the parent:

   ```bash
   gh api repos/<parent_owner>/<parent_repo>/issues/<parent_number>/sub_issues \
     --jq '.[] | select(.repository.full_name == "<current_repo>") | {number, title}'
   ```

2. **If a sub-issue exists** in the current repo, use its number.

3. **If no sub-issue exists**, create one:

   ```bash
   gh issue create \
     --repo <current_repo> \
     --title "<parent_title>" \
     --body-file <tempfile>
   ```

   The body should contain:

   ```text
   Sub-issue of <parent_owner>/<parent_repo>#<parent_number>.

   See parent issue for full context and acceptance criteria.
   ```

4. **Link it as a sub-issue** of the parent:

   ```bash
   # Get the child issue's database ID
   child_db_id=$(gh api \
     repos/<current_owner>/<current_repo>/issues/<child_number> \
     --jq '.id')

   # Link to parent
   gh api repos/<parent_owner>/<parent_repo>/issues/<parent_number>/sub_issues \
     --method POST -F sub_issue_id="$child_db_id"
   ```

5. **Add to the project**. Determine which project the parent belongs to:

   ```bash
   gh api graphql -f query='
   {
     repository(owner: "<parent_owner>", name: "<parent_repo>") {
       issue(number: <parent_number>) {
         projectItems(first: 5) {
           nodes {
             project {
               number
               title
             }
           }
         }
       }
     }
   }'
   ```

   Add the new sub-issue to the same project:

   ```bash
   gh project item-add <project_number> \
     --owner <owner> \
     --url <child_issue_url> \
     --format json --jq '.id'
   ```

**Captures**: `issue_number` (the repo-local issue number to use for
branching).

### Check for existing branches

Before creating a branch, check if one already exists for this issue:

```bash
git fetch origin
git branch -r | grep -E "origin/(feature|bugfix|hotfix)/${issue_number}-"
```

**If a branch exists**: check it out and report it. Do not create a new
branch.

```bash
git checkout <branch_name>
```

If the branch exists only on the remote:

```bash
git checkout -b <local_name> origin/<branch_name>
```

**If no branch exists**: proceed to create one.

### Create the branch

Determine the branch type based on the issue context:

| Context | Type |
| --- | --- |
| New functionality, refactoring, docs, dependencies | `feature` |
| Non-urgent defect fix | `bugfix` |
| Production-blocking issue (branched from `main`) | `hotfix` |

When in doubt, use `feature`.

Construct the branch name:

```text
{type}/{issue_number}-{short-description}
```

- `{issue_number}`: the repo issue number resolved above
- `{short-description}`: kebab-case, derived from the issue title
  (truncate to keep the full branch name under 60 characters)

Create and push the branch:

```bash
git checkout -b <branch_name>
git push -u origin <branch_name>
```

### Report

Display:

- The issue number and title
- Whether an existing branch was checked out or a new one was created
- The full branch name
- If a sub-issue was created, its URL and the parent issue link

## Cross-repo work

When implementation reveals that additional repos need changes:

1. Re-invoke this skill in each additional repo with the same parent issue.
2. The sub-issue flow will create repo-specific sub-issues automatically.
3. Each repo gets its own branch with its own issue number.

Do not create branches in other repos without running this workflow. The
one-branch-per-issue invariant must hold everywhere.

## Resources

- `docs/code-management/github-issues.md`
- `docs/code-management/github-projects.md`
- `docs/code-management/branching/branching-and-deployment.md`
- `docs/code-management/branching/library-branching-and-release.md`
- `docs/code-management/branching/documentation-branching-model.md`
