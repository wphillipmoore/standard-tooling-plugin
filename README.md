# standard-tooling-plugin

Claude Code plugin for the standard-tooling ecosystem. Delivers
hooks, skills, and agents that enforce the fleet workflow mechanically
in every Claude Code session.

## Table of Contents

- [What this plugin does](#what-this-plugin-does)
- [Install](#install)
- [Update](#update)
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

**Prerequisite:** this plugin's commands and skills shell out to
`st-commit`, `st-submit-pr`, `st-finalize-repo`, and friends from
the standard-tooling Python package. Install those on your host
PATH first — see the Getting Started guide above.

## Update

After a new release ships, refresh the local install with this
three-step sequence. Each step is required — none of them are
implied by the others.

```text
/plugin marketplace update standard-tooling-marketplace
/plugin update standard-tooling@standard-tooling-marketplace
/reload-plugins
```

What each step does:

1. **`/plugin marketplace update <marketplace>`** — refreshes the
   marketplace index only. It tells Claude Code that a new version
   exists; it does **not** download the new version.
2. **`/plugin update <plugin>@<marketplace>`** — installs the new
   version into the local cache at
   `~/.claude/plugins/cache/<plugin-id>/<version>/`. The previous
   version stays on disk for 7 days as a grace window for
   concurrent sessions, then is removed automatically.
3. **`/reload-plugins`** — applies the new skills / hooks / agents
   to the **current** Claude Code session without restarting.
   Without this, the running session keeps using the old in-memory
   plugin state.

### Non-interactive form

For scripts and one-liners (e.g., `claude` invocations from a
deploy hook), the same install-side action runs as:

```bash
claude plugin update standard-tooling@standard-tooling-marketplace
```

After running it, any **new** Claude Code session you start picks
up the new version automatically. Existing sessions still need
`/reload-plugins`.

### Verify the update

```bash
ls -1 ~/.claude/plugins/cache/standard-tooling-marketplace/standard-tooling/
```

You should see one directory per cached version. The newest
version should match the latest tag on
[GitHub Releases](https://github.com/wphillipmoore/standard-tooling-plugin/releases).

### References

Sourced from the official Claude Code documentation:

- [Plugins reference — CLI commands](https://code.claude.com/docs/en/plugins-reference.md)
- [Discover plugins — Apply changes without restarting](https://code.claude.com/docs/en/discover-plugins.md)

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
