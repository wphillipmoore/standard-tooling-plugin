#!/usr/bin/env bash
# host-container-tools.sh — canonical tool routing lists per #96.
#
# Source of truth for which tools run on the host vs in the container.
# Consumed by enforce-host-container-split.sh; kept here so the same
# lists can power future docs/lint if needed.
#
# This file is meant to be `source`d, not executed directly.

# Host-only: release/git workflow tools, thin gh/git wrappers.
# shellcheck disable=SC2034
HOST_TOOLS=(
  st-prepare-release
  st-commit
  st-submit-pr
  st-finalize-repo
  st-merge-when-green
  st-wait-until-green
  st-validate-local
  st-docker-run
  st-ensure-label
  gh
  git
  git-cliff
)

# Container-only: language toolchain validators.
# shellcheck disable=SC2034
CONTAINER_TOOLS=(
  ruff
  mypy
  ty
  black
  isort
  markdownlint
  st-markdown-standards
  yamllint
  actionlint
  shellcheck
  shfmt
)
