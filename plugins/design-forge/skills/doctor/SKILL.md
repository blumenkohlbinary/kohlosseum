---
name: doctor
description: |
  Plugin health check — validates design-forge installation, schemas, scripts, and MCP availability. Use when user says: "forge doctor", "design-forge doctor", "design-forge health check", "diagnose plugin", "fix plugin issues", "plugin funktioniert nicht".
user-invocable: false
allowed-tools: Read, Glob, Bash
model: sonnet
---

# Design-Forge Doctor — Plugin Health Check

## Purpose

Validate design-forge installation and flag any issues preventing audit from running correctly.

## Trigger Conditions

Hidden skill:
- "run forge doctor"
- "check plugin health"
- "is design-forge working?"
- German: "design-forge prüfen", "diagnose"

## Checks (Sequential)

### Check 1 — plugin.json Validity

```bash
python -c "import json; d=json.load(open('$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json')); assert d.get('name')=='design-forge'; print('OK')" 2>&1
```

### Check 2 — All Required Agents Present

Expected: 12 files in `agents/`:
- css-auditor, a11y-auditor, color-auditor, typography-auditor, layout-auditor, system-auditor, performance-auditor, motion-auditor, interaction-auditor, visual-auditor, design-critic, design-fixer

```bash
ls "$CLAUDE_PLUGIN_ROOT/agents/"*.md | wc -l
```

Expect ≥10 (M1+M2 minimum), 12 for full release.

### Check 3 — All Guides Present

Expected: 10 guides.

### Check 4 — Schemas Valid

Validate all three JSON schemas parse.

### Check 5 — Scripts Executable

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/contrast.js" "#000" "#fff"
```

Expect JSON output with `wcag_ratio: 21`.

### Check 6 — .design-forge/ Writable

```bash
mkdir -p .design-forge/findings .design-forge/reports
touch .design-forge/.forge-doctor-test && rm .design-forge/.forge-doctor-test
```

### Check 7 — Git Available

```bash
git --version 2>&1
```

Needed for the fix skill / design-fixer agent Git-Checkpoints.

### Check 8 — Optional: Playwright MCP

Check if mcp__playwright__* tools available (for visual-auditor).

### Check 9 — Optional: Node ≥20

```bash
node -v
```

Expect v20.x.x or higher.

### Check 10 — hooks.json Syntax (if exists)

```bash
python -c "import json; json.load(open('$CLAUDE_PLUGIN_ROOT/hooks/hooks.json'))" 2>&1
```

## Report Format

```
## Design-Forge Doctor Report

✅ plugin.json             OK
✅ Agents                  12/12 present
✅ Guides                  10/10 present
✅ Schemas                 3/3 valid
✅ scripts/contrast.js     Works (test: 21:1 for #000/#fff)
✅ .design-forge/          Writable
✅ Git                     2.42.0
⚠️  Playwright MCP          Not installed (optional, needed for visual-auditor)
✅ Node                    v20.18.3
✅ hooks/hooks.json        Valid

Overall: Healthy ✅ (1 warning)

Recommendation:
  Install Playwright MCP for visual regression + multi-viewport testing.
  Otherwise all systems go.
```

## Error Recovery

For each failed check, provide fix-hint:
- plugin.json broken → restore from git or reinstall plugin
- Agents missing → reinstall via marketplace
- Scripts fail → check Node version, reinstall dependencies
- .design-forge/ not writable → check permissions
- Git missing → install git

## Verification

- All checks execute without crashing doctor itself
- Report ends with clear Overall-Status
- Each finding has actionable fix-hint
