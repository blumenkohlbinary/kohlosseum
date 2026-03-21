# Community Pain Points & Competitor Reference

## 8 Pain Points Checklist

### 1. Rules Silently Ignored
- **Detection:** `paths:` in rule frontmatter with YAML lists or quoted strings; user-level rules with `paths:`
- **Fix:** Migrate `paths:` to `globs:` format: `globs: src/**/*.ts, tests/**/*.ts`
- **Severity:** Critical, frequent

### 2. MEMORY.md Overflows Without Warning
- **Detection:** `wc -l < MEMORY.md` exceeds 180 lines
- **Fix:** SessionStart hook warning at >180 lines; `/mind-compact` to trim
- **Severity:** Critical, frequent -- data silently lost beyond line 200

### 3. No Overview of All Context Files
- **Detection:** User cannot see all active CLAUDE.md, rules, MEMORY.md, topic files in one view
- **Fix:** `/mind-status` command listing all context files with line counts + token estimates
- **Severity:** Medium, quality-of-life

### 4. Contradictions Between CLAUDE.md and Memory
- **Detection:** Conflicting instructions across CLAUDE.md files and MEMORY.md
- **Fix:** Conflict-detector scanning all context sources for contradictory directives
- **Note:** 60% of generation errors on complex projects linked to ambiguous instructions

### 5. Auto-Memory Writes Irrelevant Content
- **Detection:** MEMORY.md contains stale, duplicate, or low-value entries
- **Fix:** Hygiene scan checking for outdated/irrelevant entries; cleanup suggestions
- **Workaround:** Explicit prompts: "Update your memory files with what you learned today"

### 6. Cross-Project Knowledge Lost
- **Detection:** Learned patterns in Project A unavailable in Project B
- **Fix:** Cross-project index skill (technically complex)
- **Note:** Global CLAUDE.md must be maintained manually

### 7. CLAUDE.md Compliance Degrades With Length
- **Detection:** CLAUDE.md exceeds 200 lines (compliance drops from 92% to 71% at 400+ lines)
- **Fix:** Progressive disclosure -- essentials in CLAUDE.md, details in @import or rules
- **Threshold:** Warn at >150 lines, critical at >300 lines

### 8. InstructionsLoaded Hook Unknown to Users
- **Detection:** User unaware which context files load and when
- **Fix:** Debug mode auto-configuring `InstructionsLoaded` hook for visibility
- **Note:** Only hook that reveals file loading behavior

---

## Competitor Comparison

| Feature | Claude Code | Cursor | Copilot | Cline | Aider |
|---------|------------|--------|---------|-------|-------|
| Context files | CLAUDE.md + rules | .cursor/rules/*.mdc | .github/copilot-instructions.md | .clinerules | .aider.conf.yml |
| Auto-memory | MEMORY.md (auto) | -- | -- | Memory Bank (manual) | Chat history |
| Memory overflow protection | -- | n/a | n/a | n/a | n/a |
| Hook system | 22 events, 4 handler types | 5 events, command only | preToolUse only | -- | -- |
| Glob-based rules | paths:/globs: | globs in .mdc | -- | -- | -- |
| Context overview | /context (visual) | -- | -- | -- | -- |
| Conflict detection | -- | -- | -- | -- | -- |

### Claude Code Advantages Over Competitors
- Auto-memory (writes automatically, no manual setup)
- Agent/prompt hooks (semantic decisions, not just command)
- Structured JSON hook output with tool-input modification
- Multiple context levels (global/project/rules)

### Competitor Advantages Over Claude Code
- **Cursor:** @Docs integration (external docs as context), context pinning, notepad scratch-pad
- **Cline:** Structured Memory Bank with typed files (projectbrief, activeContext, progress)
- **Aider:** Automatic repo-map as context

### Mind Manager USP Matrix

| Capability | Native | Mind Manager |
|-----------|--------|-------------|
| Memory overflow warning | -- | SessionStart hook |
| Full context overview | /context (visual only) | /mind-status (files + tokens) |
| Conflict detection | -- | Analyzer skill |
| Rules syntax audit | -- | paths: -> globs: migration |
| Cross-project index | -- | Index skill |
| Pre-compact backup | -- | Built-in diary mechanism |
| Memory hygiene | -- | Cleanup suggestions |
