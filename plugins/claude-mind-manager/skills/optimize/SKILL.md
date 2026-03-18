---
name: optimize
description: |
  Optimize context budget: shorten verbose entries, modularize large CLAUDE.md sections
  into rules, deduplicate across files, suggest progressive disclosure via @imports,
  migrate CLAUDE.local.md to @import pattern. Uses SFEIR compliance data to show
  projected improvement (5 rules x 30 lines = 96% vs 150-line CLAUDE.md = 92%).

  Use when the user says "optimize context", "reduce tokens", "mind optimize",
  "CLAUDE.md too long", "budget optimization", "token budget", or "/mind:optimize".
argument-hint: "[--dry-run]"
context: inherit
allowed-tools: Read Glob Grep Edit Write Bash Agent
---

# Context Budget Optimizer

Optimize token usage and compliance rate through restructuring.

## Objective

Analyze context files, generate optimization plan with token savings estimates, apply changes with user confirmation. Use `--dry-run` to preview without changes.

## Workflow

### Step 1: Parse Arguments

Check `$ARGUMENTS` for `--dry-run` flag. Dry-run shows plan without applying changes.

### Step 2: Dispatch Optimizer Agent

Launch **context-optimizer** agent:
"Analyze all context files and generate optimization suggestions: shortening, modularization into rules, progressive disclosure via @imports, deduplication, MEMORY.md offloading, missing .claudeignore. Estimate token savings for each suggestion. Order by impact."

### Step 3: Load Reference Data

Read [references/quality-criteria.md](references/quality-criteria.md) for optimization patterns and anti-patterns.

### Step 4: Add Inline Checks

While agent runs, perform additional checks:
- **CLAUDE.local.md migration:** If exists, prepare migration plan
- **Missing .claudeignore:** Generate recommended content
- **Token estimate:** Calculate current vs projected totals

### Step 5: Present Optimization Plan

```
=== Context Optimization Plan ===

Current: ~4,500 tokens | Projected: ~2,800 tokens | Savings: ~1,700 (38%)
Compliance: ~89% → ~96% (modularization + compression)

[1] MODULARIZE: "TypeScript Conventions" → .claude/rules/typescript.md
    Source: CLAUDE.md:30-55 (25 lines, ~250 tokens)
    Target: .claude/rules/typescript.md (globs: **/*.ts, **/*.tsx)
    Savings: ~250 tokens (loads only when editing .ts files)
    Compliance: +4% (SFEIR modularization benefit)
    [Apply / Skip]

[2] SHORTEN: Compress verbose instructions
    CLAUDE.md:12 "When you are writing TypeScript code, always use strict mode"
              → "TypeScript: MUST use strict mode"
    CLAUDE.md:67 "Please make sure to run the linter before committing"
              → "Pre-commit: MUST run linter"
    Savings: ~80 tokens
    [Apply / Skip]

[3] PROGRESSIVE DISCLOSURE: Extract "Database" section
    CLAUDE.md:40-58 (18 lines) → @docs/database.md
    Replace with: "Database: PostgreSQL 16, Prisma ORM. Details: @docs/database.md"
    Savings: ~170 tokens from always-loaded context
    [Apply / Skip]

[4] MIGRATE: CLAUDE.local.md → @import
    Move content to ~/.claude/<project>-instructions.md
    Add @import reference in CLAUDE.md
    [Apply / Skip]

[5] CREATE: .claudeignore
    Recommended: node_modules/, dist/, build/, coverage/, *.lock
    Savings: up to 50% of file-scanning token budget
    [Apply / Skip]
```

### Step 6: Apply (If Not Dry-Run)

For each confirmed suggestion:
- **Modularize:** Write new rule file, Edit CLAUDE.md to remove section
- **Shorten:** Edit CLAUDE.md with compressed text
- **Progressive Disclosure:** Write new doc file, Edit CLAUDE.md with @import
- **Migrate:** Write new file, Edit CLAUDE.md with @import, note CLAUDE.local.md for user to delete
- **Claudeignore:** Write .claudeignore file

### Step 7: Summary

```
=== Optimization Complete ===
Applied: 4 suggestions | Skipped: 1
Token savings: ~1,500 (estimated)
Compliance prognosis: 89% → 96%
Files modified: 2 | Files created: 3
```

## Hard Constraints

- NEVER lose information during optimization — all content must be preserved (relocated, not deleted)
- NEVER apply changes in --dry-run mode
- ALWAYS show before/after comparison for each suggestion
- ALWAYS estimate token savings (lines × 10)
- ALWAYS reference SFEIR compliance data for modularization
- ALWAYS confirm before creating new files
