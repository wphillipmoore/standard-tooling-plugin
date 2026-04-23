#!/usr/bin/env bash
# block-raw-git-commit.sh — PreToolUse hook for Bash.
# Blocks raw 'git commit' commands. Use st-commit instead.
set -euo pipefail

command=$(jq -r '.tool_input.command' < /dev/stdin)

# Match git commit but not st-commit or git commit-related subcommands
# that aren't actual commits (e.g., git commit-tree, git commit-graph).
if echo "$command" | grep -qE '(^|[;&|]\s*)git\s+commit(\s|$)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Raw git commit is blocked. Use st-commit instead. See docs/repository-standards.md for usage."
    }
  }'
else
  exit 0
fi
