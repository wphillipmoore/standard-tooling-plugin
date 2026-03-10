#!/usr/bin/env bash
# validate-shell.sh — Validate a shell script.
# Runs inside the dev container via st-docker-run.
# Auto-fixes with shfmt, then checks with shellcheck.
set -euo pipefail

file="$1"
errors=""

# Auto-fix: shfmt
st-docker-run -- shfmt -w "$file" 2>/dev/null || true

# Check: shellcheck
if ! output=$(st-docker-run -- shellcheck "$file" 2>&1); then
  errors+="$output"$'\n'
fi

if [[ -n "$errors" ]]; then
  echo "$errors" >&2
  exit 2
fi
