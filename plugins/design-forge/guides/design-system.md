# Design System Guide für design-forge (Web)

**Quellen:** `Wissen/UIGUI Design System Architektur-Guide.md`
**Scope:** 3-Tier Token-Architektur, Material Design 3, Apple HIG, Tailwind v4, shadcn/ui, W3C DTCG
**Verwendet von:** `system-auditor`, `color-auditor` (Token-Referenzen), `css-auditor` (Cascade Layers)
**Python-Pendant:** Siehe `guides/design-system-python.md` für PyQt/Tkinter/CustomTkinter

---

## 1. Quickstart: Die 8 kritischsten Regeln

| # | Regel | Schwellenwert | Quelle | Prüfer-Agent |
|---|-------|---------------|--------|--------------|
| 1 | 3-Tier Architektur | Primitive → Semantic → Component | Matrix A #40 | system-auditor |
| 2 | Keine Hardcoded Hex | Tokens verwenden | Matrix A #42 | css-auditor + system-auditor |
| 3 | State-Varianten komplett | default/hover/active/focus/disabled | Matrix A #50 | system-auditor |
| 4 | Direct-Primitive-Access verboten | immer über Semantic | Matrix A #51 | system-auditor |
| 5 | Theme via Semantic-Layer | Light/Dark ändert nur Schicht 2 | Matrix A #52 | system-auditor |
| 6 | W3C DTCG JSON Export | stabil seit Okt 2025 | Matrix A #53, #172 | system-auditor |
| 7 | CSS Cascade Layers | @layer reset, tokens, base... | Matrix A #162 | css-auditor |
| 8 | Z-Index-Tokens | --z-base 0 → --z-toast 600 | Matrix A #163 | system-auditor |

---

## 2. 3-Tier Token-Architektur

### 2.1 Schicht 1: Primitives (Option Tokens)

Rohe Farben, Abstände — keine semantische Bedeutung.

```css
:root {
  /* Colors — Primitives */
  --blue-50:  #eff6ff;
  --blue-500: #3b82f6;
  --blue-900: #1e3a8a;

  /* Neutrals */
  --neutral-0:   #ffffff;
  --neutral-50:  #f9fafb;
  --neutral-500: #6b7280;
  --neutral-900: #111827;

  /* Spacing */
  --size-1: 4px;
  --size-2: 8px;
  --size-3: 12px;
  --size-4: 16px;
}
```

### 2.2 Schicht 2: Semantic (Decision Tokens)

Rollen, austauschbar pro Theme.

```css
:root {
  --color-action-primary:         var(--blue-500);
  --color-action-primary-hover:   var(--blue-700);
  --color-action-primary-active:  var(--blue-800);
  --color-action-primary-disabled:var(--neutral-300);

  --color-text-primary:   var(--neutral-900);
  --color-text-secondary: var(--neutral-500);
  --color-text-muted:     var(--neutral-400);

  --color-bg-surface:     var(--neutral-0);
  --color-bg-subtle:      var(--neutral-50);

  --space-gutter:  var(--size-4);
  --space-section: calc(var(--size-4) * 4);
}
```

### 2.3 Schicht 3: Component (Component Tokens)

Komponenten-spezifisch, referenziert NUR Semantic.

```css
.button-primary {
  --btn-bg:     var(--color-action-primary);
  --btn-text:   var(--color-text-inverse);
  --btn-padding:var(--space-gutter);

  background: var(--btn-bg);
  color:      var(--btn-text);
  padding:    var(--btn-padding);
}
```

**REGEL:** Schicht 3 referenziert NUR Schicht 2. Niemals direkt auf Primitives zugreifen.

---

## 3. Naming Convention

**Python (snake_case):**
```
category_role_property_state
color_action_primary_hover
spacing_section_mobile
```

**Web (kebab-case):**
```
--color-action-primary-hover
--space-section-mobile
```

**REGEL:** Keine visuellen Eigenschaften im Namen (`--space-md` statt `--space-16px`). Size-Änderungen brechen dann nicht die API.

---

## 4. W3C DTCG JSON (Token Interchange Standard)

Seit Oktober 2025 stabil. Export-Standard für multi-platform.

```json
{
  "color": {
    "action": {
      "primary": {
        "$value": "{color.blue.500}",
        "$type": "color"
      }
    }
  },
  "spacing": {
    "gutter": {
      "$value": "16px",
      "$type": "dimension"
    }
  }
}
```

Tools: **Style Dictionary v4**, **Tokens Studio** (Figma-Plugin).

Quelle: Matrix A #53, #172

---

## 5. Tailwind v4 `@theme` Direktive

Pure CSS Config, keine JS-Build nötig.

```css
@import "tailwindcss";

@theme {
  --color-brand-action: oklch(55% 0.15 250);
  --spacing-gutter: 16px;
  --breakpoint-tablet: 48em;
}
```

Quelle: Matrix A #164

---

## 6. Vergleich der 6 großen Design-Systeme

