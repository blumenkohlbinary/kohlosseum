---
name: modernize
description: |
  Detect legacy CSS/HTML patterns and suggest modernization (float→grid, media→container queries, px→rem, padding-top-hack→aspect-ratio, JPEG→AVIF). Use when user says: "modernize my CSS", "upgrade legacy patterns", "forge modernize", "modernisiere mein css", "update to modern standards", "css legacy check".
user-invocable: false
allowed-tools: Read, Grep, Glob, Write, Task, Bash
model: sonnet
---

# Design-Forge Modernize — Legacy Pattern Detection

## Purpose

Scan for outdated CSS/HTML patterns and suggest 2024/2025 modern equivalents. Not destructive — suggestions only (fixes via design-fixer).

## Trigger Conditions

Hidden skill:
- "modernize my CSS"
- "what legacy patterns are in my code?"
- "forge modernize"
- German: "modernisiere", "legacy prüfen"

## Legacy Patterns Detected

| # | Legacy | Modern | Matrix A |
|---|--------|--------|----------|
| 1 | `float: left/right` for layout | Grid or Flexbox | — |
| 2 | `@media (min-width: ...)` for component-scoped | `@container (min-width: ...)` | #102 |
| 3 | `padding-top: X%; position: absolute` aspect-ratio | `aspect-ratio: 16/9` | #103 |
| 4 | `font-size: 16px` | `font-size: 1rem` | #6 WCAG 1.4.4 |
| 5 | `calc(100% - 40px)` | `width: stretch` / Grid auto | — |
| 6 | `display: table` layout | Flexbox/Grid | — |
| 7 | `position: absolute` centering | Grid `place-items: center` | — |
| 8 | JPEG/PNG only | AVIF + WebP `<picture>` | #86 |
| 9 | `transform: translate3d(0,0,0)` hack | `will-change` (dynamic) | #89 |
| 10 | Clearfix hack | Flexbox/Grid implicit | — |
| 11 | Manual vendor-prefixes | Autoprefixer + Baseline 2024 | — |
| 12 | `@font-face` without font-display | + font-display: swap | #93 |
| 13 | Grid-system via float columns | CSS Grid with grid-template-columns | — |
| 14 | Icon Fonts | SVG sprites | — |
| 15 | `<table>` for layout | `<div>` + Grid | HTML5 |
| 16 | Hex colors everywhere | CSS Custom Properties / Tailwind config | #42 |
| 17 | Inline `style=` attributes | CSS classes | — |
| 18 | `onclick=` inline JS | Event-listeners | — |
| 19 | Separate weight-files | Variable Fonts | #57, #124 |
| 20 | `em`-based breakpoints missing | em-breakpoints for zoom-robust | — |

## Orchestration

### Step 1: Resolve Scope

All `*.css`, `*.scss`, `*.html`, `*.jsx`, `*.tsx`, `*.vue`, `*.svelte`.

### Step 2: Run Pattern Searches (Grep)

For each pattern, grep and aggregate occurrences.

Example:
```bash
grep -rE 'float:\s*(left|right)' --include='*.css' --include='*.scss' | wc -l
```

### Step 3: Dispatch to css-auditor for Deep Analysis

```
Task(
  subagent_type="css-auditor",
  prompt="Run in MODERNIZE mode. Focus on Rules 9, 14 plus these additional patterns: <legacy-list-above>. Write findings with auto_fixable classification."
)
```

(Alternative: implement directly in this skill since pattern-detection is deterministic.)

### Step 4: Present Report

```
## Modernization Opportunities

### High-Impact
- Float-based layouts found in 5 files → migrate to Grid (Matrix A: Grid better for 2D)
- 12 px-based font-sizes → change to rem (WCAG 1.4.4)

### Medium-Impact
- 23 JPEG images → consider AVIF/WebP picture-element

### Low-Impact
- 3 vendor-prefixes for properties with Baseline 2024 → remove manually

### Summary
  Legacy patterns: 43 found across 18 files
  Auto-fixable:    23 (via design-fixer --safe-only)
  Manual:          20 (structural changes)

### Next Steps
  Review report, then run design-fixer for auto-fixable.
```

## Verification

- Report written to `.design-forge/reports/modernize-<ts>.md`
- Each pattern has Matrix-A-reference if available
- Severity classified: high/medium/low
