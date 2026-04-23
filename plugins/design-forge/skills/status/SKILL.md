---
name: status
description: |
  Show design-forge project state: system.md presence, last audit timestamp, open findings count, latest fix-history. Use when user says: "forge status", "design-forge status", "show design state", "audit state", "status des design systems", "zeige design forge status".
user-invocable: false
allowed-tools: Read, Glob, Bash
model: sonnet
---

# Design-Forge Status — Project Memory State

## Purpose

Quick-overview of design-forge state in current project. Read-only.

## Trigger Conditions

Hidden skill. Invoked via natural language:
- "show design forge status"
- "design system status"
- "is design-forge initialized?"
- German: "design-forge status", "zeige design status"

## Orchestration

### Step 1: Check Memory

```bash
if [ -f .design-forge/system.md ]; then
  echo "MEMORY: found"
else
  echo "MEMORY: missing"
fi
```

### Step 2: Count Findings

```bash
find .design-forge/findings -name "*.json" 2>/dev/null | wc -l
```

### Step 3: Latest Report

```bash
ls -t .design-forge/reports/*.md 2>/dev/null | head -1
```

Read first 40 lines for summary.

### Step 4: Fix History

```bash
ls -t .design-forge/fixes/*.json 2>/dev/null | head -3
```

### Step 5: Present Report

Format:

```
## Design-Forge Status — <project_name>

### Memory (.design-forge/system.md)
{✅ Initialized | ❌ Missing — run init}

If Initialized:
  Framework:       <framework>
  Token Format:    <token_format>
  Intent Who:      <intent.who>
  Intent What:     <intent.what>
  Intent Feel:     <intent.feel>
  Decisions:       <count> logged
  Last Updated:    <latest decision date>

### Findings Artifacts
  Last run:      <timestamp or "never">
  Agents reported: <N>/10
  Cached files:  <N>

### Reports
  Latest: <filename>
  Summary: <first 5 lines>

### Fix History
  Last fix:      <timestamp>
  Applied:       <count>
  Phase:         <safe/medium/risky>

### Next Steps
  {if no memory} → run init
  {if memory, no audit} → run audit
  {if audit, blockers} → run fix --safe-only
  {if all green} → you're up to date
```

## Verification

- Read-only: no files modified
- If .design-forge/ missing entirely: show "not initialized, run init"
