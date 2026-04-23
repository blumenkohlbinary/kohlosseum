# design-forge — Known Issues & Backlog

Warnings aus `plugin-dev` Validation (siehe Plan §16.4) und identifizierte M8+ Features.

---

## v1.0.0-rc Warnings (nicht-blockend)

### Skill-Reviewer-Style-Suggestions
- `/design-forge:audit` description 1024 Zeichen ausgeschöpft — ggf. nachschärfen wenn zusätzliche Trigger-Phrasen aufkommen.
- Hidden Skills (init/extract/status/doctor/fix/diff/modernize) teilen ähnliche Trigger-Vocabulary — minimal Overlap möglich.

### Agent-Development-Style
- Alle Auditoren-Prompts ~1500-2500 Tokens (Goldilocks-Zone 1200-2100 erfüllt, einige am oberen Rand)
- Few-Shot-Examples sind konsistent 3 pro Agent (Simple/Edge/Complex) — könnte bei Bedarf erweitert werden

### MCP-Fallbacks
- `visual-auditor` degradiert graceful bei fehlender Playwright MCP (single informational finding) — dokumentiert
- Kein HTTP-MCP-Fallback für axe-core — `a11y-auditor` nutzt nur Static-Analysis + `Bash(axe:*)` wenn installiert

### Guide-Cross-Reference
- Guides haben Matrix-A-Referenzen (Plan §15), aber keine direkten Backlinks zwischen Guides — M8+ Polish

---

## M8+ Feature-Backlog

### Aus Plan §13 "Nicht-Replizierte Items" (bewusst out-of-scope v1.0):
- **Figma-native Integration** (M8+ optional)
- **LSP-Server** für CSS-Intelligenz (M8+ möglich)
- **Docs-Generator** für Components (Storybook-Style)
- **Email-Template-Audit** (eigene Rendering-Engine-Domäne)

### Aus Matrix C (prompt-engineering refinements):
- **REMO Mistake-Notebook** (`.design-forge/errors.md`) für Confidence-Calibration (Matrix C #57)
- **Dynamic Few-Shot Selection** via Semantic-Similarity (Matrix C #59)
- **MINEA-Completeness-Baselines** für Test-Fixtures (Matrix C #69)

### Architektur-Erweiterungen:
- **PreToolUse-Hook** für echte Prävention (blockt Magic-Numbers VOR Schreiben)
- **Session-UUID-Tracking** (aus claudekit-Muster) für Context-Injection-Deduplication
- **Debounced Incremental Index** (statt Full-Rescan bei kleinen Änderungen)

### Tool-Erweiterungen:
- **scripts/oklch.js** — Palette-Generator + CVD-Simulation (Okabe-Ito-Snap)
- **scripts/python_lint.py** — Python-Desktop-spezifische Regex-Lints
- **axe-core HTTP-MCP-Wrapper** als optionaler Fallback
- **Stylelint-Integration** via `Bash(stylelint:*)` (Prompt-seitig bereits vorgesehen, Dokumentation fehlt)

### Testing/QA:
- Baseline-Test-Suite (50 Cases) + Adversarial-Suite (30 Cases) — aus Plan §14 (Matrix C #74)
- Robustness-Score-Automation (≥0.88 pro Release, Matrix C #77)

### Documentation:
- CONTRIBUTING.md
- Examples-Verzeichnis mit Before/After-Demos
- Video-Walkthrough für `/design-forge:audit` + fix-Workflow

---

## Report-Kanäle

Bugs + Feature-Requests:
- GitHub Issues: https://github.com/blumenkohlbinary/kohlosseum/issues
- Label-Convention: `design-forge:<category>` (audit/fixer/hook/guide/agent)
