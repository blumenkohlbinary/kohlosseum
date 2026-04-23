# Motion Guide für design-forge

**Quellen:** `Wissen/UI-Animation & Micro-Interactions Vollständige Wissensbasis.md`
**Scope:** Disney-Prinzipien, Easing, Timing, Micro-Interactions, prefers-reduced-motion, FLIP, Spring
**Verwendet von:** `motion-auditor`, `performance-auditor` (FPS), `a11y-auditor` (vestibular)

---

## 1. Quickstart: Die 8 kritischsten Regeln

| # | Regel | Schwellenwert | Quelle | Prüfer-Agent |
|---|-------|---------------|--------|--------------|
| 1 | Enter-Duration | 150–225ms | Matrix A #147 | motion-auditor |
| 2 | Exit-Duration | 70–195ms | Matrix A #148 | motion-auditor |
| 3 | State-Change | 200–300ms | Matrix A #149 | motion-auditor |
| 4 | Micro-Feedback | 50–100ms | Matrix A #150 | motion-auditor |
| 5 | Stagger Total | ≤1000ms | Matrix A #151 | motion-auditor |
| 6 | prefers-reduced-motion | implementiert | Matrix A #159 | motion-auditor |
| 7 | Flimmern | ≤3 Blitze/s | WCAG 2.3.1 / Matrix A #13 | motion-auditor |
| 8 | Nur transform/opacity | Compositor | Matrix A #90 | motion-auditor + performance-auditor |

---

## 2. Timing & Duration

### 2.1 Duration-Tabelle

| Kontext | Range | Cubic-Bezier |
|---------|-------|--------------|
| Micro-Feedback (Toggle, Ripple) | 50–100ms | instant/linear |
| **Enter** (Modal-In, Dropdown-Open) | **150–225ms** | **cubic-bezier(0, 0, 0.2, 1)** — Deceleration |
| **Exit** (Modal-Out, Dropdown-Close) | **70–195ms** | **cubic-bezier(0.4, 0, 1, 1)** — Acceleration |
| **State-Change** (Hover, Focus) | **200–300ms** | **cubic-bezier(0.4, 0, 0.2, 1)** — Standard |
| Complex Move (On-Screen) | 300–500ms | standard |
| Page-Transition | 400–600ms | standard |
| Onboarding-Hero | 800–1200ms | choreografiert |

### 2.2 60fps = 16.67ms/Frame

Browser-Overhead ~6ms → **~10ms für Animation-Logik**. Bei Überschreitung: Jank.

---

## 3. Easing Decision Matrix

| Easing | Formel | Use-Case |
|--------|--------|----------|
| `linear` | linear(0, 1) | Progress-Bars |
| `ease-out` | cubic-bezier(0, 0, 0.2, 1) | Enter — Element kommt zur Ruhe |
| `ease-in` | cubic-bezier(0.4, 0, 1, 1) | Exit — Element beschleunigt raus |
| `ease-in-out` | cubic-bezier(0.4, 0, 0.2, 1) | State-Change, Symmetrisch |
| `overshoot` | cubic-bezier(0.68, -0.55, 0.265, 1.55) | Playful |
| `spring` | CSS linear() oder JS | Unterbrechbare Interaktionen |

---

## 4. Die 12 Disney-Prinzipien (UI-angewandt)

| # | Prinzip | UI-Anwendung |
|---|---------|---------------|
| 1 | Squash & Stretch | Button-Press: scale(0.95) + scale(1) |
| 2 | Anticipation | Loading-Pull-to-Refresh Spannungsanzeige |
| 3 | Staging | Focus-Element bekommt Contrast/Scale |
| 4 | Straight-Ahead / Pose-to-Pose | Lottie vs. CSS keyframes |
| 5 | Follow-Through | Ausschwingen bei Card-Drop |
| 6 | Slow-In / Slow-Out | ease-out / ease-in |
| 7 | Arcs | Modal-Erscheinen von unten (nicht linear) |
| 8 | Secondary Action | Icon-Rotation während Button-Click |
| 9 | Timing | Duration-Tabelle §2.1 |
| 10 | Exaggeration | Empty-State mit oversize Illustration |
| 11 | Solid Drawing | Elevation-Shadow während Drag |
| 12 | Appeal | Character/Mascot-Animations |

---

## 5. Micro-Interactions

### 5.1 Button-States

```css
.btn {
  transition: background 100ms ease-out,
              transform 100ms ease-out;
}
.btn:hover { background: var(--hover); }
.btn:active { transform: scale(0.97); }
.btn:focus-visible { outline: 2px solid var(--focus); }
```

