#!/usr/bin/env bash
# validate-markdown.sh — Validate a Markdown file.
# Delegates to markdown-standards for consistent checks with CI.
# Auto-fixes with markdownlint --fix first, then runs the full check.
set -euo pipefail

file="$1"

# Both tools are required
if ! command -v markdownlint &>/dev/null; then
  echo "FATAL: markdownlint not found on PATH" >&2
  exit 2
fi
if ! command -v st-markdown-standards &>/dev/null; then
  echo "FATAL: st-markdown-standards not found on PATH" >&2
  exit 2
fi

# Auto-fix: markdownlint --fix
markdownlint --fix "$file" 2>/dev/null || true

# Check: markdown-standards (same checks as CI — markdownlint + structural)
if ! errors=$(st-markdown-standards "$file" 2>&1); then
  echo "$errors" >&2
  exit 2
fi
