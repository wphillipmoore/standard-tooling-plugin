#!/usr/bin/env bash
# validate-toml.sh — Validate a TOML file.
# Auto-fixes with taplo fmt, then checks with taplo check.
set -euo pipefail

file="$1"
errors=""

# Required
if ! command -v taplo &>/dev/null; then
  echo "FATAL: taplo not found on PATH" >&2
  exit 2
fi

# Auto-fix: taplo fmt
taplo fmt "$file" 2>/dev/null || true

# Check: taplo syntax check
if ! output=$(taplo check "$file" 2>&1); then
  errors+="$output"$'\n'
fi

if [[ -n "$errors" ]]; then
  echo "$errors" >&2
  exit 2
fi
