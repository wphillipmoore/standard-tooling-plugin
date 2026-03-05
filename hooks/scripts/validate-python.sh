#!/usr/bin/env bash
# validate-python.sh — Validate a Python file.
# Auto-fixes with ruff, then checks for remaining issues with ruff, mypy, and ty.
set -euo pipefail

file="$1"
errors=""

# All tools are required — fail loudly if missing
for tool in ruff mypy ty; do
  if ! command -v "$tool" &>/dev/null; then
    echo "FATAL: $tool not found on PATH" >&2
    exit 2
  fi
done

# Auto-fix: ruff check --fix + ruff format
ruff check --fix --quiet "$file" 2>/dev/null || true
ruff format --quiet "$file" 2>/dev/null || true

# Check: ruff lint (remaining unfixable issues)
if ! output=$(ruff check "$file" 2>&1); then
  errors+="$output"$'\n'
fi

# Check: mypy
if ! output=$(mypy "$file" 2>&1); then
  errors+="$output"$'\n'
fi

# Check: ty
if ! output=$(ty check "$file" 2>&1); then
  errors+="$output"$'\n'
fi

if [[ -n "$errors" ]]; then
  echo "$errors" >&2
  exit 2
fi
