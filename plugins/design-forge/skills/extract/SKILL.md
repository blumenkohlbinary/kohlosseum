---
name: extract
description: |
  Extract design tokens (colors, spacing, typography, shadows) from existing CSS/Tailwind/SCSS code and populate .design-forge/system.md tokens section. Use when user says: "extract design tokens", "extract from existing code", "learn my design system", "forge extract", "analyze my tokens", "extrahiere tokens", "lerne mein design system".
user-invocable: false
allowed-tools: Read, Grep, Glob, Write, Bash
model: sonnet
---

# Design-Forge Extract — Reverse-Engineer Design System

## Purpose

Scan existing code for repeated color/spacing/typography values, consolidate into tokens, populate `.design-forge/system.md`. Based on interface-design's `extract` pattern + frequency analysis.

## Trigger Conditions

Hidden skill. Claude invokes when user expresses intent:
- "extract tokens from my code"
- "learn existing design system"
- "forge extract"
- German: "extrahiere tokens", "design system analysieren"

## Orchestration

### Step 1: Verify Memory Exists

```bash
ls .design-forge/system.md 2>/dev/null
```

If missing: Prompt "No system.md found. Run init first? Or continue and create baseline?"

### Step 2: Scope Resolution

Default scope: all CSS/SCSS/Tailwind-config in project.

```bash
find . \( -name "*.css" -o -name "*.scss" -o -name "*.sass" -o -name "tailwind.config.*" \) -not -path "*/node_modules/*" -not -path "*/dist/*"
```

### Step 3: Extract Colors

Grep for hex/rgb/hsl/oklch:

```bash
grep -rhE '#[0-9a-fA-F]{3,8}|rgb\([^)]+\)|hsl\([^)]+\)|oklch\([^)]+\)' <files> | sort | uniq -c | sort -rn
```

Top-20 most-frequent are candidate tokens. Cluster similar hex values (distance ≤10 in RGB-space) — suggest canonical representative.

### Step 4: Extract Spacing

Grep for px-values in margin/padding/gap/top/left/right/bottom:

```bash
grep -rhE '(margin|padding|gap|top|left|right|bottom)\s*:\s*[0-9]+px' <files> | awk -F: '{print $2}' | grep -oE '[0-9]+px' | sort -n | uniq -c
```

Identify scale pattern (likely 4/8px-grid). Flag non-grid outliers for Review.

### Step 5: Extract Typography

- `font-family` usages → unique families
- `font-size` values → detect type-scale ratio
- `font-weight` variants
- `line-height` patterns

### Step 6: Extract Shadows

```bash
grep -rhE 'box-shadow\s*:[^;]+' <files> | sort | uniq -c | sort -rn
```

Top-5 unique shadows → elevation-levels.

### Step 7: Generate Tokens-Section

Build YAML fragment:

```yaml
tokens:
  primitives:
    colors:
      brand_primary: "#3b82f6"
      brand_secondary: "#10b981"
      neutral_50: "#f9fafb"
      # ... top-10 detected
    spacing: [4, 8, 12, 16, 24, 32, 48, 64]
    typography:
      font_families: ["Inter", "system-ui"]
      font_sizes: [12, 14, 16, 18, 20, 24, 32, 40]
      type_scale_ratio: 1.25  # detected
  semantic:
    # Suggestions only — user confirms
  component: {}
```

### Step 8: Present to User for Confirmation

```
Extracted tokens from N CSS files:

Colors (top 10):
  brand_primary:    #3b82f6  (23 uses)
  brand_secondary:  #10b981  (17 uses)
  ...

Spacing scale detected:  [4, 8, 12, 16, 24, 32, 48]
  off-grid values:       17px (3 uses), 22px (1 use) — flagged for manual review

Typography:
  families: Inter, system-ui
  sizes:    [12, 14, 16, 20, 24, 32, 40]
  ratio:    ~1.25 (Major Third)

Confirm before writing? [y/n/edit]
```

### Step 9: Merge into system.md

On confirm: read existing system.md, merge tokens section (not overwrite other sections), write back.

Add decision-log entry:
```yaml
- date: "<today>"
  what: "Extracted design tokens from codebase"
  why: "Baseline for future audit consistency"
  author: "<git user>"
```

## Verification

- system.md tokens section populated
- Schema still valid after merge
- Decision-log entry appended
- Off-grid values documented for user review
