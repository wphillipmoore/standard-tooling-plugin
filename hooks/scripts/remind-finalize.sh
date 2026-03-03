#!/usr/bin/env bash
# remind-finalize.sh — PostToolUse hook for Bash.
# After st-submit-pr runs, reminds Claude to finalize after the PR merges.
set -euo pipefail

input=$(cat)
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
