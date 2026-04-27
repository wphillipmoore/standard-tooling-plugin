#!/usr/bin/env bash
# block-associative-arrays.sh — PreToolUse hook for Bash.
# Blocks bash associative arrays (declare -A) which require bash 4.0+.
# macOS ships bash 3.2 (GPLv2) and will not upgrade to GPLv3 versions.
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# either docs/repository-standards.md or st-config.yaml. See
# hooks/scripts/lib/managed-repo-check.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"

input=$(cat)
cwd=$(echo "$input" | jq -r '.tool_input.cwd // .cwd // "."')

if ! is_managed_repo "$cwd"; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command')

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
