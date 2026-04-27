#!/usr/bin/env bash
# remind-finalize.sh — PostToolUse hook for Bash.
# After st-submit-pr runs, reminds Claude to finalize after the PR merges.
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# either docs/repository-standards.md or st-config.yaml. See
# hooks/scripts/lib/managed-repo-check.sh.
set -euo pipefail

input=$(cat)
cwd=$(echo "$input" | jq -r '.tool_input.cwd // .cwd // "."')

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
if ! is_managed_repo "$cwd"; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command')

# Only trigger after st-submit-pr
if ! echo "$command" | grep -qE '(^|[;&|]\s*)st-submit-pr(\s|$)'; then
  exit 0
fi

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: "REMINDER: A PR was just submitted. After the PR merges, you MUST run st-finalize-repo to complete the cycle (switch to develop, pull the merge, prune stale branches). Do not consider the work done until st-finalize-repo succeeds. If the PR has not merged yet, wait for it before finalizing."
  }
}'
