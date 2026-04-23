# Typography Guide für design-forge

**Quellen:** `Wissen/Typografie im Software- und UI-Design — Vollständiges Nachschlagewerk.md`
**Scope:** Type Scales, Line-Height, Measure, Letter-Spacing, Font-Pairing, Variable Fonts, iOS-Input
**Verwendet von:** `typography-auditor`, `a11y-auditor` (Readability-Delegation)

---

## 1. Quickstart: Die 10 kritischsten Regeln

| # | Regel | Schwellenwert | Quelle | Prüfer-Agent |
|---|-------|---------------|--------|--------------|
| 1 | Type-Scale-Ratio SaaS | 1.2–1.25 | Matrix A #110 | typography-auditor |
| 2 | Type-Scale-Ratio Marketing | 1.5–1.618 | Matrix A #110 | typography-auditor |
| 3 | Line-Height Body | 1.5–1.7 unitless | M3 / Matrix A #111 | typography-auditor |
| 4 | Line-Height Headlines | 1.0–1.15 (bei ≥40px) | M3 / Matrix A #112 | typography-auditor |
| 5 | Measure (CPL) | 45–75ch (ideal 66) | Bringhurst / Matrix A #113 | typography-auditor |
| 6 | iOS-Input font-size | ≥16px | Matrix A #119 | typography-auditor |
| 7 | Max 2 Fonts (+Mono optional) | Pairing | Matrix A #120 | typography-auditor |
| 8 | Max 3–4 Weights | 400/500/600/700 | Matrix A #117 | typography-auditor |
| 9 | font-size in rem/em | nicht px | WCAG 1.4.4 | typography-auditor |
| 10 | Variable Font statt mehrerer Weights | Inter 43KB ersetzt 4× 80KB | Matrix A #124 | typography-auditor |

---

## 2. Type Scales

Modular Scale Ratios:

| Name | Ratio | Use-Case |
|------|-------|----------|
| Minor Second | 1.067 | Sehr kompakt (Dashboards) |
| Major Second | 1.125 | Kompakt |
| **Minor Third** | **1.2** | **Dashboards, Admin** |
| **Major Third** | **1.25** | **SaaS, Apps** |
| Perfect Fourth | 1.333 | Content-Sites |
| Augmented Fourth | 1.414 | Editorial |
| Perfect Fifth | 1.5 | Marketing |
| Golden Ratio | 1.618 | Hero-Pages, Dramatic |

**Python Formel:**
```
size_n = base_size × ratio^n
# z.B. base=16, ratio=1.25:
# H1 = 16 × 1.25^4 = 39.06 ≈ 40px
# H2 = 16 × 1.25^3 = 31.25 ≈ 32px
```

**Utopia.fyi Dual-Scale:** Unterschiedliche Ratio bei min/max Viewport für divergierende Headlines.

---

## 3. Praktische Pixel-Werte

### 3.1 Major Third (1.25) — Empfohlen für SaaS

| Rolle | Size | px |
|-------|------|-----|
| Display | 48 | 48 |
| H1 | 40 | 40 |
| H2 | 32 | 32 |
| H3 | 24 | 24 |
| H4 | 20 | 20 |
| Body Large | 18 | 18 |
| Body | 16 | 16 |
| Small | 14 | 14 |
| Caption | 12 | 12 |

### 3.2 Fluid Typography (clamp)

```css
h1 {
  font-size: clamp(2rem, 1rem + 3vw, 3.5rem);
}
```

Utopia.fyi Formel:
```
slope = (max - min) / (max-viewport - min-viewport)
intercept = min - slope × min-viewport
clamp(min, intercept + slope × 100vw, max)
```

---

## 4. Line-Height

### 4.1 Unitless ist Pflicht

```css
/* ❌ */
.prose { font-size: 16px; line-height: 24px; }
.child { font-size: 32px; /* erbt 24px absolut — Kollision! */ }

/* ✅ */
.prose { font-size: 16px; line-height: 1.5; }
.child { font-size: 32px; /* erbt 1.5, berechnet 48px */ }
```

