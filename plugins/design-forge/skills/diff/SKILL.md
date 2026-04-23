---
name: diff
description: |
  Incremental audit: only scan files changed since a Git reference. Use when user says: "design-forge diff", "audit changed files", "audit since last commit", "forge diff", "audit nur änderungen", "inkrementeller audit". Faster than full audit for iterative workflows.
user-invocable: false
allowed-tools: Read, Task, Bash
argument-hint: "[--since=<git-ref>]"
model: sonnet
---

# Design-Forge Diff — Incremental Audit

## Purpose

Run `/design-forge:audit` but only over files changed since a Git reference. Saves time on large projects during iteration.

## Trigger Conditions

Hidden skill. Claude invokes when user says:
- "audit changed files"
- "forge diff"
- "only check what I changed"
- German: "nur änderungen prüfen", "inkrementell"

## Arguments

- `--since=<git-ref>`: Git reference (default: HEAD, options: main, develop, <sha>, <tag>)

## Orchestration

### Step 1: Resolve Changed Files

```bash
git diff --name-only --diff-filter=ACM "${SINCE:-HEAD}" | grep -E '\.(css|scss|sass|html|jsx|tsx|vue|svelte)$'
```

If empty: "No frontend changes since <ref>. Nothing to audit."

### Step 2: Compare with Latest Report

```bash
LATEST=$(ls -t .design-forge/reports/audit-*.json 2>/dev/null | head -1)
```

If exists: load previous findings, pass to critic for delta-analysis.

### Step 3: Dispatch Audit with Narrowed Scope

Invoke the primary audit skill (`/design-forge:audit`) with the filtered file list as scope. Pass `--since=<ref>` and the previous report path so the critic can compute the delta (new/resolved/unchanged).

### Step 4: Present Delta

```
## Incremental Audit — since <git-ref>

Files changed: N
Audited: N

### New findings (introduced by these changes)
{N blockers, M high, ...}

### Resolved findings (fixed by these changes)
{N previously-flagged issues now clean}

### Unchanged
{N findings persisting from previous audit}

Net delta: +N introduced, -N resolved
```

## Verification

- Only changed files scanned
- Delta report shows new vs resolved
- Full report still written to `.design-forge/reports/audit-<ts>.md` with diff-marker
