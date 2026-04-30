#!/usr/bin/env bash
# block-agent-merge.sh — PreToolUse hook for Bash.
# Blocks gh pr merge and gh pr review --approve on non-release PRs.
# Delegates branch verification to st-check-pr-merge.
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

is_merge_command=false

if echo "$command" \
     | grep -qE '(^|[;&|]\s*)gh\s+pr\s+(merge(\s|$)|review\s+.*--approve)'; then
  is_merge_command=true
fi

if echo "$command" | grep -qE 'gh\s+api\s+.*/pulls/[0-9]+/merge(\s|$)' \
  && echo "$command" | grep -qiE '(-X\s+PUT|--method\s+PUT|-XPUT)'; then
  is_merge_command=true
fi

if echo "$command" | grep -qE 'gh\s+api\s+.*/pulls/[0-9]+/reviews(\s|$)' \
  && echo "$command" | grep -qiE '(-X\s+POST|--method\s+POST|-XPOST)'; then
  is_merge_command=true
fi

if [ "$is_merge_command" = false ]; then
  exit 0
fi

rc=0
stderr=$(st-check-pr-merge "$command" 2>&1 1>/dev/null) || rc=$?
if [ "$rc" -eq 0 ]; then
  exit 0
fi

if [ "$rc" -eq 1 ]; then
  reason="${stderr:-Denied by st-check-pr-merge (no details provided).}"
elif [ "$rc" -eq 2 ]; then
  reason="st-check-pr-merge could not determine whether this merge is allowed (exit 2). Error: ${stderr:-no details}. Resolve the tool failure before retrying."
else
  reason="st-check-pr-merge exited with unexpected code $rc. Error: ${stderr:-no details}. Cannot determine whether this merge is allowed."
fi

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
