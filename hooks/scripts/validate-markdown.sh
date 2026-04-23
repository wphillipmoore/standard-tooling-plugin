#!/usr/bin/env bash
# validate-markdown.sh — Validate a Markdown file.
# Runs inside the dev container via st-docker-run.
# Auto-fixes with markdownlint --fix first, then runs the full check.
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

# Auto-fix: markdownlint --fix
st-docker-run -- markdownlint --fix "$file" 2>/dev/null || true

# Check: markdown-standards (same checks as CI — markdownlint + structural)
if ! errors=$(st-docker-run -- st-markdown-standards "$file" 2>&1); then
  echo "$errors" >&2
  exit 2
fi
