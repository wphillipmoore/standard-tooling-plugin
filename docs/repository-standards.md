# Standard Tooling Plugin Repository Standards

## Table of Contents

- [AI co-authors](#ai-co-authors)
- [Repository profile](#repository-profile)
- [Post-merge async workflows](#post-merge-async-workflows)
- [Validation policy](#validation-policy)
- [External tooling dependencies](#external-tooling-dependencies)
- [CI gates](#ci-gates)
- [Commit and PR scripts](#commit-and-pr-scripts)
- [Local deviations](#local-deviations)

## AI co-authors

- Co-Authored-By: wphillipmoore-codex <255923655+wphillipmoore-codex@users.noreply.github.com>
- Co-Authored-By: wphillipmoore-claude <255925739+wphillipmoore-claude@users.noreply.github.com>

## Repository profile

- repository_type: library
- versioning_scheme: semver
- branching_model: library-release
- release_model: tagged-release
- supported_release_lines: 0.x (pre-release)
- primary_language: none

## Post-merge async workflows

Workflows triggered by a merge to `develop` that must be verified
as part of PR finalization. A PR is not "done" until every listed
workflow has reached `conclusion: success` for the merge commit.

| Workflow    | Trigger          | What it does                          |
| ----------- | ---------------- | ------------------------------------- |
| `docs.yml`  | push to `develop`| Rebuild MkDocs site, deploy dev alias |

Repos with additional async post-merge workflows (e.g.,
`docker-publish.yml` in `standard-tooling`) add them to this
table. The `pr-workflow` skill reads this section to determine
which workflows to verify.

## Validation policy

- canonical_local_validation_command: markdownlint .
- validation_required: yes (markdownlint required)

## External tooling dependencies

- markdownlint (markdownlint-cli)

## CI gates

Hard gates (required status checks on `develop`):

- Standards compliance:
  - Repository profile validation (`repo-profile`)
  - Markdownlint (`markdown-standards`)
  - Commit message lint (CI validator)
  - Issue linkage validation (`pr-issue-linkage`)

Local hard gates (pre-commit hooks):

- Branch naming enforcement: branching-model-aware prefix validation.
- Commit message lint: Conventional Commits required.

## Commit and PR scripts

AI agents **must** use the wrapper scripts for commits and PR submission.
Do not construct commit messages or PR bodies manually.

### Committing

```bash
st-commit \
  --type TYPE --message MESSAGE --agent AGENT \
  [--scope SCOPE] [--body BODY]
```

- `--type` (required): `feat|fix|docs|style|refactor|test|chore|ci|build`
- `--message` (required): commit description
- `--agent` (required): `claude` or `codex`
- `--scope` (optional): conventional commit scope
- `--body` (optional): detailed commit body

The script resolves the correct `Co-Authored-By` identity from the
[AI co-authors](#ai-co-authors) section and the git hooks validate the result.

### Submitting PRs

```bash
st-submit-pr \
  --issue NUMBER --summary TEXT \
  [--linkage KEYWORD] [--title TEXT] \
  [--notes TEXT] [--dry-run]
```

- `--issue` (required): GitHub issue number (just the number)
- `--summary` (required): one-line PR summary
- `--linkage` (optional, default: `Fixes`): `Fixes|Closes|Resolves|Ref`
- `--title` (optional): PR title (default: most recent commit subject)
- `--notes` (optional): additional notes
- `--dry-run` (optional): print generated PR without executing

The script detects the target branch and merge strategy automatically.

## Local deviations

- No primary language — this repo contains only Markdown, JSON, and shell
  scripts for Claude Code plugin configuration.
- No language-specific CI (no ruff, mypy, pytest, etc.).
