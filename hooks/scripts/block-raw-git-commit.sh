#!/usr/bin/env bash
# block-raw-git-commit.sh — PreToolUse hook for Bash.
# Blocks raw 'git commit' commands. Use st-commit instead.
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# standard-tooling.toml. See hooks/scripts/lib/managed-repo-check.sh.
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

# Match git commit but not st-commit or git commit-related subcommands
# that aren't actual commits (e.g., git commit-tree, git commit-graph).
if echo "$command" | grep -qE '(^|[;&|]\s*)git\s+commit(\s|$)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Raw git commit is blocked. Use st-commit instead. See standard-tooling.toml for usage."
    }
  }'
else
  exit 0
fi
