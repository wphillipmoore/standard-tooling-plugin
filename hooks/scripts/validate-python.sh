#!/usr/bin/env bash
# validate-python.sh — Validate a Python file.
# Runs inside the dev container via st-docker-run.
# Auto-fixes with ruff, then checks for remaining issues with ruff, mypy,
# and ty.
set -euo pipefail

file="$1"
errors=""

# Auto-fix: ruff check --fix + ruff format
st-docker-run -- ruff check --fix --quiet "$file" 2>/dev/null || true
st-docker-run -- ruff format --quiet "$file" 2>/dev/null || true

# Check: ruff lint (remaining unfixable issues)
if ! output=$(st-docker-run -- ruff check "$file" 2>&1); then
  errors+="$output"$'\n'
fi

# Check: mypy
if ! output=$(st-docker-run -- mypy "$file" 2>&1); then
  errors+="$output"$'\n'
fi

# Check: ty
if ! output=$(st-docker-run -- ty check "$file" 2>&1); then
  errors+="$output"$'\n'
fi

if [[ -n "$errors" ]]; then
  echo "$errors" >&2
  exit 2
fi
