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
- [Development and deployment](#development-and-deployment)

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
two-step sequence:

```text
/plugin marketplace update standard-tooling-marketplace
/reload-plugins
```

What each step does:

1. **`/plugin marketplace update <marketplace>`** — refreshes the
   marketplace index and downloads the new plugin version into the
   local cache at `~/.claude/plugins/cache/<plugin-id>/<version>/`.
   The previous version stays on disk for 7 days as a grace window
   for concurrent sessions, then is removed automatically.
2. **`/reload-plugins`** — applies the new skills / hooks / agents
   to the **current** Claude Code session without restarting.
   Without this, the running session keeps using the old in-memory
   plugin state.

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
mechanically. Every hook below **except `block-heredoc`** is
gated on a managed-repo check: a repo must contain
`standard-tooling.toml` at its root for the hook to fire. In repos
without this marker, the gated hooks
short-circuit to a no-op so the plugin doesn't interfere with
ad-hoc git work in unrelated repositories. See the
[hooks reference](https://github.com/wphillipmoore/standard-tooling-plugin/blob/develop/docs/site/docs/hooks/index.md#managed-repo-gating)
for the rationale.

| Hook | Matcher | Purpose |
|---|---|---|
| `block-raw-git-commit` | PreToolUse/Bash | Redirects raw `git commit` to `st-commit` |
| `block-raw-gh-pr-create` | PreToolUse/Bash | Redirects raw `gh pr create` to `st-submit-pr` |
| `block-protected-branch-work` | PreToolUse/Bash | Blocks commits from outside `.worktrees/*` on repos that adopt the worktree convention; otherwise blocks commits on `develop`/`main` |
| `block-heredoc` | PreToolUse/Bash | Blocks `<<EOF` in CLI args (use `--body-file` or `$(cat <file>)`) |
| `block-associative-arrays` | PreToolUse/Bash | Blocks bash 4+ associative arrays — host scripts must run on macOS bash 3.2 |
| `enforce-host-container-split` | PreToolUse/Bash | Denies wrapping host-only tools in `st-docker-run`; warns on bare container-only tools |
| `block-autoclose-linkage` | PreToolUse/Bash | Blocks `--linkage Fixes/Closes/Resolves` in `st-submit-pr` — use `Ref` instead |
| `remind-finalize` | PostToolUse/Bash | After `st-submit-pr`, reminds to run `st-finalize-repo` |
| `detect-deprecation-warnings` | PostToolUse/Bash | Surfaces deprecation warnings from test output for triage |

Full reference:
<https://github.com/wphillipmoore/standard-tooling-plugin/blob/develop/docs/site/docs/hooks/index.md>.

### Skills

Shared workflow skills, invoked as `/standard-tooling:<name>`.

| Skill | Purpose |
|---|---|
| `pr-workflow` | Guide PR creation, submission, and finalization |
| `publish` | Drive library/tooling/documentation release flow |
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

## Development and deployment

This section covers contributing to the plugin itself — how to set
up a working environment, ship a change, and complete the
post-publish hand-off. Distinct from the [Install](#install) and
[Update](#update) sections, which cover how a *consumer* of the
plugin uses it. The two roles have different obligations.

### Set up a worktree

Sessions on this repo always start at the project root
(`~/dev/github/standard-tooling-plugin/`), never inside a
worktree. Each in-flight issue gets its own worktree under
`.worktrees/issue-<N>-<slug>/` on a `feature/<N>-<slug>` branch.
The full procedure (issue resolution, sub-issue creation,
worktree+branch creation, agent prompt template) lives at
[`docs/development/starting-work-on-an-issue.md`](docs/development/starting-work-on-an-issue.md).

The worktree convention is enforced by the
`block-protected-branch-work` hook: commits originating from
outside `.worktrees/*/` are denied.

### Ship a change

Use the [`pr-workflow` skill](skills/pr-workflow/SKILL.md) to
submit, wait for CI green, and hand off:

```text
/standard-tooling:pr-workflow
```

The agent submits via `st-submit-pr`, waits for CI to go green,
fixes agent-fixable failures, and hands off to you for review and
merge. Auto-merge is disabled fleet-wide; you review and merge
feature/bugfix PRs manually. After you report the merge, the
agent runs `st-finalize-repo` from inside the worktree.

### Cut a release

Use the [`publish` skill](skills/publish/SKILL.md):

```text
/standard-tooling:publish
```

The skill drives Phases 1–7: prepare release, merge release PR
via `st-merge-when-green` (the documented exception to the
"humans review human PRs" policy — release PRs are
agent-authored and agent-merged), merge the post-publish bump
PR, confirm both `publish.yml` and `docs.yml` succeeded on
`main`, optionally do dependency updates, close the tracking
issue with a summary, finalize, and surface the consumer-refresh
sequence.

### Post-publish hand-off (Phase 7)

**A release is not concluded until consumers have refreshed.**
After `publish.yml` and `docs.yml` succeed, every Claude Code
session that has this plugin installed needs to run:

```text
/plugin marketplace update standard-tooling-marketplace
/plugin update standard-tooling@standard-tooling-marketplace
/reload-plugins
```

The agent producing the release surfaces this sequence in its
hand-off message. The user runs it (in this session, or in any
new session that wants the new plugin behavior). Without the
refresh, hooks and skills stay on the previously-cached version
and the release is invisible to running sessions.

This is the user-facing
[Update](#update) sequence, surfaced from the producer side at
the moment of release rather than left to the user to remember.

### Develop against the source tree

When iterating on hooks or skills before release, load the plugin
directly from the source tree to avoid the marketplace
round-trip:

```bash
claude --plugin-dir /path/to/standard-tooling-plugin
```

This bypasses `~/.claude/plugins/cache/` and mounts the working
tree as the plugin source.

### Reporting issues

Open an issue at
<https://github.com/wphillipmoore/standard-tooling-plugin/issues>.
