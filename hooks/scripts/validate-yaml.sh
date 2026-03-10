#!/usr/bin/env bash
# validate-yaml.sh — Validate a YAML file.
# Runs inside the dev container via st-docker-run.
# Runs yamllint, and actionlint for GitHub workflow files.
set -euo pipefail

file="$1"
errors=""

# Check: yamllint
if ! output=$(st-docker-run -- yamllint "$file" 2>&1); then
  errors+="$output"$'\n'
fi

# Check: actionlint for GitHub workflow files
if echo "$file" | grep -qE '\.github/workflows/.*\.ya?ml$'; then
  if ! output=$(st-docker-run -- actionlint "$file" 2>&1); then
    errors+="$output"$'\n'
  fi
fi

if [[ -n "$errors" ]]; then
  echo "$errors" >&2
  exit 2
fi