### 4.2 Werte nach Rolle

| Kontext | Line-Height | Quelle |
|---------|-------------|--------|
| Body | 1.5–1.7 | Matrix A #111 |
| Long-Form Prose | 1.625 | Matrix A #111 |
| Headlines ≥40px | 1.0–1.15 | Matrix A #112 |
| Code | 1.4–1.6 | Industrie-Standard |

---

## 5. Measure (Characters Per Line)

| Wert | Use-Case |
|------|----------|
| 45ch | Mobile Minimum |
| **66ch** | **Optimal (Bringhurst)** |
| 75ch | Desktop Maximum |
| >80ch | ❌ Zu breit, Lesefluss gestört |

```css
.prose { max-width: 65ch; }
```

---

## 6. Letter-Spacing

| Kontext | Tracking | Grund |
|---------|----------|-------|
| Body | 0 | Fonts sind optimiert |
| ALL-CAPS | +0.05 bis +0.1em | Butterick-Regel |
| Headlines >40px | -0.01 bis -0.03em | Optisches Driften korrigieren |
| Monospace | 0 | Feste Breite |

---

## 7. Font-Pairing

### 7.1 Pairing-Strategien

**Kontrast (95% Standard):**
- Serif-Display + Sans-Body: Playfair Display + Source Sans 3
- Slab-Display + Sans-Body: Archivo + Inter

**Harmonie (Superfamily):**
- Inter 400/700 + Georgia (System-Serif = 0 KB)
- Recursive Sans + Recursive Mono

### 7.2 Regeln

- Max 2 Fonts (+Mono optional)
- Max 3–4 Weights je Font
- Inter Variable (43KB) ersetzt 4× Fixed-Weight (320KB)

### 7.3 System Font Stacks (0 KB)

```css
:root {
  --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, system-ui, sans-serif;
  --font-serif: Georgia, "Times New Roman", serif;
  --font-mono: ui-monospace, "SF Mono", Consolas, monospace;
}
```

---

## 8. Variable Fonts

### 8.1 Vorteile

- Single-File ersetzt 4+ separate Files
- Optical Sizing: Schrift passt sich automatisch an Größe an (opsz-Achse)
- Feinkörnige Weight-Kontrolle (400.5, 425, 600.25 möglich)

### 8.2 Beispiel Inter

```css
@font-face {
  font-family: 'Inter';
  src: url('/fonts/InterVariable.woff2') format('woff2-variations');
  font-weight: 100 900;
  font-display: swap;
}

:root {
  --font-body: 'Inter', system-ui, sans-serif;
}
```

---

## 9. iOS Auto-Zoom Prevention

```css
/* ❌ */
input { font-size: 14px; }  /* iOS zoomt auf focus */

/* ✅ */
input { font-size: max(16px, 1rem); }
```

Quelle: Matrix A #119

---

## 10. OpenType Features

```css
.prose {
  font-feature-settings:
    "onum" 1,   /* Old-Style Numerals im Body */
    "liga" 1,   /* Ligaturen */
    "kern" 1;   /* Kerning */
}

.tabular {
  font-feature-settings: "tnum" 1;  /* Tabular Numerals für Tabellen */
}
```

---

## 11. Leitprinzipien

1. **Unitless line-height** — erbt korrekt durch Kaskade
2. **rem/em statt px** — respektiert User-Zoom
3. **Measure ≤75ch** — sonst zerfällt Lesbarkeit
4. **Max 2 Fonts** — Pairing nach Kontrast ODER Harmonie
5. **Variable Fonts Default** — außer Browser-Support kritisch

---

## 12. Quellenverweise

- **Primär:** `Wissen/Typografie im Software- und UI-Design — Vollständiges Nachschlagewerk.md`
- **Utopia:** https://utopia.fyi/
- **Google Fonts:** https://fonts.google.com/
- **Variable Fonts:** https://v-fonts.com/
- **Regel-Index:** Plan §15 Matrix A #110-125
