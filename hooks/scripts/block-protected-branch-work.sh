#!/usr/bin/env bash
# block-protected-branch-work.sh — PreToolUse hook for Bash.
#
# Blocks commits that shouldn't happen at the project root:
#
# 1. If the repo has adopted the parallel-AI-agent worktree convention
#    (signal: `.worktrees/` line in .gitignore), enforce that commits
#    originate from a `.worktrees/<name>/` subdirectory. The main tree
#    is read-only under that convention.
#
# 2. If the repo has NOT adopted the convention, fall back to the
#    long-standing behavior: block commits on `main` or `develop`.
#
# Does NOT block branch operations (checkout, merge, push, pull, etc.).
#
# See wphillipmoore/standard-tooling/docs/specs/worktree-convention.md
# for the adopted-convention rules.
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command')

# Only check commands that could create commits on the current branch.
# Allow git operations that don't create commits (checkout, push, pull, etc.).
if ! echo "$command" | grep -qE '(^|[;&|]\s*)(git\s+commit|st-commit)(\s|$)'; then
  exit 0
fi

cwd=$(echo "$input" | jq -r '.tool_input.cwd // "."')

# Determine the effective directory where the commit will actually run.
# Handles two common patterns that redirect the commit to a different dir:
#   (a) "cd <dir> && ... git commit ..."   — walk into the dir first
#   (b) "git -C <dir> commit ..."           — inline dir override
# Default: the tool_input cwd.
effective_dir="$cwd"
if prefix_cd=$(echo "$command" | grep -oE '^cd[[:space:]]+[^[:space:];&|]+' | head -1); then
  target=$(printf '%s\n' "$prefix_cd" | sed -E 's/^cd[[:space:]]+//')
  case "$target" in
    /*) effective_dir="$target" ;;
    *)  effective_dir="$cwd/$target" ;;
  esac
elif gitc=$(echo "$command" | grep -oE 'git[[:space:]]+-C[[:space:]]+[^[:space:]]+[[:space:]]+commit' | head -1); then
  target=$(printf '%s\n' "$gitc" | sed -E 's/^git[[:space:]]+-C[[:space:]]+//; s/[[:space:]]+commit$//')
  case "$target" in
    /*) effective_dir="$target" ;;
    *)  effective_dir="$cwd/$target" ;;
  esac
fi

# Resolve the effective repository root. If the dir isn't a git repo at all,
# don't block — something else will fail or this was a non-repo commit.
toplevel=$(git -C "$effective_dir" rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$toplevel" ]; then
  exit 0
fi

# Has this repo adopted the worktree convention? Signal: a line reading
# exactly `.worktrees/` in the repo-root .gitignore.
if [ -f "$toplevel/.gitignore" ] && grep -qxF '.worktrees/' "$toplevel/.gitignore" 2>/dev/null; then
  # Enforce: commit must originate from inside $toplevel/.worktrees/*.
  case "$effective_dir" in
    "$toplevel"/.worktrees/*)
      exit 0
      ;;
    *)
      jq -n --arg dir "$effective_dir" '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: ("Commits must originate from inside .worktrees/<name>/ per the worktree convention. You appear to be committing from \($dir). Create a worktree for your work:\n  git worktree add .worktrees/issue-<N>-<slug> -b feature/<N>-<slug> origin/develop\n\nSee docs/specs/worktree-convention.md in standard-tooling for the full convention.")
        }
      }'
      exit 0
      ;;
  esac
fi

# Repo has not adopted the convention — fall back to the original protected-branch check.
branch=$(git -C "$effective_dir" branch --show-current 2>/dev/null || echo "")
if [ "$branch" = "main" ] || [ "$branch" = "develop" ]; then
  jq -n --arg branch "$branch" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("Commits on protected branch \"\($branch)\" are blocked. Create a feature branch first: git checkout -b feature/<name>")
    }
  }'
else
  exit 0
fi
