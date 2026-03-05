#!/usr/bin/env bash
# validate-yaml.sh — Validate a YAML file.
# Runs yamllint, and actionlint for GitHub workflow files.
set -euo pipefail

file="$1"
errors=""

# Required
if ! command -v yamllint &>/dev/null; then
  echo "FATAL: yamllint not found on PATH" >&2
  exit 2
fi

# Check: yamllint
if ! output=$(yamllint "$file" 2>&1); then
  errors+="$output"$'\n'
fi

# Check: actionlint for GitHub workflow files
if echo "$file" | grep -qE '\.github/workflows/.*\.ya?ml$'; then
  if ! command -v actionlint &>/dev/null; then
    echo "FATAL: actionlint not found on PATH" >&2
    exit 2
  fi
  if ! output=$(actionlint "$file" 2>&1); then
    errors+="$output"$'\n'
  fi
fi

if [[ -n "$errors" ]]; then
  echo "$errors" >&2
  exit 2
fi
