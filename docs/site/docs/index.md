# Standard Tooling Plugin

Claude Code plugin for the standard-tooling ecosystem. Delivers shared hooks,
skills, agents, and commands to all managed repositories.

## Overview

This plugin is the behavioral counterpart to the
[standard-tooling](https://github.com/wphillipmoore/standard-tooling) Python
package. While standard-tooling provides runtime CLI tools (`st-commit`,
`st-submit-pr`, etc.) via PATH, this plugin provides Claude Code configuration
that enforces workflow compliance mechanically.

## What's Included

| Component | Purpose |
|-----------|---------|
| [Hooks](hooks/index.md) | PreToolUse/PostToolUse/Stop guardrails that enforce workflow rules |
| [Skills](skills/index.md) | Shared workflow skills (commit, PR, release, publish, etc.) |
| [Agents](agents/index.md) | Bootstrap subagent for session-start context loading |

## Two-Repo Model

| Repo | Delivers | Distribution |
|------|----------|-------------|
| `standard-tooling` | Python CLIs (`st-*`), bash validators, git hooks | PATH |
| `standard-tooling-plugin` | Hooks, skills, agents, commands | Claude Code plugin |

These are complementary: the plugin tells Claude how to behave; PATH makes the
tools available to run.

## Installation

### From marketplace

Configure in your project's `.claude/settings.json`:

```json
{
  "plugins": ["standard-tooling"]
}
```

### Local development

```bash
claude --plugin-dir /path/to/standard-tooling-plugin
```

## Plugin Namespace

All skills are namespaced under `standard-tooling`:

```text
/standard-tooling:<skill-name>
```
