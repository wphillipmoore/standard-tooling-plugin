#!/usr/bin/env bash
# stop-guard-finalization.sh — Stop hook.
# Prevents Claude from stopping if a PR was submitted but st-finalize-repo
# was not run in this session. Checks the transcript for evidence.
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# either docs/repository-standards.md or st-config.yaml. See
# hooks/scripts/lib/managed-repo-check.sh.
set -euo pipefail

input=$(cat)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"

if ! is_managed_repo "$PWD"; then
  exit 0
fi

stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

# Prevent infinite loops — if a stop hook already continued the session,
# do not block again.
if [ "$stop_hook_active" = "true" ]; then
  exit 0
fi

# If no transcript available, allow stop
if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
  exit 0
fi

# Check if st-submit-pr was called in this session
submitted_pr=false
if grep -q 'st-submit-pr' "$transcript_path" 2>/dev/null; then
  submitted_pr=true
fi

if [ "$submitted_pr" = false ]; then
  exit 0
fi

# Check if st-finalize-repo was called after the PR submission
finalized=false
if grep -q 'st-finalize-repo' "$transcript_path" 2>/dev/null; then
  finalized=true
fi

if [ "$finalized" = true ]; then
  exit 0
fi

# PR was submitted but not finalized — block the stop
jq -n '{
  decision: "block",
  reason: "A PR was submitted in this session but st-finalize-repo has not been run. Finalization is mandatory: run st-finalize-repo to switch to develop, pull the merge, and prune stale branches. If the PR has not merged yet, check its status with gh pr view."
}'
