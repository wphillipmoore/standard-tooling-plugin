#!/usr/bin/env bash
# block-raw-gh-pr-create.sh — PreToolUse hook for Bash.
# Blocks raw 'gh pr create' commands. Use st-submit-pr instead.
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
