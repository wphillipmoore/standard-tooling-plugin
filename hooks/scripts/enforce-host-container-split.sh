#!/usr/bin/env bash
# enforce-host-container-split.sh — PreToolUse hook for Bash.
# Enforces the host-vs-container tool routing rule from #96.
#
# - DENY: wrapping a host-only tool in st-docker-run --
# - WARN: bare-invoking a container-only tool without st-docker-run --
#
# Gated on managed-repo detection (#87): no-op in repos that lack
# either docs/repository-standards.md or st-config.yaml.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/host-container-tools.sh"

input=$(cat)
cwd=$(echo "$input" | jq -r '.tool_input.cwd // .cwd // "."')

if ! is_managed_repo "$cwd"; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command')

# Check for host tools wrapped in st-docker-run -- (DENY)
for tool in "${HOST_TOOLS[@]}"; do
  if echo "$command" | grep -qE "(^|[;&|]\s*)st-docker-run\s+--\s+$tool(\s|$)"; then
    jq -n --arg tool "$tool" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("\($tool) is a host command — invoke directly without st-docker-run wrapping. See issue #96: https://github.com/wphillipmoore/standard-tooling-plugin/issues/96")
      }
    }'
    exit 0
  fi
done

# Check for container tools invoked directly (WARN)
for tool in "${CONTAINER_TOOLS[@]}"; do
  if echo "$command" | grep -qE "(^|[;&|]\s*)(st-docker-run\s+--\s+)?$tool(\s|$)"; then
    jq -n --arg tool "$tool" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: ("WARNING: \($tool) should not be invoked directly. Use st-validate-local for validation — it delegates to scripts/dev/*.sh which handle tool routing internally. See issue #168: https://github.com/wphillipmoore/standard-tooling-plugin/issues/168")
      }
    }'
    exit 0
  fi
done

exit 0
