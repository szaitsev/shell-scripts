# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Shell Scripts Collection — Claude Instructions

## Project purpose
Personal collection of bash utility scripts. Each script lives in its own
subdirectory with its own README and optionally its own CLAUDE.md.

## Repository layout
```
shell-scripts/
├── CLAUDE.md                  ← this file: global rules
├── README.md                  ← global index of all scripts
└── script-name/
    ├── script-name.sh         ← the script
    ├── README.md              ← usage docs for this script
    └── CLAUDE.md             ← (optional) script-specific context
```

- Script-level CLAUDE.md files **extend** these global rules, never override them
- Use `claude /memory` to verify which CLAUDE.md files are active in a session

## Shell conventions
- Shell: bash (`#!/usr/bin/env bash`)
- Always set safety flags at the top: `set -euo pipefail`
- Use `readonly` for constants
- Prefer long flags for clarity (`--output` over `-o`) in internal calls
- Quote all variable expansions: `"${var}"` not `$var`
- Local variables in functions must use `local`

## Error handling
- Always validate required inputs/args before doing any work
- Print errors to stderr: `echo "Error: ..." >&2`
- Exit with meaningful codes (1 = general error, 2 = bad usage)
- Every script must have a `usage()` function

## Standard script structure (preserve this order)
1. Shebang + safety flags
2. Constants / config variables (`readonly`)
3. `usage()` function
4. Helper functions (`log`, `err`, `die`)
5. Core logic functions
6. `main()` function
7. `main "$@"` at the bottom — always last line

## Naming conventions
- Script files: `kebab-case.sh`
- Functions: `snake_case`
- Constants: `UPPER_SNAKE_CASE`
- Local variables: `lower_snake_case`
- Folder name matches script name exactly

## Testing
- Syntax check: `bash -n script-name.sh`
- Every script must be invocable with `--help` and produce useful output
- Include at least one concrete usage example in the README

## Commit conventions
- Prefix every commit with the script folder name: `script-name: description`
- For repo-wide changes (README, CLAUDE.md, .gitignore, CI): use `repo: description`
- For new scripts: `script-name: add initial implementation`
- For bug fixes: `script-name: fix <what was broken>`
- For docs-only changes: `script-name(docs): update README`
- Keep subject line ≤ 72 characters, lowercase after the prefix colon
- Use imperative mood: "add", "fix", "remove" — not "added", "fixed"

Examples:
```
ai-local-stack: add --dry-run flag to start command
ai-local-stack(docs): document GPU memory requirements
repo: add .gitignore and git init
repo: update global CLAUDE.md with commit conventions
```

## What NOT to do
- No hardcoded absolute paths — use variables or detect at runtime
- No silent failures — always handle errors explicitly
- Do not put script-specific context in this global file; use a local CLAUDE.md instead
- Do not delete or restructure the `main "$@"` pattern
