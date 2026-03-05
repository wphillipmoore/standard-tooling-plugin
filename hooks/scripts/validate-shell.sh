#!/usr/bin/env bash
# validate-shell.sh — Validate a shell script.
# Auto-fixes with shfmt, then checks with shellcheck.
set -euo pipefail

file="$1"
errors=""

# Both tools are required
if ! command -v shfmt &>/dev/null; then
  echo "FATAL: shfmt not found on PATH" >&2
  exit 2
fi
if ! command -v shellcheck &>/dev/null; then
  echo "FATAL: shellcheck not found on PATH" >&2
  exit 2
fi

# Auto-fix: shfmt
shfmt -w "$file" 2>/dev/null || true

# Check: shellcheck
if ! output=$(shellcheck "$file" 2>&1); then
  errors+="$output"$'\n'
fi

if [[ -n "$errors" ]]; then
  echo "$errors" >&2
  exit 2
fi
