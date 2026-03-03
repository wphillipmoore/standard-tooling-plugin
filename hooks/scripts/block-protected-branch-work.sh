#!/usr/bin/env bash
# block-protected-branch-work.sh — PreToolUse hook for Bash.
# Blocks commits on protected branches (main, develop).
# Does NOT block branch operations (checkout, merge, push, pull, etc.).
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command')

# Only check commands that could create commits on the current branch.
# Allow git operations that don't create commits (checkout, push, pull, etc.).
if ! echo "$command" | grep -qE '(^|[;&|]\s*)(git\s+commit|st-commit)(\s|$)'; then
  exit 0
fi

# Check the current branch
cwd=$(echo "$input" | jq -r '.cwd // "."')
branch=$(git -C "$cwd" branch --show-current 2>/dev/null || echo "")

if [ "$branch" = "main" ] || [ "$branch" = "develop" ]; then
  jq -n --arg branch "$branch" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("Commits on protected branch \"\($branch)\" are blocked. Create a feature branch first: git checkout -b feature/<name>")
    }
  }'
else
  exit 0
fi
