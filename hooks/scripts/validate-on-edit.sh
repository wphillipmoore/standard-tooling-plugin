#!/usr/bin/env bash
# validate-on-edit.sh — PostToolUse hook for Write|Edit.
# Dispatches per-language validation on the edited file. Auto-fixable issues
# are fixed in place silently; unfixable issues block the agent (exit 2).
#
# Validation tools run inside the dev container via st-docker-run. Missing
# st-docker-run is a fatal error (exit 2) with a clear install pointer —
# validation cannot run without the dispatcher, so failing silently would
# hide the plugin's purpose from the agent.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.file // ""')

# Skip if no file path or file doesn't exist (deleted / virtual)
if [[ -z "$file_path" || ! -f "$file_path" ]]; then
  exit 0
fi

# Validation tools live in the dev container. Missing st-docker-run is
# fatal — the plugin's validation layer cannot function without the
# dispatcher, and a silent skip would hide that from the agent.
if ! command -v st-docker-run >/dev/null 2>&1; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: "ERROR: st-docker-run not found on PATH. File validation cannot run.\n\nst-docker-run is the host-side dispatcher that runs commands inside the dev container image. It is delivered by the standard-tooling Python package.\n\nInstall: see the Getting Started guide for host venv bootstrap and PATH setup:\n  https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/site/docs/getting-started.md"
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
