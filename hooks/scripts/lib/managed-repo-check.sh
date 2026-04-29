#!/usr/bin/env bash
# managed-repo-check.sh — shared helper for plugin enforcement hooks.
#
# A "managed" repo is one configured to use standard-tooling. The signal
# is the presence of either of two marker files at the repo root:
#
#   docs/repository-standards.md   — the existing per-repo config
#   st-config.toml                 — the single-file config
#   st-config.yaml                 — legacy variant (both formats
#                                    accepted during migration)
#
# When neither marker is present, the plugin's enforcement hooks
# short-circuit to a no-op so the plugin does not interfere with
# ad-hoc git work in repositories that have not opted in.
#
# This file is meant to be `source`d, not executed directly.
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/managed-repo-check.sh"
#   if ! is_managed_repo "$cwd"; then
#     exit 0
#   fi

# is_managed_repo <starting-dir>
#
# Walks up from <starting-dir> looking for either marker file. Returns
# 0 (true) if a marker is found, 1 (false) otherwise. Termination
# conditions:
#   1. A marker file is found    → return 0 (managed)
#   2. A `.git` boundary is found (file or directory — both are valid
#      since a worktree's `.git` is a file pointing at the main repo's
#      git dir). The marker check has already failed at this level,
#      so → return 1 (not managed).
#   3. The walk reaches `/` or an empty path → return 1 (not managed).
#
# Implementation note: pure shell. No subprocess spawns (no `git`,
# no `dirname`, no `realpath`). Each iteration is three `[ -f ]`
# and one `[ -e ]` — sub-millisecond per call.
is_managed_repo() {
	local dir="${1:-$PWD}"

	# Resolve relative paths against the hook subprocess's PWD.
	case "$dir" in
	/*) ;;
	*) dir="$PWD/$dir" ;;
	esac

	while [ "$dir" != "/" ] && [ -n "$dir" ]; do
		if [ -f "$dir/docs/repository-standards.md" ] || [ -f "$dir/st-config.toml" ] || [ -f "$dir/st-config.yaml" ]; then
			return 0
		fi
		if [ -e "$dir/.git" ]; then
			return 1
		fi
		dir="${dir%/*}"
	done

	return 1
}
