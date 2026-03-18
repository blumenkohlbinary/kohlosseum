---
name: audit
description: |
  Deep analysis of context health: detect duplicates between CLAUDE.md and MEMORY.md,
  find contradictions, check for stale paths and versions, estimate compliance rate
  using SFEIR data, validate rules syntax (paths: vs globs: migration), find orphaned
  @imports, flag CLAUDE.local.md deprecation. Dispatches 4 specialized agents in parallel.

  Use when the user says "audit my context", "check context health", "mind audit",
  "find contradictions", "check for duplicates", "context problems", "compliance check",
  or "/mind:audit".
argument-hint: "[--focus memory|claude-md|rules|paths]"
context: inherit
allowed-tools: Read Glob Grep Bash Agent
---

# Context Audit

Comprehensive analysis of context health by dispatching specialized agents in parallel.

## Objective

Run a deep audit across all context files using 4 parallel agents, then consolidate findings into a unified report with prioritized recommendations.

## Workflow

### Step 1: Parse Arguments

Check `$ARGUMENTS` for `--focus` filter:
- `memory` — dispatch only memory-auditor
- `claude-md` — dispatch only claude-md-analyzer
- `rules` — run rules check inline (no agent needed)
- `paths` — dispatch only path-validator
- No focus (default) — dispatch ALL 4 agents in parallel

### Step 2: Load Reference Data

Read these reference files for scoring thresholds:
- [references/context-file-guide.md](references/context-file-guide.md) — file catalog
- [references/budget-thresholds.md](references/budget-thresholds.md) — SFEIR compliance data

### Step 3: Dispatch Agents (Parallel)

Launch up to 4 agents simultaneously using the Agent tool:

1. **memory-auditor** — "Scan all memory files in this project for duplicates, stale entries, budget issues, and misplaced content. Report findings with line numbers."

2. **claude-md-analyzer** — "Analyze all CLAUDE.md files across scopes for structure quality, line efficiency, compliance prognosis, @import validation, CLAUDE.local.md deprecation, and cross-scope contradictions."

3. **context-optimizer** — "Analyze all context files and suggest optimizations: shortening, modularization into rules, progressive disclosure via @imports, deduplication, MEMORY.md offloading to topic files."

4. **path-validator** — "Extract all path references and @imports from context files and verify they exist on disk. Report broken references with source locations."

### Step 4: Inline Rules Check

While agents run, perform rules syntax check directly:
- Glob for `.claude/rules/*.md` and `~/.claude/rules/*.md`
- Grep for `^paths:` — flag as "known bug, use globs: instead"
- Check if user-level rules use `paths:` — flag as "does NOT work in user-level rules"
- Check YAML quoting issues

### Step 5: Consolidate Report

Collect all agent results and inline findings. Present consolidated report:

```
=== Claude Mind Manager — Context Audit ===

Health Score: XX/100
Compliance Prognosis: ~XX% (SFEIR: N total instruction lines)

### Critical (action required)
- MEMORY.md: 195/200 lines — overflow imminent → /mind:cleanup
- CLAUDE.md:45 contradicts MEMORY.md:23 (test runner) → /mind:sync
- @import @docs/api.md MISSING — silently ignored → fix path or remove

### Warnings
- 2 rule files use paths: (known bug) → /mind:rules migrate
- CLAUDE.local.md detected (deprecated) → /mind:optimize
- CLAUDE.md:12-18 verbose (could save ~40 tokens) → /mind:optimize
- MEMORY.md:34 stale path "src/old-module/" → /mind:cleanup

### Info
- 3 duplicate entries across files → /mind:cleanup
- .claudeignore missing → /mind:optimize
- 2 optimization opportunities identified → /mind:optimize --dry-run

### Recommended Actions (priority order)
1. /mind:cleanup — resolve overflow and stale entries
2. /mind:rules migrate — fix paths: syntax
3. /mind:sync — resolve contradictions
4. /mind:optimize — compress and modularize
```

## Hard Constraints

- NEVER modify any files — this skill is read-only
- ALWAYS dispatch agents in parallel (not sequentially)
- ALWAYS include specific file:line references for every finding
- ALWAYS calculate health score using budget-thresholds.md rubric
- ALWAYS recommend specific /mind: commands for each finding
