#!/usr/bin/env bash
# validate-markdown.sh — Validate a Markdown file.
# Runs inside the dev container via st-docker-run.
# Auto-fixes with markdownlint --fix first, then runs the full check.
set -euo pipefail

file="$1"

# Auto-fix: markdownlint --fix
st-docker-run -- markdownlint --fix "$file" 2>/dev/null || true

# Check: markdown-standards (same checks as CI — markdownlint + structural)
if ! errors=$(st-docker-run -- st-markdown-standards "$file" 2>&1); then
  echo "$errors" >&2
  exit 2
fi
