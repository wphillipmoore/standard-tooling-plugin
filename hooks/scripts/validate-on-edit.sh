#!/usr/bin/env bash
# validate-on-edit.sh — PostToolUse hook for Write|Edit.
# Dispatches per-language validation on the edited file. Auto-fixable issues
# are fixed in place silently; unfixable issues block the agent (exit 2).
#
# Validation tools run inside the dev container via st-docker-run. If
# st-docker-run is not on PATH, validation is skipped silently.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.file // ""')

# Skip if no file path or file doesn't exist (deleted / virtual)
if [[ -z "$file_path" || ! -f "$file_path" ]]; then
  exit 0
fi

# Validation tools live in the dev container — warn if st-docker-run is
# not available.
if ! command -v st-docker-run &>/dev/null; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: "WARNING: st-docker-run not found on PATH. File validation skipped. Ensure standard-tooling host venv is set up and st-docker-run is on PATH."
    }
  }'
  exit 2
fi

# Convert absolute host path to repo-relative path for the container
# (st-docker-run mounts the repo root at /workspace).
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [[ -n "$repo_root" ]]; then
  rel_path="${file_path#"$repo_root"/}"
else
  rel_path="$file_path"
fi

# Route by extension or path pattern to per-language validator
validator=""
case "$file_path" in
  *.py)
    validator="$SCRIPT_DIR/validate-python.sh"
    ;;
  *.sh)
    validator="$SCRIPT_DIR/validate-shell.sh"
    ;;
  *.md)
    validator="$SCRIPT_DIR/validate-markdown.sh"
    ;;
  *.yml | *.yaml)
    validator="$SCRIPT_DIR/validate-yaml.sh"
    ;;
  *)
    # Check for extensionless shell scripts (scripts/bin/*, scripts/lib/*)
    if echo "$file_path" | grep -qE '(^|/)scripts/(bin|lib)/'; then
      validator="$SCRIPT_DIR/validate-shell.sh"
    elif [[ -f "$file_path" ]] && head -1 "$file_path" | grep -qE '^#!.*\b(bash|sh)\b'; then
      validator="$SCRIPT_DIR/validate-shell.sh"
    else
      exit 0
    fi
    ;;
esac

# Run the validator with the repo-relative path
errors=""
if ! errors=$("$validator" "$rel_path" 2>&1); then
  exit_code=$?
  jq -n --arg ctx "FILE VALIDATION FAILED for ${file_path}:
${errors}
Fix the issues above before continuing." '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $ctx
    }
  }'
  exit "$exit_code"
fi
