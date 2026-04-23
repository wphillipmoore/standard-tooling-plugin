#!/usr/bin/env bash
# validate-shell.sh — Validate a shell script.
# Runs inside the dev container via st-docker-run.
# Auto-fixes with shfmt, then checks with shellcheck.
#
# Missing st-docker-run is a fatal error (exit 2). The plugin's
# validation layer depends on the container dispatcher; without it,
# nothing here can run, and silent skips would hide that from the agent.
set -euo pipefail

if ! command -v st-docker-run >/dev/null 2>&1; then
  {
    echo "ERROR: st-docker-run not found on PATH. Cannot validate this file."
    echo ""
    echo "st-docker-run is the host-side dispatcher that runs commands"
    echo "inside the dev container image. It is delivered by the"
    echo "standard-tooling Python package."
    echo ""
    echo "Install: see the Getting Started guide for host venv bootstrap"
    echo "and PATH setup:"
    echo "  https://github.com/wphillipmoore/standard-tooling/blob/develop/docs/site/docs/getting-started.md"
  } >&2
  exit 2
fi

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