### 5.2 Toggle

```css
.toggle__thumb {
  transition: transform 200ms cubic-bezier(0.4, 0, 0.2, 1);
}
.toggle[aria-pressed="true"] .toggle__thumb {
  transform: translateX(20px);
}
```

### 5.3 Ripple (Material)

JavaScript: radiale Expansion ab Click-Koordinate, opacity-fade-out.

---

## 6. Page / Section Transitions

### 6.1 View Transitions API

```css
@view-transition { navigation: auto; }

.hero { view-transition-name: hero-image; }
```

```html
<!-- Chrome 126+, Safari 18+ Cross-Document MPA Support -->
```

### 6.2 FLIP-Technique

First, Last, Invert, Play — für Layout-Animations ohne Reflow:

```js
const first = el.getBoundingClientRect();
// do DOM mutation
const last = el.getBoundingClientRect();
const invert = { x: first.x - last.x, y: first.y - last.y };
el.animate(
  [{ transform: `translate(${invert.x}px, ${invert.y}px)` }, { transform: 'none' }],
  { duration: 300, easing: 'cubic-bezier(0.4, 0, 0.2, 1)' }
);
```

### 6.3 Stagger

```css
.list-item {
  animation: slide-in 300ms cubic-bezier(0, 0, 0.2, 1) backwards;
}
.list-item:nth-child(1) { animation-delay: 0ms; }
.list-item:nth-child(2) { animation-delay: 80ms; }
.list-item:nth-child(3) { animation-delay: 160ms; }
/* Max: 1000ms gesamt */
```

---

## 7. Accessibility & Performance

### 7.1 prefers-reduced-motion

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

Default = reduziert, Opt-In für volle Animation via `:no-preference`.

### 7.2 Vestibular-Safe-Zone

- ✅ Opacity-Fade
- ✅ Color-Transitions
- ✅ Kleine Translate (<20px)
- ⚠️ Rotation >15°
- ⚠️ Scale-Changes >10%
- ❌ Parallax-Scroll
- ❌ Kontinuierliche Auto-Rotation
- ❌ Kamera-Shake-Effekte

### 7.3 Seizure-Prevention

- Max 3 Blitze/Sekunde (WCAG 2.3.1)
- Keine roten Flashes auf gesamten Viewport

---

## 8. Moderne Trends

### 8.1 Spring-Physics (CSS linear())

```css
.bounce {
  animation: slide-in 800ms linear(
    0, 0.45 13.575%, 0.75 25.4%, 0.93 37.8%, 1 52%,
    0.93 64.8%, 0.85 75.5%, 0.9 85.8%, 1 100%
  );
}
```

→ Spring-Approximation in Pure CSS (~88% Browser-Support).

### 8.2 Scroll-Driven Animations

```css
@keyframes fade-in { from { opacity: 0; } to { opacity: 1; } }

.hero {
  animation: fade-in linear;
  animation-timeline: view();
  animation-range: entry 0% cover 30%;
}
```

→ Off-Main-Thread, Zero-Bundle-Overhead.

### 8.3 Lottie Animations

- Gut: Komplexe Icon-States, Onboarding-Illustrationen
- Vorsicht: Size >50KB, JS-Overhead
- Alternative: Optimiertes SVG mit CSS-Animation

---

## 9. Wann Animation hilft — und wann sie schadet

| ✅ Hilft | ❌ Schadet |
|---------|-----------|
| Feedback auf User-Action | Dekorativ ohne Zweck |
| State-Transition sichtbar machen | Wait-Time verlängern |
| Fokus-Lenkung | Ablenkung von Content |
| Spatial-Relationship zeigen | Confuse/Overstimulate |
| Delight bei Milestones | Jeder Click animiert |

---

## 10. Leitprinzipien

1. **Enter: ease-out / Exit: ease-in** — Polarität zählt
2. **prefers-reduced-motion Default reduziert** — invertierte Logik
3. **Nur transform/opacity** — Compositor-Only
4. **100–300ms UI-Standard** — nicht länger
5. **Tokens statt Hard-Coded** — `var(--duration-standard)`

---

## 11. Quellenverweise

- **Primär:** `Wissen/UI-Animation & Micro-Interactions Vollständige Wissensbasis.md`
- **Disney 12 Principles:** https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation
- **View Transitions API:** https://developer.mozilla.org/en-US/docs/Web/API/View_Transitions_API
- **Regel-Index:** Plan §15 Matrix A #147-160
