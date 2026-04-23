---
name: init
description: |
  Interactive Intent-Dialog to initialize .design-forge/system.md for a project. Use when user says: "initialisiere design-forge", "create design system memory", "setup design tokens", "forge init", "init design forge", "start design system", "create .design-forge/system.md". Asks Who/What/Feel intent questions, detects project framework, suggests initial tokens, writes system.md.
user-invocable: false
allowed-tools: Read, Glob, Write, Bash
model: sonnet
---

# Design-Forge Init — Memory Bootstrap

## Purpose

Initialize `.design-forge/system.md` — the persistent design-system memory file. Based on interface-design's Intent-First philosophy (Who/What/Feel), adapted with design-forge Token-Architecture.

## Trigger Conditions

Hidden skill (`user-invocable: false`). Claude invokes when user expresses intent via natural language:
- "initialize design forge"
- "setup design system for this project"
- "create design-forge memory"
- "forge init"
- German variants: "design-forge einrichten", "design-system anlegen"

## Orchestration

### Step 1: Check if Already Initialized

```bash
ls .design-forge/system.md 2>/dev/null
```

If exists: Ask user "system.md already exists. Reinitialize (overwrites)? View current status via forge-status instead?"

### Step 2: Detect Project Framework

Scan for indicators:
- `package.json` → parse `dependencies` for react/vue/svelte/angular
- `requirements.txt` / `pyproject.toml` → python-pyqt / python-tkinter
- `tailwind.config.*` → tailwind-v3/v4
- `*.css` + `*.html` with no JS framework → html

### Step 3: Intent Dialog (3 Questions)

Present these 3 questions, collect free-text answers:

**Q1 — Who is this human?**
Not "users". The actual person. Where are they when they open this? What's on their mind?

**Q2 — What must they accomplish?**
Not "use the dashboard". The verb. Grade submissions. Find broken deployment. Approve payment.

**Q3 — What should this feel like?**
Not "clean and modern" — every AI says that. Warm like a notebook? Cold like a terminal? Dense like a trading floor? Calm like a reading app?

### Step 4: Suggest Direction

Based on Q3 answer, suggest:
- `personality`: descriptive keyword (e.g. "editorial", "precision-instrument", "warm-workspace")
- `foundation`: light|dark|both|system-adaptive
- `depth`: flat|subtle-depth|layered-elevation

Confirm with user.

### Step 5: Token Defaults

Propose baseline tokens:
- `rules.spacing_grid`: [4, 8, 12, 16, 24, 32, 48, 64]
- `rules.contrast_min_ratio`: 4.5 (AA standard)
- `rules.icon_sizes`: [16, 20, 24]
- `rules.breakpoints`: [640, 768, 1024, 1280, 1536]
- `rules.type_scale_ratio`: 1.25 (Major Third — SaaS default)
- `rules.elevation_levels`: 5

User can override each.

### Step 6: Write system.md

Create `.design-forge/system.md` with YAML frontmatter + markdown body:

```markdown
---
version: "1.0.0"
project_name: <detected or asked>
framework: <detected>
token_format: <detected>
intent:
  who: <Q1 answer>
  what: <Q2 answer>
  feel: <Q3 answer>
direction:
  personality: <suggested>
  foundation: <suggested>
  depth: <suggested>
tokens:
  primitives:
    colors: {}
    spacing: [4, 8, 12, 16, 24, 32, 48, 64]
    typography: {}
  semantic: {}
  component: {}
rules:
  spacing_grid: [4, 8, 12, 16, 24, 32, 48, 64]
  elevation_levels: 5
  contrast_min_ratio: 4.5
  icon_sizes: [16, 20, 24]
  breakpoints: [640, 768, 1024, 1280, 1536]
  type_scale_ratio: 1.25
decisions:
  - date: "<today ISO>"
    what: "Initialized design-forge memory"
    why: "Project-specific design-system baseline"
    author: "<from git config or env>"
themes:
  light: {}
  dark: {}
---

# <project_name> Design System

## Intent

**Who:** <intent.who>
**What:** <intent.what>
**Feel:** <intent.feel>

## Direction

- **Personality:** <direction.personality>
- **Foundation:** <direction.foundation>
- **Depth:** <direction.depth>

## Notes

Add additional context, examples, or decisions below.
```

### Step 7: Validate Schema

```bash
python -c "import yaml, json, jsonschema; data = yaml.safe_load(open('.design-forge/system.md').read().split('---')[1]); schema = json.load(open('<plugin>/schemas/system.schema.json')); jsonschema.validate(data, schema); print('VALID')"
```

If jsonschema unavailable, just verify YAML parses.

### Step 8: Confirm to User

```
✅ .design-forge/system.md created.

Intent:
  Who:  <who>
  What: <what>
  Feel: <feel>

Rules:
  Spacing Grid:  [4, 8, 12, 16, 24, 32, 48, 64]
  Min Contrast:  4.5:1 (WCAG AA)
  Breakpoints:   [640, 768, 1024, 1280, 1536]

Next: run /design-forge:audit to baseline your project.
```

## Verification

- `.design-forge/system.md` exists
- YAML frontmatter parses
- Required keys present: version, project_name, framework
- User confirmed all 3 intent answers
