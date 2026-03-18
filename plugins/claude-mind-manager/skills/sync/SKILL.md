---
name: sync
description: |
  Detect and resolve contradictions between CLAUDE.md, MEMORY.md, and rules. Finds
  conflicting instructions, version mismatches, redundant entries, and scope conflicts.
  Presents each conflict with resolution options and applies selected fixes.

  Use when the user says "sync context", "find contradictions", "mind sync",
  "context conflicts", "fix inconsistencies", "resolve conflicts", or "/mind:sync".
context: inherit
allowed-tools: Read Glob Grep Edit Agent
---

# Context Synchronization

Detect and resolve contradictions between context files.

## Objective

Find semantic contradictions, version mismatches, and redundancies across all context files. Present each conflict with resolution options and apply user-chosen fixes.

## Workflow

### Step 1: Dispatch Analyzer

Launch the **claude-md-analyzer** agent with focus on cross-file contradictions:
"Read all CLAUDE.md files (global, project, local), MEMORY.md, and rule files. Find contradictions: instructions that conflict, version mismatches, and redundant entries expressed differently. Report each with exact file:line references."

### Step 2: Categorize Conflicts

Group findings into categories:

**Direct Contradictions:** Opposite instructions
- "Use jest" in CLAUDE.md vs "Prefer vitest" in MEMORY.md

**Version Mismatches:** Different versions of the same thing
- "Node 18" in MEMORY.md vs "Node 20" in CLAUDE.md

**Redundant Instructions:** Same meaning, different wording
- "Always format with prettier" in CLAUDE.md AND "Code formatting: prettier" in MEMORY.md

**Scope Conflicts:** Lower scope unintentionally overrides higher
- Global: "Use tabs" vs Project: "Use spaces" (may be intentional)

### Step 3: Present Each Conflict

For each conflict, show both sides and offer resolution:

```
=== Conflict #1: Test Runner (Direct Contradiction) ===

  CLAUDE.md:45      → "Test runner: jest"
  MEMORY.md:23      → "User prefers vitest over jest"

  These directly contradict. Resolution options:
  [A] Keep CLAUDE.md (jest) — remove from MEMORY.md
  [B] Keep MEMORY.md (vitest) — update CLAUDE.md
  [C] Keep both (intentional difference between team and personal)
  [D] Skip

=== Conflict #2: Node Version (Version Mismatch) ===

  CLAUDE.md:3       → "Node 20 LTS"
  MEMORY.md:15      → "Node 18 was used for initial setup"

  Resolution options:
  [A] Keep CLAUDE.md (Node 20) — remove stale MEMORY.md entry
  [B] Update CLAUDE.md to match MEMORY.md
  [C] Skip
```

### Step 4: Apply Resolutions

For each user selection, use Edit to:
- Remove the deprecated entry, OR
- Update the outdated entry with correct value
- Show confirmation with updated line counts

### Step 5: Summary

```
=== Sync Complete ===
Resolved: 3 conflicts
Skipped: 1 conflict
CLAUDE.md: 180 → 179 lines
MEMORY.md: 195 → 193 lines
```

## Hard Constraints

- NEVER auto-resolve contradictions — ALWAYS present options
- ALWAYS show both sides with exact file:line references
- ALWAYS wait for user decision before modifying any file
- Scope conflicts (global vs project) may be intentional — present option C