| System | Color-Space | Token-Layers | Besonderheit |
|--------|-------------|--------------|--------------|
| Material Design 3 | HCT | 3 (Ref/Sys/Comp) | Tonale Paletten 0-100, Dynamic-Color |
| Apple HIG | sRGB + P3 | 2 (System/Semantic) | SF Symbols, Vibrancy, Liquid Glass (2025) |
| Fluent 2 | sRGB + OKLCH | 3 (Global/Alias/Control) | Reveal, Acrylic |
| Ant Design | HSB + Bézier | 2 (Palette/Token) | Bézier-Interpolation für Paletten |
| shadcn/ui | HSL via CSS vars | 2 (Config/Semantic) | Radix-basiert, cn()+twMerge |
| Chakra UI v3 | CSS-in-JS | 3 (Style-Props) | Recipes, Tokens API |

Quelle: Matrix A §2 in `UIGUI Design System Architektur-Guide.md`

---

## 7. CSS Cascade Layers (Strict Ordering)

Eliminiert Specificity-Wars.

```css
@layer reset, tokens, base, layouts, components, utilities, overrides;

@layer reset { * { box-sizing: border-box; } }
@layer tokens { :root { --color-primary: ...; } }
@layer base { html, body { ... } }
@layer components { .btn { ... } }
@layer utilities { .mt-4 { margin-top: 16px; } }
```

Quelle: Matrix A #162

---

## 8. Z-Index-Tokens

```css
:root {
  --z-base:     0;
  --z-dropdown: 100;
  --z-sticky:   200;
  --z-overlay:  300;
  --z-modal:    400;
  --z-popover:  500;
  --z-toast:    600;
}
```

**REGEL:** Keine nackten z-index-Zahlen außerhalb dieser Tokens.

Quelle: Matrix A #163

---

## 9. Elevation-System (5-Level)

```css
:root {
  --elevation-0: none;
  --elevation-1: 0 1px 2px rgba(0,0,0,.05);
  --elevation-2: 0 2px 6px rgba(0,0,0,.08);
  --elevation-3: 0 4px 12px rgba(0,0,0,.10);
  --elevation-4: 0 8px 24px rgba(0,0,0,.12);
  --elevation-5: 0 16px 48px rgba(0,0,0,.15);
}
```

Quelle: Matrix A #43

---

## 10. State-Varianten (Pflicht für Interaktiv-Komponenten)

Jede interaktive Komponente MUSS 5 States definieren:

```css
.btn                  { ... }          /* default */
.btn:hover            { ... }
.btn:active           { ... }
.btn:focus-visible    { outline: 2px solid var(--color-focus); }
.btn:disabled, .btn[aria-disabled="true"] { opacity: .5; cursor: not-allowed; }
```

Quelle: Matrix A #50

---

## 11. Trends 2024-2026

| Trend | Adoption-Empfehlung |
|-------|---------------------|
| **Bento Grid** | ✅ Dashboard-Layouts (A11y-Reihenfolge prüfen!) |
| **Glassmorphism 2.0** (backdrop-filter 92%+) | ✅ Subtil, mit Text-Kontrast-Check |
| **Apple Liquid Glass** (iOS 27+) | ⏳ Abwarten, Web-Implementierung unklar |
| **Variable Fonts** (Inter, Recursive) | ✅ Sofort — 43KB ersetzt 4× 80KB |
| **AI-native Patterns** (cmdk, Vercel AI SDK) | ⚠️ Fallback-Patterns für Non-AI-User |
| **Spatial Design** (visionOS → 2D-Einfluss) | ❌ Zu früh, nur Inspiration |
| **Brutalism / Neobrutalism** | ⚠️ A11y-kritisch, nur mit Care |

---

## 12. Component API Design

**Pattern:**
```tsx
<Button variant="primary" size="md" loading={false}>
  Submit
</Button>
```

**Props-Konvention:**
- `variant`: visuelle Varianten (primary/secondary/ghost)
- `size`: dimensionale Varianten (sm/md/lg)
- `loading`, `disabled`: Zustände
- `as` / `asChild`: Polymorphismus (Radix-Pattern)

---

## 13. Linting & Audits

Diese Guide-Regeln werden durchgesetzt von:
- `system-auditor` — Token-Compliance, State-Coverage
- `css-auditor` — Cascade Layers, Magic Numbers, Tailwind arbitrary values
- `color-auditor` — Hardcoded hex detection, contrast

---

## 14. Leitprinzipien

1. **3 Tiers sind Pflicht** — Kein direkter Primitive-Access
2. **Tokens statt Werte** — Alles ist ein Token
3. **State-Coverage vollständig** — 5 States pro interaktiver Komponente
4. **Semantic-only Theming** — Light/Dark nur auf Schicht 2
5. **W3C DTCG als Export-Standard** — Interop zählt

---

## 15. Quellenverweise

- **Primär:** `Wissen/UIGUI Design System Architektur-Guide.md`
- **W3C DTCG Spec:** https://www.designtokens.org/
- **Material Design 3:** https://m3.material.io/
- **Tailwind v4 Docs:** https://tailwindcss.com/docs
- **Regel-Index:** Plan §15 Matrix A #40-61, #161-172
