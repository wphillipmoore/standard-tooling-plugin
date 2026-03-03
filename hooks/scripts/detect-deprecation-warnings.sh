#!/usr/bin/env bash
# detect-deprecation-warnings.sh — PostToolUse hook for Bash.
# After test commands run, checks output for deprecation warnings and
# reminds Claude to triage them using the deprecation-triage skill.
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command')
response=$(echo "$input" | jq -r '.tool_response // ""')

# Only trigger after test commands
is_test_command=false
if echo "$command" | grep -qE '(^|[;&|]\s*)(pytest|cargo\s+test|go\s+test|bundle\s+exec\s+rspec|ruby\s+-e|rake\s+test|mvn\s+test|uv\s+run\s+pytest)(\s|$)'; then
  is_test_command=true
fi

if [ "$is_test_command" = false ]; then
  exit 0
fi

# Check for deprecation warning patterns in the response
has_deprecation=false
if echo "$response" | grep -qiE '(DeprecationWarning|PendingDeprecationWarning|FutureWarning|deprecated|DEPRECATION)'; then
  has_deprecation=true
fi

if [ "$has_deprecation" = false ]; then
  exit 0
fi

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: "WARNING: Deprecation warnings detected in test output. After completing your current task, triage these warnings using the deprecation-triage skill (/standard-tooling:deprecation-triage). Do not suppress warnings without tracking them in an issue."
  }
}'
