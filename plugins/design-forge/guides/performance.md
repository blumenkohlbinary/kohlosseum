# Performance Guide für design-forge

**Quellen:** `Wissen/Performance-bewusstes UI-Design Technische Checkliste.md`
**Scope:** Core Web Vitals, Critical CSS, Media Optimization, Font Loading, Rendering Performance
**Verwendet von:** `performance-auditor`, `css-auditor` (size-checks), `motion-auditor` (FPS)

---

## 1. Quickstart: Die 8 kritischsten Regeln

| # | Regel | Schwellenwert | Quelle | Prüfer-Agent |
|---|-------|---------------|--------|--------------|
| 1 | LCP (Largest Contentful Paint) | ≤2.5s | CWV / Matrix A #80 | performance-auditor |
| 2 | INP (Interaction to Next Paint) | ≤200ms | CWV / Matrix A #81 | performance-auditor |
| 3 | CLS (Cumulative Layout Shift) | ≤0.1 | CWV / Matrix A #82 | performance-auditor |
| 4 | Critical CSS | ≤14KB gzipped | Matrix A #83 | css-auditor + performance-auditor |
| 5 | Only transform/opacity animieren | Compositor-only | Matrix A #90 | motion-auditor + performance-auditor |
| 6 | Font-Display | swap oder optional | Matrix A #93 | performance-auditor |
| 7 | Image-Format | AVIF / WebP | Matrix A #86 | performance-auditor |
| 8 | Virtual Scrolling | ≥500 Items | Matrix A #92 | performance-auditor |

---

## 2. Core Web Vitals (2025)

| Metrik | Schwellenwert | Bedeutung |
|--------|---------------|-----------|
| **LCP** | ≤2.5s | Largest Contentful Paint — Zeit bis zum größten Element |
| **INP** | ≤200ms | Interaction to Next Paint (ersetzte FID 2024) |
| **CLS** | ≤0.1 | Cumulative Layout Shift — unerwartete Verschiebungen |

**Gemessen:** 75. Perzentil echter Nutzer (Field-Data), nicht Lab-Tests.

---

## 3. Critical CSS (14KB-Regel)

TCP initcwnd=10 → erste 10 Segmente à 1460B = **14.6KB** in einem Roundtrip.

**Strategie:**
1. Above-the-fold CSS inline in `<head>` einbetten
2. Rest async laden mit `<link rel="preload" as="style" onload="...">` oder `media="print" onload="this.media='all'"`

**Tools:** `critical` (npm), `critters` (webpack), `@fullhuman/postcss-purgecss`.

---

## 4. Perceived Performance

### 4.1 Skeleton vs. Spinner

| Wartezeit | UI |
|-----------|-----|
| <1s | Nichts zeigen |
| 1–4s | Spinner |
| >4s | Skeleton-Screen oder Progress Bar |

Skeleton-Screens werden 20–50% kürzer wahrgenommen (Bill Chung).

### 4.2 Optimistic UI

UI-Update vor Server-Response, Rollback bei Fehler. Pattern: Delete-Action mit Undo-Toast.

---

## 5. Rendering-Performance

### 5.1 Compositor-Only Properties

| Animierbar ohne Reflow | Layout-trigger ❌ |
|-----------------------|---------------------|
| `transform` | width, height |
| `opacity` | top, left, right, bottom |
| `filter` | margin, padding |
| `backdrop-filter` | font-size |

### 5.2 CSS Containment

```css
.card { contain: content; }
.section { contain: strict; } /* strict = content + size (erfordert intrinsic-size) */
```

