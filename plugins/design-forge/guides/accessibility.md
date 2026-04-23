# Accessibility Guide für design-forge

**Quellen:** `Wissen/Accessibility & Usability für UIGUI Design-Plugins — Vollständige Referenz.md`
**Scope:** WCAG 2.2 AA + 9 neue Kriterien, Nielsen-Heuristiken, ARIA-Patterns, Keyboard-Navigation
**Verwendet von:** `a11y-auditor`, `interaction-auditor`, `color-auditor` (Kontrast-Delegation), `motion-auditor` (vestibular)

---

## 1. Quickstart: Die 10 kritischsten Regeln

| # | Regel | Schwellenwert | Quelle | Prüfer-Agent |
|---|-------|---------------|--------|--------------|
| 1 | Kontrast Normaltext | ≥4.5:1 | WCAG 2.2 SC 1.4.3 / Matrix A #1 | color-auditor |
| 2 | Kontrast Large-Text (≥18pt) | ≥3:1 | SC 1.4.3 / Matrix A #2 | color-auditor |
| 3 | Kontrast UI-Komponenten | ≥3:1 | SC 1.4.11 / Matrix A #3 | color-auditor |
| 4 | Focus-Visible-Style | ≥2px solid outline | SC 2.4.7+2.4.13 / Matrix A #4 | a11y-auditor |
| 5 | Touch-Target (AA) | ≥24×24 CSS px | NEU SC 2.5.8 / Matrix A #9 | layout-auditor |
| 6 | Tab-Order == DOM-Order | visuelle Reihenfolge | SC 2.4.3 / Matrix A #23 | a11y-auditor |
| 7 | Skip-Link als erstes Tab-Stop | — | SC 2.4.1 / Matrix A #15 | a11y-auditor |
| 8 | Alt-Text auf jedem `<img>` | präsent | SC 1.1.1 / Matrix A #27 | a11y-auditor |
| 9 | prefers-reduced-motion respektiert | Default reduziert | SC 2.3.3 / Matrix A #29 | motion-auditor |
| 10 | Heading-Hierarchie keine Sprünge | h1→h2→h3 | Best Practice / Matrix A #16 | a11y-auditor |

---

## 2. WCAG 2.2 Übersicht

- **4 Prinzipien:** Perceivable, Operable, Understandable, Robust (POUR)
- **3 Level:** A (Minimum) / AA (Rechtlicher Standard EU+USA) / AAA (Enhanced)
- **86 Success Criteria** gesamt, davon **9 neu in WCAG 2.2** (veröffentlicht Okt 2023)

### 2.1 Die 9 neuen WCAG-2.2-Kriterien

| SC | Name | Level | Matrix A | Prüfer |
|----|------|-------|----------|--------|
| 2.4.11 | Focus Not Obscured (Min) | AA | #11 | a11y-auditor |
| 2.4.12 | Focus Not Obscured (Enhanced) | AAA | #12 | a11y-auditor |
| 2.4.13 | Focus Appearance | AAA | #5 | a11y-auditor |
| 2.5.7 | Dragging Movements | AA | #17 | interaction-auditor |
| 2.5.8 | Target Size (Minimum) | AA | #9 | layout-auditor |
| 3.2.6 | Consistent Help | A | #20 | interaction-auditor |
| 3.3.7 | Redundant Entry | A | #19 | interaction-auditor |
| 3.3.8 | Accessible Auth (Minimum) | AA | #18 | interaction-auditor |
| 3.3.9 | Accessible Auth (Enhanced) | AAA | — | interaction-auditor |

---

## 3. Farbe & Kontrast

