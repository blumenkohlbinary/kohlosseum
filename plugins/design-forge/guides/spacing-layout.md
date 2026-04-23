# Spacing & Layout Guide für design-forge

**Quellen:** `Wissen/Spacing, Grids und Layout — Das Nachschlagewerk für UI-Entwickler.md`
**Scope:** 8px-Grid, Container Queries, Touch-Targets, Baseline-Grid, F/Z-Patterns
**Verwendet von:** `layout-auditor`, `system-auditor`, `visual-auditor`, `a11y-auditor` (Touch-Targets)

---

## 1. Quickstart: Die 8 kritischsten Regeln

| # | Regel | Schwellenwert | Quelle | Prüfer-Agent |
|---|-------|---------------|--------|--------------|
| 1 | Spacing-Grid | [4, 8, 12, 16, 24, 32, 48, 64] | Matrix A #41, #98 | layout-auditor |
| 2 | Touch-Target AA | ≥24×24 CSS px | WCAG 2.2 SC 2.5.8 / Matrix A #9 | layout-auditor |
| 3 | Touch-Target AAA | ≥44×44 CSS px | Matrix A #10 | layout-auditor |
| 4 | Container-Max-Width-Progression | [540, 720, 960, 1140, 1320] | Bootstrap / Matrix A #99 | layout-auditor |
| 5 | Gutter | 16/24/32 (Mobile/Tablet/Desktop) | Matrix A #100 | layout-auditor |
| 6 | Proximity (Innen ≤ Außen) | Padding ≤ Margin | Gestalt / Matrix A #101 | layout-auditor |
| 7 | Container Queries statt Media | @container für Komponenten | 97% Support 2024 / Matrix A #102 | layout-auditor |
| 8 | aspect-ratio Property | statt padding-top-Hack | Matrix A #103 | css-auditor |

---

## 2. Das 8px-Grid-System

### 2.1 Warum 8px?

- **Subpixel-robust:** 8px skaliert sauber auf 1.5× (12px), 2× (16px), 3× (24px)
- **rem-Mapping:** 8px = 0.5rem (bei root-font-size 16px)
- **Industrie-Standard:** Material Design, Carbon, Apple HIG, Tailwind, Bootstrap

### 2.2 Spacing-Scale

```
[4, 8, 12, 16, 24, 32, 48, 64, 96, 128] px
```

**Nicht-lineare Progression (Weber-Fechner):** Wahrgenommene Differenz proportional zur Größe.

**Als CSS Custom Properties:**
```css
:root {
  --space-xs:  4px;
  --space-sm:  8px;
  --space-md: 16px;
  --space-lg: 24px;
  --space-xl: 32px;
  --space-2xl: 48px;
  --space-3xl: 64px;
}
```

### 2.3 Half-Steps (4px)

4px dient als Halbschritt für feine Anpassungen (Icons, kleinste Abstände).

---

## 3. Grid-Systeme

### 3.1 12-Spalten (Standard)

Klassisch von Bootstrap/Foundation, flexibel teilbar in 2/3/4/6.

### 3.2 CSS Grid vs. Flexbox — Entscheidungsmatrix

| Kriterium | CSS Grid | Flexbox |
|-----------|----------|---------|
| 2D Layout | ✅ | ❌ |
| 1D Layout | ⚠️ | ✅ |
| Named Grid Areas | ✅ | ❌ |
| Gap Support | ✅ | ✅ (seit 2021) |
| Subgrid | ✅ | ❌ |
| Dynamische Inhaltsgrößen | ⚠️ | ✅ |

### 3.3 Container Queries (97% Support seit 2024)

**Statt Media Queries für Komponenten:**
```css
.card-container {
  container-type: inline-size;
}
@container (min-width: 400px) {
  .card { grid-template-columns: 1fr 1fr; }
}
```

Quelle: Matrix A #102

---

## 4. Responsive Breakpoints

| Gerät | Breakpoint | Tailwind-Name |
|-------|-----------|---------------|
| Mobile | — | default |
| Mobile Large | 640px | `sm:` |
| Tablet | 768px | `md:` |
| Laptop | 1024px | `lg:` |
| Desktop | 1280px | `xl:` |
| Large Desktop | 1536px | `2xl:` |

**Em-basiert** für Zoom-Robustheit:
```css
@media (min-width: 48em) { /* 768px bei 16px root */ }
```

---

## 5. Container-Max-Width

**Progressiv:**
```
540 → 720 → 960 → 1140 → 1320 px
```
Quelle: Matrix A #99

**Als CSS:**
```css
.container {
  max-width: clamp(540px, 100%, 1320px);
  margin-inline: auto;
  padding-inline: var(--gutter);
}
```

