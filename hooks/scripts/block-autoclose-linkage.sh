#!/usr/bin/env bash
# block-autoclose-linkage.sh — PreToolUse hook for Bash.
# Blocks st-submit-pr invocations that use auto-close linkage keywords
# (Fixes, Closes, Resolves). Use --linkage Ref instead.
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# either docs/repository-standards.md or st-config.yaml.
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

if echo "$command" | grep -qE 'st-submit-pr\b'; then
  if echo "$command" | grep -qiE -- '--linkage\s+(Fixes|Closes|Resolves)\b'; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "Auto-close linkage keywords (Fixes, Closes, Resolves) are forbidden. Use --linkage Ref instead. Issues are closed explicitly after st-finalize-repo confirms the work cycle is complete. See issue #126."
      }
    }'
    exit 0
  fi
fi

exit 0