| Regel | Schwellenwert | Quelle | Prüfer-Agent |
|-------|---------------|--------|--------------|
| Normaltext-Kontrast | ≥4.5:1 | SC 1.4.3 / Matrix A #1 | color-auditor |
| Large-Text-Kontrast (≥18pt / ≥14pt bold) | ≥3:1 | SC 1.4.3 / Matrix A #2 | color-auditor |
| UI-Komponenten-Kontrast | ≥3:1 | SC 1.4.11 / Matrix A #3 | color-auditor |
| AAA-Text-Kontrast | ≥7:1 | SC 1.4.6 | color-auditor |
| Non-Color-Cue | Icon + Text + Farbe | SC 1.4.1 / Matrix A #30 | color-auditor + interaction-auditor |
| forced-colors Media-Query | @media (forced-colors: active) | Windows HCM / Matrix A #28 | css-auditor |

**Algorithmen (in `scripts/contrast.js`):**
- WCAG Luminanz: `L = 0.2126·R + 0.7152·G + 0.0722·B` nach Gamma-Dekompression (Matrix A #62)
- Kontrast-Ratio: `(L₁ + 0.05) / (L₂ + 0.05)` (Matrix A #63)
- APCA Lc für Dark Mode: Lc ≥75-90 (Matrix A #64)

---

## 4. Keyboard & Focus

| Regel | Schwellenwert | Quelle | Prüfer-Agent |
|-------|---------------|--------|--------------|
| Tab-Reihenfolge = DOM-Reihenfolge | keine tabindex>0 | SC 2.4.3 / Matrix A #23 | a11y-auditor |
| Focus-Visible-Style | outline ≥2px solid, offset ≥2px | SC 2.4.13 / Matrix A #4 | a11y-auditor |
| Focus-Kontrast | ≥3:1 fokussiert vs. unfokussiert | SC 2.4.13 / Matrix A #5 | color-auditor |
| Skip-Link-Position | erstes fokussierbares Element | SC 2.4.1 / Matrix A #15 | a11y-auditor |
| Modal Focus-Trap + Escape | implementiert | Pattern-Lib / Matrix A #144 | a11y-auditor + interaction-auditor |
| Roving Tabindex für Composite Widgets | Arrow-Key-Navigation | ARIA-Pattern / Matrix A #24 | a11y-auditor |
| Character-Key-Shortcuts | abschaltbar ODER focus-only | SC 2.1.4 / Matrix A #38 | a11y-auditor |
| sticky-header scroll-padding-top | berechnet | CSS / Matrix A #37 | css-auditor |

---

## 5. Screen Reader & Semantik

| Regel | Schwellenwert | Quelle | Prüfer-Agent |
|-------|---------------|--------|--------------|
| First Rule of ARIA | natives HTML > ARIA | WebAIM-Studie / Matrix A #21 | a11y-auditor |
| Accessible Name Reihenfolge | aria-labelledby > aria-label > native label > title > placeholder(WARN) | ACCNAME-AAM / Matrix A #22 | a11y-auditor |
| Landmark-Abdeckung | header, nav, main, aside, footer | HTML5 / Matrix A #26 | a11y-auditor |
| Heading-Hierarchie | 1× h1, keine Sprünge | Best Practice / Matrix A #16 | a11y-auditor |
| Alt-Text-Klassifikation | dekorativ="" / informativ kurz / komplex + aria-describedby | SC 1.1.1 / Matrix A #27 | a11y-auditor |
| Live Regions | role="status" (polite) vs role="alert" (assertive) | ARIA-Pattern / Matrix A #25 | a11y-auditor |
| Labels auf Form-Felder | präsent, verknüpft | SC 1.3.1+3.3.2 | a11y-auditor + interaction-auditor |
| Placeholder als Label | ❌ Anti-Pattern | SC 1.4.3 / Matrix A #22 | interaction-auditor |

**ARIA-Patterns:** Dialog, Combobox, Tabs, Menu, Disclosure, Alert/Alertdialog, Tree, Grid, Listbox.

---

## 6. Usability-Heuristiken & Gesetze

| Gesetz / Heuristik | Schwellenwert | Quelle | Prüfer-Agent |
|---------------------|---------------|--------|--------------|
| Nielsen's 10 Heuristiken | qualitativ | Matrix A #31 | interaction-auditor |
| Fitts's Law (Target-Size nach Distanz) | ≥24px AA / ≥44px AAA | Matrix A #32 | layout-auditor |
| Hick's Law (Top-Level-Options) | ≤7 | Matrix A #33 | interaction-auditor |
| Doherty Threshold (Response-Zeit) | <400ms | Matrix A #34 | performance-auditor |
| Jakob's Law (Standard-Patterns) | nicht willkürlich abweichen | Matrix A #35 | interaction-auditor |
| Gestalt: Proximity (Innen ≤ Außen) | Padding ≤ Margin | Matrix A #36 | layout-auditor |

---

## 7. Motion-Bezogene A11y

| Regel | Schwellenwert | Quelle | Prüfer-Agent |
|-------|---------------|--------|--------------|
| prefers-reduced-motion respektiert | Default reduziert, :no-preference erweitert | SC 2.3.3 / Matrix A #29 | motion-auditor |
| Flimmern | ≤3 Blitze/Sekunde | SC 2.3.1 / Matrix A #13 | motion-auditor |
| Autoplay >5s | Pause/Stop-Control erforderlich | SC 2.2.2 / Matrix A #14 | motion-auditor + interaction-auditor |

---

## 8. Text & Layout (Zoom, Reflow, Spacing)

| Regel | Schwellenwert | Quelle | Prüfer-Agent |
|-------|---------------|--------|--------------|
| Text Zoom bis 200% | ohne Layout-Loss | SC 1.4.4 / Matrix A #6 | typography-auditor |
| Reflow bei 320px | kein horizontal scroll | SC 1.4.10 / Matrix A #7 | layout-auditor |
| Text-Spacing Toleranz (user-override) | line 1.5×, letter 0.12em, word 0.16em, para 2× | SC 1.4.12 / Matrix A #8 | typography-auditor |
| iOS-Input font-size | ≥16px (Auto-Zoom-Prevention) | Best Practice / Matrix A #119 | typography-auditor |

---

## 9. Testing-Strategie

**Automatisiert (30-50% Coverage):**
- axe-core (via `Bash(axe:*)` in a11y-auditor)
- Pa11y CLI
- Lighthouse A11y-Audit
- Accessibility Insights for Web

**Manuell (50-70% Coverage):**
- Tab-Only Navigation Test (kein Maus-Zeiger)
- Screen Reader Test: NVDA (Windows), VoiceOver (macOS), TalkBack (Android)
- Graustufen-Test (Non-Color-Cue-Verification)
- 200% Zoom + 400% Zoom mit Reflow-Check
- Text-Spacing-Bookmarklet (W3C Toolbar)
- prefers-reduced-motion per OS-Setting testen

---

## 10. Leitprinzipien

1. **Natives HTML vor ARIA** — ARIA nur wenn nativ unmöglich (Matrix A #21)
2. **Jede Regel hat eine Zahl** — keine subjektiven Formulierungen in Audits
3. **Testing ist nicht optional** — 30-50% automatisiert genügt nicht für AA-Compliance
4. **Kontext zählt** — Brand-Ausnahmen erlaubt, aber dokumentiert im `.design-forge/system.md` Decision-Log
5. **A11y ist Usability für alle** — Keyboard-Navigation hilft nicht nur Blinden, sondern auch Power-Usern

---

## 11. Quellenverweise

- **Primär:** `Wissen/Accessibility & Usability für UIGUI Design-Plugins — Vollständige Referenz.md`
- **WCAG 2.2 Spec:** https://www.w3.org/TR/WCAG22/
- **ARIA Authoring Practices:** https://www.w3.org/WAI/ARIA/apg/
- **Regel-Index in design-forge:** Siehe Plan §15 Matrix A #1-39
