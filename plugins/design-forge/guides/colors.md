# Colors Guide für design-forge

**Quellen:** `Wissen/Farbe im UI-Design — Vollständiges Nachschlagewerk.md`
**Scope:** WCAG Luminanz + APCA, OKLCH, Okabe-Ito CVD-Paletten, Dark Mode, Halation
**Verwendet von:** `color-auditor`, `a11y-auditor` (Kontrast-Delegation), `system-auditor` (Token-Referenzen)

---

## 1. Quickstart: Die 7 kritischsten Regeln

| # | Regel | Schwellenwert | Quelle | Prüfer-Agent |
|---|-------|---------------|--------|--------------|
| 1 | Body-Text-Kontrast | ≥4.5:1 | WCAG SC 1.4.3 / Matrix A #1 | color-auditor |
| 2 | Large-Text-Kontrast (≥18pt) | ≥3:1 | SC 1.4.3 / Matrix A #2 | color-auditor |
| 3 | UI-Component-Kontrast | ≥3:1 | SC 1.4.11 / Matrix A #3 | color-auditor |
| 4 | Dark-Mode-Text statt #FFFFFF | #E0E0E0 | Halation / Matrix A #71 | color-auditor |
| 5 | Dark-Mode-BG statt #000000 | #121212 oder M3 Tone 6 | Matrix A #70 | color-auditor |
| 6 | CVD-sichere Palette (kein Rot↔Grün) | Okabe-Ito | Matrix A #66-68 | color-auditor |
| 7 | Nicht-Invertiert Dark Mode | Light Tone 40 → Dark Tone 80 | M3 / Matrix A #73 | color-auditor |

---

## 2. WCAG-Kontrast-Formeln

### 2.1 Relative Luminanz

```
Für jeden Kanal R, G, B (0-1):
  R_lin = R ≤ 0.03928 ? R/12.92 : ((R+0.055)/1.055)^2.4
  G_lin = G ≤ 0.03928 ? G/12.92 : ((G+0.055)/1.055)^2.4
  B_lin = B ≤ 0.03928 ? B/12.92 : ((B+0.055)/1.055)^2.4

L = 0.2126 × R_lin + 0.7152 × G_lin + 0.0722 × B_lin
```
Quelle: Matrix A #62

### 2.2 Contrast-Ratio

```
ratio = (L_heller + 0.05) / (L_dunkler + 0.05)
```
Quelle: Matrix A #63

### 2.3 WCAG-Schwellenwerte

| Textklasse | AA | AAA |
|-----------|-----|-----|
| Normal body text (<18pt / <14pt bold) | ≥4.5:1 | ≥7:1 |
| Large text (≥18pt / ≥14pt bold) | ≥3:1 | ≥4.5:1 |
| UI-Komponenten (Borders, Icons) | ≥3:1 | — |
| Focus-Ring (vs. Component-BG) | ≥3:1 | ≥3:1 |

---

## 3. APCA (WCAG 3.0 Candidate)

APCA (Accessible Perceptual Contrast Algorithm) ist der 2025-Kandidat für WCAG 3.0, besonders relevant für Dark Mode.

| Zielwert | Kontext |
|----------|---------|
| Lc ≥75 | Fließtext Body |
| Lc ≥90 | Maximum (sonst Halation) |
| Lc ≥60 | Secondary-Text |

**Vorteil über WCAG 2.x:** Berücksichtigt Font-Weight, Polarität, visuelle Masse.

Quelle: Matrix A #64

---

## 4. OKLCH — Der empfohlene Farbraum

OKLCH ist 2025-Standard für Palette-Generierung.

**Vorteile über HSL:**
- Perzeptuell uniform (gleicher L-Wert = gleiche wahrgenommene Helligkeit)
- Predictable Lightness-Delta zwischen Palette-Stufen
- Korreliert mit WCAG-Luminanz

