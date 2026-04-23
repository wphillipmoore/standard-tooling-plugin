# standard-tooling-plugin

Claude Code plugin for the standard-tooling ecosystem. Delivers
hooks, skills, and agents that enforce the fleet workflow mechanically
in every Claude Code session.

## Table of Contents

- [What this plugin does](#what-this-plugin-does)
- [Install](#install)
- [Component inventory](#component-inventory)
- [Plugin namespace](#plugin-namespace)
- [Related repositories](#related-repositories)
- [Development](#development)

## What this plugin does

This plugin is the behavioral half of a two-repo system:

| Repo | Delivers | Via |
|---|---|---|
| [`standard-tooling`](https://github.com/wphillipmoore/standard-tooling) | Python CLIs (`st-commit`, `st-submit-pr`, `st-docker-run`, …) and bash git hooks | PATH + `core.hooksPath` |
| **`standard-tooling-plugin`** (this repo) | Claude Code hooks, skills, agents, commands | Claude Code plugin system |

The two are complementary: `standard-tooling` makes the tools
available; this plugin ensures Claude Code uses them correctly —
blocking raw `git commit` in favor of `st-commit`, blocking raw
`gh pr create` in favor of `st-submit-pr`, routing per-file
validation through the dev container, and so on.

## Install

**Recommended install path** for consuming repositories is the full
walkthrough documented in standard-tooling:

- Quickstart:
  <https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/site/docs/getting-started.md>
- Detailed walkthrough with rationale:
  <https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/site/docs/guides/consuming-repo-setup.md>

The short version: add this to your repo's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "standard-tooling-marketplace": {
      "source": {
        "source": "github",
        "repo": "wphillipmoore/standard-tooling-plugin"
      }
    }
  },
  "enabledPlugins": {
    "standard-tooling@standard-tooling-marketplace": true
  }
}
```

Commit that file. Claude Code discovers and enables the plugin on
session start.

**Prerequisite:** this plugin assumes `st-docker-run` is available on
your host PATH — several hooks depend on it. Install steps are in
the standard-tooling Getting Started guide above; missing
`st-docker-run` produces a clear fatal error from the validation
hooks on first edit.

## Component inventory

### Hooks

PreToolUse, PostToolUse, and Stop hooks that enforce guardrails
mechanically.

| Hook | Matcher | Purpose |
|---|---|---|
| `block-raw-git-commit` | PreToolUse/Bash | Redirects raw `git commit` to `st-commit` |
| `block-raw-gh-pr-create` | PreToolUse/Bash | Redirects raw `gh pr create` to `st-submit-pr` |
| `block-protected-branch-work` | PreToolUse/Bash | Blocks commits from outside `.worktrees/*` on repos that adopt the worktree convention; otherwise blocks commits on `develop`/`main` |
| `block-heredoc` | PreToolUse/Bash | Blocks `<<EOF` in CLI args (use `--body-file` or `$(cat <file>)`) |
| `block-associative-arrays` | PreToolUse/Bash | Blocks bash 4+ associative arrays — host scripts must run on macOS bash 3.2 |
| `validate-on-edit` | PostToolUse/Write\|Edit | Dispatches per-language validators (`validate-markdown.sh`, `validate-python.sh`, `validate-shell.sh`, `validate-yaml.sh`) inside the dev container |
| `remind-finalize` | PostToolUse/Bash | After `st-submit-pr`, reminds to run `st-finalize-repo` |
| `detect-deprecation-warnings` | PostToolUse/Bash | Surfaces deprecation warnings from test output for triage |
| `stop-guard-finalization` | Stop | Blocks session exit if a PR was submitted but not finalized |

Full reference:
<https://github.com/wphillipmoore/standard-tooling-plugin/blob/develop/docs/site/docs/hooks/index.md>.

### Skills

Shared workflow skills, invoked as `/standard-tooling:<name>`.

| Skill | Purpose |
|---|---|
| `branch-workflow` | Resolve an issue, ensure a correctly-named branch exists |
| `pr-workflow` | Guide PR creation, submission, and finalization |
| `publish` | Drive library/tooling/documentation release flow |
| `project-issue` | Create structured GitHub issues via guided questions |
| `dependency-update` | Run the dependency-update workflow |
| `deprecation-triage` | Triage deprecation warnings into tracking issues |
| `summarize` | Decision / operation / stream-of-consciousness summaries |

Full reference:
<https://github.com/wphillipmoore/standard-tooling-plugin/blob/develop/docs/site/docs/skills/index.md>.

### Agents

| Agent | Purpose |
|---|---|
| `bootstrap` | Session-start preflight: repository profile, branch state, dispatcher availability, standards reference, git hooks |

## Plugin namespace

All skills are namespaced under `standard-tooling`:

```text
/standard-tooling:<skill-name>
```

Example: `/standard-tooling:pr-workflow`.

## Related repositories

- [`standard-tooling`](https://github.com/wphillipmoore/standard-tooling)
  — Python CLIs, bash validators, git hooks (consumed via PATH).
- [`standard-tooling-docker`](https://github.com/wphillipmoore/standard-tooling-docker)
  — Dev container images (`ghcr.io/wphillipmoore/dev-python`, `dev-go`,
  etc.) that `st-docker-run` dispatches into.
- [`standard-actions`](https://github.com/wphillipmoore/standard-actions)
  — Shared GitHub Actions composite actions consumed by CI.

## Development

Contributors working on the plugin itself can load it directly from
the source tree to avoid the marketplace round-trip:

```bash
claude --plugin-dir /path/to/standard-tooling-plugin
```

This bypasses `~/.claude/plugins/cache/` and mounts the working tree
as the plugin source. Useful for iterating on hooks and skills before
release.

Reporting issues or requesting changes: open an issue at
<https://github.com/wphillipmoore/standard-tooling-plugin/issues>.