**content-visibility: auto** für Off-Screen-Sections:
```css
.lazy-section {
  content-visibility: auto;
  contain-intrinsic-size: auto 500px;
}
```
→ 7× Rendering-Boost bei 10K-DOM (Matrix A #87)

### 5.3 will-change — Dynamisch, nicht global

```css
/* ❌ */
.btn { will-change: transform; }

/* ✅ */
.btn:hover { will-change: transform; transition: transform 200ms; }
.btn:not(:hover) { will-change: auto; }
```

Oder via JS-Event (pointerenter/pointerleave).

---

## 6. Layout-Thrashing vermeiden

FastDOM-Pattern:
```js
// ❌ Thrashing
for (const el of elements) {
  const h = el.offsetHeight; // Read
  el.style.height = h + 10 + 'px'; // Write (forces reflow)
}

// ✅ Batched
const heights = elements.map(el => el.offsetHeight); // All reads
elements.forEach((el, i) => el.style.height = heights[i] + 10 + 'px'); // All writes
```

---

## 7. Image Optimization

### 7.1 AVIF / WebP

```html
<picture>
  <source srcset="hero.avif" type="image/avif">
  <source srcset="hero.webp" type="image/webp">
  <img src="hero.jpg" alt="..." width="1200" height="600">
</picture>
```

- AVIF: ~50% kleiner als JPEG
- WebP: ~30% kleiner als JPEG

### 7.2 Responsive Images

```html
<img
  srcset="small.jpg 400w, medium.jpg 800w, large.jpg 1200w"
  sizes="(min-width: 1024px) 800px, 100vw"
  src="medium.jpg"
  alt="..."
  width="800"
  height="400"
  loading="lazy"
  decoding="async"
>
```

---

## 8. Font Loading

### 8.1 font-display Strategien

| Wert | FOUT | FOIT | CLS | Use-Case |
|------|------|------|-----|----------|
| `auto` | ⚠️ | ⚠️ | ⚠️ | Browser-Default (vermeiden) |
| `block` | nein | ja (3s) | mittel | Brand-kritisch |
| **`swap`** | **ja** | **nein** | **hoch** | **Standard** |
| `fallback` | kurz | kurz | niedrig | Body-Text |
| `optional` | evtl. | nein | **0** | **CLS-Priorität** |

### 8.2 Subsetting

Latin-Subset via `glyphhanger`:
```bash
glyphhanger ./*.html --subset=font.woff2 --formats=woff2
```
→ ~96% Size-Reduktion

### 8.3 size-adjust für Fallback-Match

```css
@font-face {
  font-family: 'Inter Fallback';
  src: local('Arial');
  size-adjust: 107%;
  ascent-override: 90%;
  descent-override: 22%;
}

body { font-family: 'Inter', 'Inter Fallback', sans-serif; }
```

→ Kein Layout-Shift beim Font-Swap.

---

## 9. Virtual Scrolling

Ab ~500–1000 Items DOM-kritisch.

Libraries:
- `@tanstack/virtual` (~10–15KB)
- `react-window` (~6KB)
- `virtua` (Framework-agnostisch)

**Regel:** DOM-Nodes warnen ab ~800, kritisch >1400.

---

## 10. Passive Event Listeners

```js
element.addEventListener('scroll', handler, { passive: true });
element.addEventListener('touchmove', handler, { passive: true });
```

→ ~50%+ Scroll-Smoothness auf Mobile.

---

## 11. Debounce vs. Throttle

| Pattern | Delay | Use-Case |
|---------|-------|----------|
| Debounce | 300ms | Autocomplete-Search |
| Throttle | 100ms | Scroll-Event-Handler |
| requestAnimationFrame | 16.67ms | Animation-Loop |

---

## 12. Target-Werte-Tabelle

| Metrik | Gut | Verbesserung | Kritisch |
|--------|-----|--------------|----------|
| LCP | ≤2.5s | 2.5–4s | >4s |
| INP | ≤200ms | 200–500ms | >500ms |
| CLS | ≤0.1 | 0.1–0.25 | >0.25 |
| FCP | ≤1.8s | 1.8–3s | >3s |
| TTI | ≤3.8s | 3.8–7.3s | >7.3s |
| TTFB | ≤800ms | 800–1800ms | >1800ms |

---

## 13. Die 5 höchsten Hebel

1. **Critical CSS** (-30 bis -60% FCP)
2. **content-visibility: auto** (7× Rendering-Boost)
3. **AVIF/WebP** (-50% Image-Size)
4. **font-display: optional** (0 CLS)
5. **Layout-Batching** (-18% INP)

---

## 14. Tool-Integration

| Tool | Zweck | Integration |
|------|-------|-------------|
| Lighthouse | CWV-Live-Messung | Bash(lighthouse) |
| WebPageTest | 3G/4G-Profile | External API |
| Bundlephobia | NPM-Package-Size | Browser/API |
| Chrome DevTools | Frame-Analysis | Browser Native |
| critical | Critical-CSS-Extract | Build-Pipeline |
| glyphhanger | Font-Subsetting | CLI |

---

## 15. Leitprinzipien

1. **Compositor-Only animieren** — transform/opacity + filter
2. **Critical CSS ≤14KB** — TCP-Fenster respektieren
3. **Images mit dims** — CLS-Prävention
4. **font-display: optional** für Body — CLS 0
5. **Virtual Scroll ab 500 Items** — DOM-Budget

---

## 16. Quellenverweise

- **Primär:** `Wissen/Performance-bewusstes UI-Design Technische Checkliste.md`
- **CWV:** https://web.dev/vitals/
- **Lighthouse:** https://developer.chrome.com/docs/lighthouse/
- **Regel-Index:** Plan §15 Matrix A #80-97
