---
name: mind-status
description: |
  [Mind Manager] Show a complete dashboard of all Claude Code context files: CLAUDE.md (all scopes
  including Enterprise), MEMORY.md, topic files, rules, @imports, .claudeignore, MCP
  servers, skills, agents, and active plugins. Displays line counts, estimated token
  usage, and a health score (0-100) with compliance rate prognosis.

  Use when the user says "mind status", "context status", "show my context",
  "how much context am I using", "memory status", "context overview",
  "what context files do I have", or "/mind-status".
argument-hint: "[--verbose]"
context: inherit
allowed-tools: Read Glob Grep Bash
---

# Context Dashboard

Display a complete overview of all context files with health assessment.

## Objective

Discover, count, and assess ALL context files in the current project and user scope. Present a clear dashboard with line counts, token estimates, and health score.

## Workflow

### Step 1: Parse Arguments

Check `$ARGUMENTS` for `--verbose` flag. Verbose mode shows file content previews.

### Step 2: Discover All Context Files

Scan these locations using Glob and Read:

**Always-loaded files:**
- `~/.claude/CLAUDE.md` (global)
- `./CLAUDE.md` or `./.claude/CLAUDE.md` (project)
- `./CLAUDE.local.md` (local — flag deprecation if found)
- Enterprise paths: `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS), check `%PROGRAMDATA%\ClaudeCode\CLAUDE.md` on Windows via Bash

**Rules:**
- `.claude/rules/*.md` (project rules)
- `~/.claude/rules/*.md` (user rules)
- `.claude/rules/active-context.md` (auto-generated session context — flag as "auto-managed" if present)

**Memory:**
- `~/.claude/projects/<hash>/memory/MEMORY.md` (auto-memory stays here)
- `<cwd>/.claude-mind/*.md` (topic files)

**Configuration:**
- `.claudeignore` — count entries, show which directories/patterns are ignored, flag entries that reference non-existent paths (use `test -d` or `test -e`)
- `.mcp.json` (count MCP servers)
- `~/.claude/mcp_settings.json` (global MCP)

**Extensions:**
- `.claude/skills/*/SKILL.md` and `~/.claude/skills/*/SKILL.md`
- `.claude/agents/*.md` and `~/.claude/agents/*.md`

**Experimental (scan if directories exist):**
- `.claude/agent-memory/*/`
- `~/.claude/agent-memory-local/*/`
- `~/.claude/agent-memory/*/`

**Additional directories:**
- Check if `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` env var is set

### Step 3: Count Lines and Estimate Tokens

For each discovered file, use Bash `wc -l` to count lines. Estimate tokens using: `lines * 10` (conservative average).

### Step 4: Calculate Health Score (0-100)

Use the scoring rubric from [references/budget-thresholds.md](../audit/references/budget-thresholds.md):

**Structure Quality (0-30):** Heading usage, bullet points, section ordering, modularity
**Budget Efficiency (0-30):** CLAUDE.md <150 lines, MEMORY.md <150 lines
**Hygiene (0-25):** No stale paths (estimated), no obvious contradictions
**Best Practices (0-15):** .claudeignore exists, rules use globs:, progressive disclosure used

### Step 5: Output Dashboard

```
=== Claude Mind Manager — Context Dashboard ===

Health Score: XX/100
Compliance Prognosis: ~XX% (based on SFEIR data for N total instruction lines)

| File                              | Lines | ~Tokens | Grade | Status          |
|-----------------------------------|-------|---------|-------|-----------------|
| ~/.claude/CLAUDE.md (global)      | 45    | ~450    | B     | OK              |
| ./CLAUDE.md (project)             | 120   | ~1200   | A     | OK              |
| MEMORY.md                         | 185   | ~1388   | —     | WARNING >180    |
| .claude/rules/typescript.md       | 30    | ~300    | —     | OK (globs:)     |
| .claude/rules/api.md              | 25    | ~250    | —     | WARNING (paths:)|
| .claude-mind/debugging.md (topic) | 45    | ~450    | —     | OK              |
| .claudeignore                     | —     | —       | —     | EXISTS          |
| .mcp.json (2 servers)             | —     | ~28000  | —     | 2 × ~14K       |

Total estimated always-loaded context: ~X,XXX tokens
Estimated on-demand context: ~X,XXX tokens
MCP overhead: ~X,XXX tokens
Skills/Agents loaded: N skills, N agents (~2% context per skill)
Compaction threshold: ~167,000 tokens

Recommendations:
- MEMORY.md near limit (185/200) → run /mind-cleanup
- 1 rule uses paths: instead of globs: → run /mind-rules migrate
```

If `--verbose`: show first 5 lines of each file as preview.

### Step 6: Hook Health (if log exists)

Read the mind-manager log:
```
Bash: tail -50 "$TEMP/mind-manager.log" 2>/dev/null || tail -50 /tmp/mind-manager.log 2>/dev/null
```

If the log exists, parse the last 50 lines:
- Count lines matching `context saved` → extract byte values with `grep -oE '[0-9]+ bytes'`, calculate average
- Count `context unchanged, skip write` → MD5-skip saves
- Count `backup triggered` and `backup skipped`
- Count `learnings extracted`
- Count lines with `ERROR` or `WARN`
- Count `recurring learning detected` → learning promotion candidates

Display after main dashboard:
```
### Hook Health (last 50 log entries)
| Metric | Value |
|--------|-------|
| Context saves | 14 (avg 2,400 bytes, range 1,200-3,000) |
| MD5 skips | 3 (18% I/O saved) |
| Backups | 2 triggered, 1 skipped (unchanged) |
| Learnings | 1 extraction (4 entries) |
| Recurring learnings | 0 promotion candidates |
| Warnings | 0 | Errors | 0 |
| Log | /tmp/mind-manager.log (87 lines) |
```

If log not found: show `Hook log: not found (no session activity yet)` and skip this step.

### Step 7: .claudeignore Recommendation (if missing)

If `.claudeignore` does not exist, check which of these directories are present:
`node_modules/`, `dist/`, `build/`, `.next/`, `__pycache__/`, `target/`, `coverage/`,
`.claude-mind/backups/`, `.claude-mind/sessions/`, `Beispiele/`, `Wissen/`

Use `test -d` for each. For every existing directory, add to recommendation list.

Display after dashboard:
```
.claudeignore: MISSING — recommended patterns based on detected directories:
  .claude-mind/backups/   (exists)
  .claude-mind/sessions/  (exists)
  node_modules/           (exists)
Run /mind-audit to create automatically, or create manually.
```

## Hard Constraints

- NEVER modify any files — this skill is read-only
- NEVER create any files
- ALWAYS check `<cwd>/.claude-mind/` for topic files
- ALWAYS show compliance prognosis based on total line count
- ALWAYS flag CLAUDE.local.md as deprecated if found
- ALWAYS flag rules using paths: instead of globs:
