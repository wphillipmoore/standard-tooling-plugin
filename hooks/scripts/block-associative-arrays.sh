#!/usr/bin/env bash
# block-associative-arrays.sh — PreToolUse hook for Bash.
# Blocks bash associative arrays (declare -A) which require bash 4.0+.
# macOS ships bash 3.2 (GPLv2) and will not upgrade to GPLv3 versions.
set -euo pipefail

command=$(jq -r '.tool_input.command' < /dev/stdin)

# Match declare with -A flag in any position (e.g., -A, -Ag, -rA, -gA).
if echo "$command" | grep -qE 'declare\s+-[a-zA-Z]*A'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Bash associative arrays (declare -A) are blocked. macOS ships bash 3.2 which does not support them (added in bash 4.0). Use parallel indexed arrays, case statements, or move the logic to Python instead."
    }
  }'
else
  exit 0
fi
