#!/usr/bin/env bash
# validate-markdown.sh — Validate a Markdown file.
# Auto-fixes with markdownlint --fix, then checks for remaining issues.
set -euo pipefail

file="$1"
errors=""

# Required
if ! command -v markdownlint &>/dev/null; then
  echo "FATAL: markdownlint not found on PATH" >&2
  exit 2
fi

# Auto-fix: markdownlint --fix
markdownlint --fix "$file" 2>/dev/null || true

# Check: markdownlint (remaining unfixable issues)
if ! output=$(markdownlint "$file" 2>&1); then
  errors+="$output"$'\n'
fi

if [[ -n "$errors" ]]; then
  echo "$errors" >&2
  exit 2
fi