**Palette-Regeln:**
- Adjacent Steps: OKLCH L-Delta ≥5-8% (Matrix A #69)
- Material Design 3 HCT: Tone-Δ ≥40 = 3:1 contrast, Δ ≥50 = 4.5:1 (Matrix A #61)

```css
/* OKLCH Palette example */
--primary-50:  oklch(96% 0.02 250);
--primary-100: oklch(90% 0.05 250);
--primary-500: oklch(55% 0.15 250);
--primary-900: oklch(20% 0.10 250);
```

---

## 5. Dark Mode — Nicht Invertieren

| Regel | Schwellenwert | Quelle |
|-------|---------------|--------|
| Dark BG | #121212 (Material) oder M3 Tone 6+ | Matrix A #70 |
| Dark Text | #E0E0E0 (87% opacity) statt #FFFFFF | Matrix A #71, #72 |
| Tone-Mapping | Light Tone 40 → Dark Tone 80 | M3 / Matrix A #73 |
| Elevation Overlays | +5% Aufhellung pro Level | Matrix A #74 |
| Semantic Overrides only | Light/Dark ändert nur Semantic-Layer | Matrix A #52 |

**Halation-Ursache:** 47% der Bevölkerung hat Astigmatismus — pures Weiß auf Schwarz erzeugt visuelle "Halos" durch Iris-Öffnung.

---

## 6. Farbenblindheit (CVD)

**Verteilung (biologisch-männlich):**
- Deuteranopie (Grün-schwach): ~6%
- Protanopie (Rot-schwach): ~2%
- Tritanopie (Blau-schwach): <0.01%
- **Gesamt: ~8% Männer, ~0.5% Frauen**

**Unsichere Farbpaare:**
- ❌ Rot + Grün (Deuteranopie/Protanopie)
- ❌ Blau + Violett (Tritanopie)
- ❌ Braun + Grün

**Universell sichere Combo:**
- ✅ **Blau + Orange** (IBM/Okabe-Ito-Standard, Matrix A #67)

**Okabe-Ito 8-Farben-Palette:**
```
#000000 schwarz
#E69F00 orange
#56B4E9 himmelblau
#009E73 bluish-green
#F0E442 gelb
#0072B2 blau
#D55E00 vermillion
#CC79A7 reddish-purple
```

---

## 7. Kulturelle Semantik

Ampel-Farben sind nicht universell. Das config-Option `locale` in `system.md` kontrolliert.

| Locale | Rot | Grün | Gelb |
|--------|-----|------|------|
| Western (EN/DE/FR) | Fehler | Erfolg | Warnung |
| China (zh-CN/zh-TW) | Glück/Anstieg | Verlust/Abfall (Börse!) | Warnung |
| Japan (ja-JP) | Positiv | Neutral | Warnung |
| Naher Osten (ar) | Gefahr/Blut | Islam/Erfolg | Reichtum |

Source: Matrix A #75

Der `color-auditor` liest `locale` aus `system.md` und passt Semantik-Checks entsprechend an.

---

## 8. 60-30-10 Farbregel (Soft-Rule)

| Anteil | Rolle |
|--------|-------|
| 60% | Hintergrund + dominierende Fläche |
| 30% | Struktur (Surfaces, Cards) |
| 10% | Akzente (CTA, Branding, Warnungen) |

Quelle: Matrix A #76

---

## 9. Harmonien

| Harmonie | Hue-Distanz | Use-Case |
|----------|-------------|----------|
| Analog | ±30° | Ruhige, verwandte Stimmung |
| Komplementär | 180° | Starker Kontrast für CTAs |
| Triadisch | 3×120° | Lebhaft, balanciert |
| Tetradisch | 2×Komplementär | Komplex — Vorsicht |

Quelle: Matrix A #77

---

## 10. Trends 2024-2026

- **Material Design 3 Expressive** (Mai 2025): HCT-Farbraum + WCAG-Automatik
- **Apple Liquid Glass** (WWDC Jun 2025): Lensing statt Blur, iOS 27+
- **W3C DTCG JSON** (stabil Okt 2025): Interoperabler Token-Standard
- **Tailwind v4** (@theme-Direktive, Pure CSS Config)

---

## 11. Tool-Integration

| Tool | Zweck | design-forge-Nutzung |
|------|-------|----------------------|
| `scripts/contrast.js` (nativ) | WCAG Luminanz + APCA + Ratio | color-auditor via Bash |
| `scripts/oklch.js` (nativ) | Palette-Generator | optional via system-extract |
| WebAIM Contrast Checker | Manuelle Verifikation | User-Referenz |
| CCA (TPGi) | Professionelle Kontrast-Messung | User-Referenz |
| axe DevTools | Browser-Extension | User-Referenz |

---

## 12. Leitprinzipien

1. **Zahlen vor Meinungen** — jede Farbentscheidung hat eine Ratio
2. **Dark Mode ist eigenes System** — nie Inversion der Light-Werte
3. **Farbe nie alleinige Info** — immer Icon + Text + Farbe (WCAG 1.4.1)
4. **Token statt Hex** — alle Farben über Semantic-Layer
5. **CVD by default** — plane für 8% der Nutzer, nicht als Nachgedanke

---

## 13. Quellenverweise

- **Primär:** `Wissen/Farbe im UI-Design — Vollständiges Nachschlagewerk.md`
- **APCA:** https://apcacontrast.com/
- **OKLCH-Tool:** https://oklch.com/
- **Regel-Index:** Plan §15 Matrix A #62-79
