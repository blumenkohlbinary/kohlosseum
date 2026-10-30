# Context Mechanics Quick Reference

## Loading Behavior

| Source | When Loaded | Mechanism |
|--------|-------------|-----------|
| Root CLAUDE.md + @imports | Session start | Eager |
| Subdirectory CLAUDE.md | When Claude reads files in that dir | Lazy |
| MEMORY.md (first 200 lines) | Session start | Eager |
| Topic files (memory/*.md) | On-demand when Claude needs them | Lazy (feature-flagged) |
| .claude/rules/*.md | When glob pattern matches active file | Conditional |

## @Import Syntax
- Format: `@docs/architecture.md` (relative path in CLAUDE.md)
- Glob support: NOT available (`@docs/*.md` does not work)
- Non-existent refs: silently ignored, no error
- Token cost: imported content counts in context window same as inline content

## MEMORY.md Truncation

- Hard limit: **200 lines** (source code constant: `pZ = 200`)
- Direction: loads **first 200 lines only**, rest is silently dropped
- New entries appended at bottom are the first to be lost
- No warning or error when truncation occurs
- Disable auto-memory: `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` or `/memory` toggle

## Topic File Discovery

- MEMORY.md acts as index; Claude moves details to topic files
- Topic files load on-demand -- but automatic scanning is **behind a feature flag** (`tengu_coral_fern`, off by default)
- No auto-deletion, consolidation, or archiving of topic files
- No hard size limit on topic files (200-line recommendation only)
- Granular control (MEMORY.md only, no topics) not available

## Rules Frontmatter

| Field | Status |
|-------|--------|
| `paths:` | Documented — FILTERS project rules (measured 16.09.2026: 13 of 13 not loaded at start, `path_glob_match` 11x) |
| `globs:` | Cursor field — filters NOTHING in Claude Code (measured: `path_glob_match` 0x in 3667 load events); such a rule loads ALWAYS |
| `description:` | Not documented for rules |
| `priority:` / `enabled:` | Not supported |
| `alwaysApply:` | Continue ecosystem only, not Claude Code |

### paths vs globs — corrected v5.174.0 (this section said the opposite until then)

```yaml
# FILTERS (project rules, measured):
paths:
  - "src/**/*.ts"

# FILTERS NOTHING in Claude Code -- the rule loads always:
globs: src/**/*.ts, tests/**/*.ts
```

Additional notes:
- `paths:` in user-level rules (`~/.claude/rules/`) is UNMEASURED (issues #21858/#22170) — only a fresh session decides it
- No defined priority order when multiple rules match the same path
- Rule without `paths:`/`globs:` frontmatter -> always loaded

## claudeMdExcludes

- Setting in `settings.json` to skip subdirectory CLAUDE.md files
- Intended for monorepo scenarios
- Exact format (array vs string, glob syntax) not documented
- Whether it can exclude root CLAUDE.md: unknown

## --add-dir External Context

```bash
CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude --add-dir /other/project
```
Without the env var, CLAUDE.md from --add-dir directories is NOT loaded.

## Subagent Memory (Separate System)
3 scopes: `.claude/agent-memory/<name>/` (project, git-versionable) | `~/.claude/agent-memory-local/<name>/` (local) | `~/.claude/agent-memory/<name>/` (user-global). Independent from MEMORY.md.

## Debugging
Use `InstructionsLoaded` hook to log which instruction files load, when, and why.

## Rules vs Subdirectory CLAUDE.md
- **Rules:** glob-pattern activation, project-root relative, best for domain-specific tech rules
- **Subdir CLAUDE.md:** directory-based lazy activation, subdir relative, best for subproject instructions
