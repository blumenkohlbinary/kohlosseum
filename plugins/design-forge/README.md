# design-forge

**Production-grade UI/design audit + auto-fix engine for Claude Code.**

Dispatches 10 specialist auditors in parallel, synthesizes findings via Opus-Critic, and applies fixes with risk-phased Git checkpoints.

## Features

- **10 Specialist Auditors** (all Sonnet 4.6):
  - `css-auditor` — Stylelint-style deterministic CSS quality
  - `a11y-auditor` — WCAG 2.2 AA complete (incl. 9 new 2.2 criteria)
  - `color-auditor` — WCAG Luminance + APCA + OKLCH + CVD + Dark Mode
  - `typography-auditor` — Type-Scale, Measure, Line-Height, Variable Fonts
  - `layout-auditor` — 8px-Grid, Breakpoints, Container Queries, Touch-Targets
  - `system-auditor` — Design-Token compliance, Pattern-Drift vs `.design-forge/system.md`
  - `performance-auditor` — Core Web Vitals, Critical CSS, content-visibility
  - `motion-auditor` — Timing, Easing, `prefers-reduced-motion`, FLIP/Spring
  - `interaction-auditor` — Nielsen Heuristics, UI-Patterns, Form-UX, Anti-Patterns
  - `visual-auditor` — Playwright Multi-Viewport, Screenshots, Visual Regression

- **Opus Synthesizer** — `design-critic` consolidates, dedupes, calibrates confidence
- **Auto-Fix-Engine** — `design-fixer` with Safe/Medium/Risky phases, Git stash checkpoints
- **Memory-Driven Consistency** — `.design-forge/system.md` with decision log + tokens
- **Incremental Diff** — only audit files changed since last git ref
- **Cross-Platform Screenshots** — Playwright works on Windows/Linux/macOS

## Commands

| Command | Purpose |
|---------|---------|
| `/forge:audit` | Full multi-specialist audit |
| `/forge:fix` | Apply auto-fixes with risk phasing |
| `/forge:a11y` | A11y-focused shortcut |
| `/forge:colors` | Color/Contrast/OKLCH shortcut |
| `/forge:init` | Interactive Intent-Dialog + create `system.md` |
| `/forge:extract` | Extract design tokens from existing code |
| `/forge:diff` | Incremental audit since git ref |
| `/forge:modernize` | Detect legacy CSS patterns |
| `/forge:status` | Show memory + last audit state |
| `/forge:doctor` | Plugin health check |

## Installation

```bash
# Via Kohlosseum marketplace
/plugin marketplace add blumenkohlbinary/kohlosseum
/plugin install design-forge@kohlosseum
```

## Requirements

- Claude Code 2.1.10+
- Node.js 20.18.3+ (for native scripts)
- Optional: Playwright MCP (for `visual-auditor`)
- Optional: Stylelint installed globally (for `css-auditor` extended checks)

## Documentation

Guides in `guides/` cover all prüfbare rules with WCAG/source references:
- `accessibility.md` — WCAG 2.2 AA + ARIA + Keyboard
- `colors.md` — OKLCH, APCA, CVD, Dark Mode
- `typography.md` — Type Scales, Measure, Variable Fonts
- `spacing-layout.md` — 8px-Grid, Container Queries, Touch Targets
- `design-system.md` — 3-Tier Tokens (Web)
- `design-system-python.md` — PyQt/Tkinter adaptation
- `motion.md` — Timing, Easing, reduced-motion
- `performance.md` — CWV, Critical CSS
- `ui-patterns.md` — Navigation, Forms, Modals
- `usability.md` — Nielsen Heuristics, Fitts/Hick

## License

MIT
