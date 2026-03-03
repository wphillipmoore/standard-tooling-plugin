#!/usr/bin/env bash
# block-raw-gh-pr-create.sh — PreToolUse hook for Bash.
# Blocks raw 'gh pr create' commands. Use st-submit-pr instead.
set -euo pipefail

command=$(jq -r '.tool_input.command' < /dev/stdin)

if echo "$command" | grep -qE '(^|[;&|]\s*)gh\s+pr\s+create(\s|$)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Raw gh pr create is blocked. Use st-submit-pr instead. See docs/repository-standards.md for usage."
    }
  }'
else
  exit 0
fi
