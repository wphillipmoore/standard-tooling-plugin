# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.4.7] - 2026-04-28

### Documentation

- remove include directives and downgrade standards-and-conventions refs

### Features

- publish: verify bump PR issue linkage before merge
- forbid auto-close linkage, require Ref and explicit issue closure

## [1.4.6] - 2026-04-28

### Bug fixes

- shorten mkdocs.yml site_description and drop stale commands reference

### Documentation

- align docs tree with post-audit codebase state

## [1.4.5] - 2026-04-28

### Documentation

- audit: rationalize skill catalog as a coherent dev+deploy toolkit
- publish + pr-workflow: docs.yml verification, Phase 6 closure, Phase 7 hand-off
- summarize: keep three-mode unified skill; SOC mode is canonical for the fleet
- complete audit steps 6-7, align host/container routing (#96)

### Features

- pr-workflow: verify post-merge async workflows from repository profile
- enforce host-vs-container tool routing per #96
- publish: verify cross-repo image rebuild for standard-tooling releases

### Refactoring

- eliminate branch-workflow skill; extract substance to starting-work-on-an-issue.md
- rewrite pr-workflow for worktree convention + humans-review posture
- project-issue: strip GitHub Projects integration, remove add-to-project workflow

## [1.4.4] - 2026-04-27

### Documentation

- document plugin update sequence in README and CLAUDE.md

### Features

- gate enforcement hooks on managed-repo detection

## [1.4.3] - 2026-04-27

### Bug fixes

- resolve session cwd and main repo root for worktree commits

### Documentation

- split tool routing: release/git tools on host, validators in container

### Features

- remove per-edit validate-* hooks; rely on st-validate-local at PR time

## [1.4.1] - 2026-04-24

### Bug fixes

- pass version-replacement to version-bump-pr composite; bump 1.4.1

### Documentation

- reorder publish skill phases so bump PR merge runs in parallel with slow publish

### Release

- 1.3.0 (#62)
- 1.3.1 (#67)

## [1.4.0] - 2026-04-24

### Features

- rewrite publish skill for poll-and-merge; bump composite pins to v1.2; plugin 1.4.0 (#70)

## [1.3.1] - 2026-04-23

### Bug fixes

- pin consumers to main ref in marketplace.json (#65)

## [1.3.0] - 2026-04-23

### Bug fixes

- use markdown-standards in validate-markdown.sh for CI parity (#14)
- fix markdownlint and structural check failures (#16)
- skip Cargo.toml and Cargo.lock in generic TOML validation (#18)
- add PreToolUse hook to block bash associative arrays (#29)
- fix marketplace.json source schema and resolve markdownlint errors (#31)
- update skills, hooks, and bootstrap for container-first execution via st-docker-run (#37)

### CI

- use dev-docs container for docs CI (#27)

### Documentation

- cross-ref git-workflow guide and refresh hook entries (block-memory-writes removed, block-protected-branch-work now worktree-aware) (#48)

### Features

- add 5 core PreToolUse guardrail hooks (#1)
- add bootstrap session-start agent (#2)
- migrate 8 skills from standards-and-conventions (#3)
- add 3 post-action hooks for finalization, deprecation, and stop guard (#4)
- add self-hosted marketplace for plugin distribution (#5)
- add MkDocs site scaffold, changelog infrastructure, and CI workflows (#7)
- add PostToolUse file validation on Write|Edit (#12)
- add CI workflows and rulesets (#19)
- adopt git worktree convention for parallel AI agent development (#43)
- make block-protected-branch-work.sh worktree-aware (opt-in via .gitignore signal) (#45)
