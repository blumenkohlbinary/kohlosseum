---
name: mind-files
description: |
  [Mind Manager] Projekt-Setup Vollverwaltung — erkennt Projekttyp, erstellt/prueft/verbessert alle Dateien.
  Scannt Repo fuer Tech-Stack, vergleicht Ist- mit Soll-Zustand basierend auf Projekttyp
  (Python, Node.js, C#, Docs-Only, Plugin, MCP Workspace), zeigt fehlende/verbesserbare Dateien,
  erstellt mit User-Bestaetigung.

  Use when the user says "setup project", "check project files", "mind files",
  "scaffold", "init project", "bootstrap project", "check setup",
  or "/mind-files".
context: inherit
allowed-tools: Read Glob Grep Write Bash Agent
---

# Projekt-Setup Vollverwaltung

Projekttyp erkennen -> Soll-Zustand definieren -> Ist pruefen -> User-OK -> Erstellen/Verbessern.

## Step 1: Projekttyp erkennen

Dispatch **project-scanner** agent:
"Scan this project for tech stack, project type, build/test/lint commands, key directories, frameworks, and package manager. Report structured findings."

## Step 2: Referenzen laden

Read these reference files for templates and best practices:
- [references/templates.md](../../references/templates.md) -- 7 project type templates
- [references/claudemd-best-practices.md](../../references/claudemd-best-practices.md) -- Required sections, anti-patterns
- [references/context-file-guide.md](../../references/context-file-guide.md) -- Complete file catalog

## Step 3: Soll-Zustand definieren

Based on project-scanner results, define what files this project SHOULD have:

| Type | Claude Files | Project Files |
|---|---|---|
| Python | CLAUDE.md, .claude/rules/, .claude/settings.json | pyproject.toml, src/, tests/, .gitignore |
| Node.js | CLAUDE.md, .claude/rules/, .claude/settings.json | package.json, tsconfig.json, .gitignore |
| C# / Unity | CLAUDE.md, .claude/rules/patterns.md | .sln, .csproj, .gitignore |
| Docs-Only | CLAUDE.md (minimal) | -- |
| Plugin | CLAUDE.md, .claude/rules/ | plugin.json, agents/, skills/ |
| MCP Workspace | CLAUDE.md, .mcp.json | -- |

### Claude-Specific Files (check for all types):

| File | Purpose | Check |
|---|---|---|
| `CLAUDE.md` | Project instructions | Exists? Has build commands? Has architecture? |
| `.claude/settings.json` | Permissions | Exists? Has `permissions.deny` for sensitive patterns? |
| `.claude/rules/*.md` | Conditional rules | Any rules exist? Are they well-structured? |
| `.claudeignore` | Token savings | Exists? Covers node_modules, dist, build, etc.? |
| `.mcp.json` | MCP server config | Only for MCP-enabled projects |

### Security Best-Practice Checks:

| Check | What | Where |
|---|---|---|
| Deny .env access | `permissions.deny` includes `.env*` patterns | .claude/settings.json |
| Deny credentials | `permissions.deny` includes credential file patterns | .claude/settings.json |
| Ignore large dirs | node_modules, dist, .git, __pycache__ etc. | .claudeignore |

## Step 4: Ist-Zustand pruefen (Gap-Analyse)

For each file in the Soll-Zustand:

**If MISSING:** Add to "Create" list with:
- What would be created (preview content)
- Why it's needed
- Priority (CRITICAL / RECOMMENDED / NICE-TO-HAVE)

**If EXISTS:** Run quick best-practice check:
- CLAUDE.md: Has build commands? Architecture section? Under 200 lines?
- settings.json: Has `permissions.deny`? Denies `.env*`?
- .gitignore: Covers build artifacts for this project type?
- .claudeignore: Covers large directories?

Present findings:

```
=== Project Setup Report ===

Project Type: Node.js (detected: package.json, tsconfig.json, src/)
Tech Stack: TypeScript, React, Vitest

### Missing Files (3)
[1] CRITICAL    .claude/settings.json — No permission restrictions configured
    -> Will create with deny patterns for .env, credentials, secrets
[2] RECOMMENDED .claudeignore — No token savings configured
    -> Will create ignoring node_modules/, dist/, coverage/, .next/
[3] NICE-TO-HAVE .claude/rules/testing.md — No testing conventions documented
    -> Will create with globs: **/*.test.ts, **/*.spec.ts

### Existing Files (3)
[4] OK          CLAUDE.md — 85 lines, has build commands, architecture section
[5] IMPROVE     .gitignore — Missing: coverage/, .env.local
[6] OK          package.json — Valid, has scripts

### Summary
Create: 3 files | Improve: 1 file | OK: 2 files

Proceed? [Yes / Select / Skip]
```

**STOP HERE. Warte auf User-Bestaetigung.**

## Step 5: Dateien erstellen/verbessern (nach User-OK)

For each confirmed action:

### Creating new files:

**CLAUDE.md** (if missing):
- Use template from references/templates.md matching the detected project type
- Fill with scan data (tech stack, build commands, directory structure)
- Target: 40-80 lines, max 100
- MUST pass generation checklist:
  - [ ] Has build/test commands section?
  - [ ] Has architecture/structure section?
  - [ ] Has conventions section?
  - [ ] No generic advice?
  - [ ] Under 100 lines?

**.claude/settings.json** (if missing):
```json
{
  "permissions": {
    "deny": [
      "Edit .env*",
      "Edit *credentials*",
      "Edit *secret*",
      "Edit *.pem",
      "Edit *.key"
    ]
  }
}
```

**.claudeignore** (if missing):
- Auto-detect which directories exist using `test -d`:
  node_modules/, dist/, build/, .next/, __pycache__/, target/,
  coverage/, .claude-mind/backups/, .claude-mind/sessions/
- Only include directories that actually exist

**Rule files** (if missing):
- Create with appropriate `globs:` pattern
- Use MUST/NEVER/ALWAYS format
- Keep under 30 lines

### Improving existing files:

| Improvement | Tool | Aktion |
|---|---|---|
| Add missing .gitignore entries | Edit | Append missing patterns |
| Add permissions.deny entries | Edit | Add to existing settings.json |
| Add missing CLAUDE.md section | Edit | Insert section at appropriate position |

## Step 6: Summary

```
=== Project Setup Complete ===
Created: 3 files (settings.json, .claudeignore, testing.md)
Improved: 1 file (.gitignore: +2 patterns)
Already OK: 2 files
Project readiness: Good (all critical files present)
```

## Hard Constraints

- NEVER overwrite existing files without user confirmation
- NEVER create files without showing preview content first
- ALWAYS show what would be created/changed before doing it
- ALWAYS use Write for new files, Edit for modifications
- ALWAYS check if directories exist before creating files in them (mkdir -p if needed)
- For CLAUDE.md generation: ALWAYS use project-scanner results, NEVER guess
- For settings.json: ALWAYS include .env* in deny patterns (security baseline)
- NEVER include secrets, API keys, or credentials in any generated file
