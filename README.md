# standard-tooling-plugin

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
| **Hooks** | PreToolUse guardrails (block raw git commit, enforce branch rules, etc.) |
| **Skills** | Shared workflow skills (commit, PR, release, publish, etc.) |
| **Agents** | Bootstrap subagent for session-start context loading |
| **Commands** | User-invokable slash commands |

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
