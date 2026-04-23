---
name: fix
description: |
  Apply design-forge auto-fixes with risk-phased Git checkpoints. Use when user says: "fix design-forge findings", "auto-fix design issues", "apply design fixes", "fix the audit", "forge fix", "behebe die findings", "repariere design issues". Dispatches design-fixer agent.
user-invocable: false
allowed-tools: Read, Task, Bash
argument-hint: "[--safe-only|--confirm|--aggressive] [--allow-dirty]"
model: sonnet
---

# Design-Forge Fix — Risk-Phased Auto-Fixer

## Purpose

Orchestration layer for the `design-fixer` agent. Reads the latest audit report, determines fix mode, dispatches the fixer with appropriate flags.

## Trigger Conditions

Hidden skill:
- "fix the design-forge findings"
- "auto-fix design issues"
- "apply safe fixes"
- German: "behebe design-forge findings", "repariere"

## Arguments

- `--safe-only` (default): Only apply auto_fixable=safe findings
- `--confirm`: Also apply medium-severity with per-fix user confirmation
- `--aggressive`: Include risky fixes (explicit per-fix user-confirmation)
- `--allow-dirty`: Skip git-clean precondition check (risky!)

## Orchestration

### Step 1: Verify Latest Audit Exists

```bash
ls -t .design-forge/reports/audit-*.json 2>/dev/null | head -1
```

If none → "No audit report found. Run /design-forge:audit first."

### Step 2: Preflight Git Check

```bash
git rev-parse --is-inside-work-tree 2>/dev/null && git status --porcelain
```

If git-not-available: warn "Git not available — fixes will not be rollback-safe. Continue? [y/n]"

If uncommitted changes AND --allow-dirty NOT set: stop, "Uncommitted changes detected. Commit/stash first, OR use --allow-dirty."

### Step 3: Dispatch design-fixer Agent

```
Task(
  subagent_type="design-fixer",
  description="Auto-fix design-forge findings",
  prompt="""
Latest audit report: .design-forge/reports/audit-<latest>.json
Mode: <mode-from-flags>
Allow-dirty: <bool>

Execute per your system prompt: read findings, classify into safe/medium/risky phases,
create Git stash checkpoints between phases, apply fixes, re-audit verification, write
fix-artifact to .design-forge/fixes/fix-<timestamp>.json.
"""
)
```

### Step 4: Present Result

After fixer completes, show:

```
## Design-Forge Fix — Phase Summary

### Phase: Safe
  Attempted: N
  Applied:   N
  Failed:    N
  Git checkpoint: <stash-id>

### Phase: Medium  (if --confirm)
  Attempted: N
  Applied:   N (after confirmation)

### Phase: Risky   (if --aggressive)
  Attempted: N

### Totals
  Fixed:           N / N
  Residual:        N (manual review needed)
  Git checkpoints: <list> (rollback: git stash apply <id>)

### Next Steps
  - Re-run /design-forge:audit to verify
  - OR git stash apply <id> to rollback specific phase
  - OR commit the fixed state: git add -A && git commit -m "design-forge auto-fixes"
```

## Rollback

Instruct user how to rollback:
```bash
# Full rollback (all phases):
git stash apply <before_safe_stash_id>

# Partial rollback (undo risky only, keep safe):
git stash apply <before_risky_stash_id>
```

## Verification

- Fix artifact exists at `.design-forge/fixes/fix-<timestamp>.json`
- Schema validates
- All applied fixes have git_stash_id
- Git log shows stash entries