---

## 6. Whitespace (Gestalt-Principien)

### 6.1 Proximity-Regel (Matrix A #101)

**Innen ≤ Außen:** Padding innerhalb einer Komponente muss KLEINER sein als Margin zwischen Komponenten.

```css
.card { padding: 16px; }              /* Innen */
.card + .card { margin-top: 32px; }  /* Außen, größer */
```

Inverse = Ambiguous Grouping.

### 6.2 Micro- vs. Macro-Whitespace

| Typ | Zweck | Werte |
|-----|-------|-------|
| Micro | Lesbarkeit innerhalb (line-height, letter-spacing) | Typografisch |
| Macro | Struktur (Abstände zwischen Sektionen) | 32-96px |

---

## 7. Touch-Targets (WCAG 2.2 SC 2.5.8)

| Level | Min-Size | Quelle |
|-------|----------|--------|
| AA | ≥24×24 CSS px | NEU WCAG 2.2 SC 2.5.8 / Matrix A #9 |
| AAA | ≥44×44 CSS px | SC 2.5.5 / Matrix A #10 |

**Fitts-Law Error-Rate:**
- 44×44: 3% Fehlklicks
- 24×24: 15% Fehlklicks
- 16×16: >40% Fehlklicks

**Implementation mit Padding-Expansion:**
```css
.icon-btn {
  width: 20px;  /* visuell */
  padding: 12px; /* unsichtbar, expandiert Tap-Area auf 44×44 */
}
```

---

## 8. Layout-Patterns

### 8.1 Holy Grail (moderner Weg)

```css
.layout {
  display: grid;
  grid-template-areas:
    "header header header"
    "nav    main    aside"
    "footer footer footer";
  grid-template-columns: 200px 1fr 150px;
  grid-template-rows: auto 1fr auto;
  min-height: 100vh;
}
```

### 8.2 RAM-Pattern (Responsive Auto-Fit)

```css
.cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: var(--space-lg);
}
```

Quelle: Matrix A #108

### 8.3 F-Pattern (Text-Scan)

Für text-lastige Seiten (Blog, Docs):
- Headline oben
- Links-ausgerichtete Sub-Headlines
- Dichter Text vertikal

### 8.4 Z-Pattern (Landing Pages)

CTAs folgen dem Blickverlauf:
- Oben-links: Brand
- Oben-rechts: Login/CTA
- Mitte: Headline
- Unten-rechts: Primary-CTA

### 8.5 Bento-Grid (2024-Trend)

Variable Card-Größen mit `grid-template-areas` oder `grid-auto-flow: dense`.

**Wichtig:** Screen-Reader-Reihenfolge gegen visual order prüfen (Matrix A #58).

---

## 9. Optical Alignment

Mathematisches Zentrieren sieht bei Icons/Text oft falsch aus.

| Element | Korrektur |
|---------|-----------|
| Play-Icon in Kreis | `translateX(2px)` — nach rechts schieben |
| Button-Text | `padding-bottom: calc(X - 1px)` |
| Circular Avatar + Text | Text slight größer (Kreis optisch kleiner als Quadrat) |

Quelle: Matrix A #107

---

## 10. Baseline-Grid (Typografie-Rhythmus)

Wenn `line-height: 1.5rem` = 24px → alle vertikalen Margins/Paddings in Vielfachen von 24px.

```css
.prose { line-height: 1.5rem; }
.prose h1 { margin-block: 48px; } /* 24 × 2 */
.prose p  { margin-block: 24px; } /* 24 × 1 */
```

Quelle: Matrix A #106

---

## 11. Density-Levels

Via `data-density`-Attribut + CSS Custom Properties:

```css
[data-density="compact"]     { --space-unit: 6px; }
[data-density="comfortable"] { --space-unit: 8px; }
[data-density="spacious"]    { --space-unit: 12px; }
```

---

## 12. Leitprinzipien

1. **Alles auf 4/8px-Grid** — Ausnahmen im Decision-Log dokumentiert
2. **Container Queries für Komponenten** — Media Queries nur für Page-Level-Breakpoints
3. **Touch-Targets ≥24px** — Ausnahmslos
4. **Gestalt vor Ästhetik** — Proximity/Similarity/Closure
5. **Em-basierte Breakpoints** — Respektiert User-Zoom

---

## 13. Quellenverweise

- **Primär:** `Wissen/Spacing, Grids und Layout — Das Nachschlagewerk für UI-Entwickler.md`
- **WCAG 2.2 SC 2.5.8:** https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
- **Container Queries:** https://caniuse.com/css-container-queries
- **Regel-Index:** Plan §15 Matrix A #98-109
