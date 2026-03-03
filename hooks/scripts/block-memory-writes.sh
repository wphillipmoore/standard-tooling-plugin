#!/usr/bin/env bash
# block-memory-writes.sh — PreToolUse hook for Write|Edit.
# Blocks writes to MEMORY.md. All behavioral rules belong in managed,
# version-controlled documentation (CLAUDE.md, AGENTS.md, skills, or docs/).
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.file // ""')

if echo "$file_path" | grep -qE '(^|/)MEMORY\.md$'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Writing to MEMORY.md is blocked. All behavioral rules belong in version-controlled documentation (CLAUDE.md, AGENTS.md, skills, or docs/). Discuss with the user what to capture and where."
    }
  }'
else
  exit 0
fi
