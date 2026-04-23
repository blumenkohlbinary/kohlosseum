# UI Patterns Guide für design-forge

**Quellen:** `Wissen/UI Pattern Library — Expertenwissen für Interface-Komponenten.md`
**Scope:** Navigation, Content, Forms, Feedback, Empty States, Anti-Patterns
**Verwendet von:** `interaction-auditor`, `a11y-auditor` (Forms), `system-auditor`

---

## 1. Quickstart: Die 10 kritischsten Patterns/Anti-Patterns

| # | Pattern | Regel | Quelle | Prüfer-Agent |
|---|---------|-------|--------|--------------|
| 1 | Form-Validation | On-Blur, nicht on-keystroke | Matrix A #127 | interaction-auditor |
| 2 | Form-Layout | Single-Column | Baymard / Matrix A #131 | interaction-auditor |
| 3 | Placeholder als Label | ❌ Anti-Pattern | Matrix A #130 | interaction-auditor + a11y-auditor |
| 4 | Hamburger auf Desktop | ❌ Anti-Pattern (≥1024px) | NNG / Matrix A #133 | interaction-auditor |
| 5 | Loading-State Timing | <1s kein / 1–4s Spinner / >4s Skeleton | Matrix A #84, #85 | interaction-auditor |
| 6 | Modal Focus-Trap + Escape | Pflicht | Matrix A #144 | a11y-auditor + interaction-auditor |
| 7 | Toast Auto-Dismiss | 2–4s mit Pause-on-Hover | Matrix A #138 | interaction-auditor |
| 8 | Carousel | Max 5 Items + Pause-Button | NNG / Matrix A #142 | interaction-auditor |
| 9 | Button-States | 5 komplett (default/hover/active/focus/disabled) | Matrix A #50 | system-auditor + interaction-auditor |
| 10 | Error-Message | Spezifisch, nicht "Invalid input" | Matrix A #129 | interaction-auditor |

---

## 2. Navigation Patterns

### 2.1 Top Navigation
- Logo links, Nav-Items mitte, Account/CTA rechts
- Max 7 Top-Level-Items (Hick's Law)
- Breakpoint zu Hamburger: <768px (nicht Desktop!)

### 2.2 Sidebar
- Permanent auf Desktop (≥1280px)
- Collapsible mit Icon+Text
- Mobile: Drawer über Hamburger

### 2.3 Bottom Tab Bar
- Mobile-First (iOS/Android Standard)
- 3–5 Tabs
- Aktiver Tab visuell distinkt (nicht nur Farbe — Icon filled vs outlined)

### 2.4 Breadcrumbs
- Separator `›` oder `/`
- Letzter Item nicht verlinkt
- Strukturiert mit `<nav aria-label="Breadcrumb">`

### 2.5 Tabs vs. Segmented Controls
| Tabs | Segmented |
|------|-----------|
| Verschiedene Content-Pages | Gleicher Content gefiltert |
| ARIA role="tablist" | ARIA role="radiogroup" |

### 2.6 Mega-Menu
- Timing: Show-Delay 100ms, Hide-Delay 500ms
- Keyboard: Arrow-Keys + Escape
- Landmark: `<nav aria-label="...">`

### 2.7 Command Palette (cmd+K)
- Fuzzy-Search
- Recent + Suggested Sections
- Library: `cmdk` (Radix-basiert)

---

## 3. Content Components

### 3.1 Cards

**Click-Behavior eindeutig:**
- Option A: Fully clickable (wrapping `<a>`)
- Option B: Inner CTA-Button only
- NIE mischen in derselben Card-Grid

### 3.2 Lists

- Bullet-List für ungeordnet
- Numbered für geordnete Sequenz
- Table nur für echte Daten mit Spalten-Beziehung

### 3.3 Data Tables

- Sticky Header
- Zebra-Stripes optional (A11y: Kontrast prüfen)
- Sortable mit visueller Indikation + aria-sort
- Responsive: horizontale Scroll oder Card-Transform <768px

### 3.4 Carousels ⚠️

Generelle Empfehlung: **vermeiden**. NNG-Klick-Rate ≤1%.

Wenn unvermeidbar:
- Max 5 Frames
- KEIN Autoplay (oder expliziter Pause-Button)
- Keyboard-Arrow-Nav
- Touch-Swipe + sichtbare Indicators
- Nur für Product-Gallery / Before-After

---

## 4. Input & Forms

### 4.1 Text Inputs

```html
<div class="field">
  <label for="email">Email</label>
  <input
    id="email"
    type="email"
    required
    aria-describedby="email-hint email-error"
  >
  <small id="email-hint">Wir teilen Ihre Adresse nie.</small>
  <span id="email-error" role="alert"></span>
</div>
```

### 4.2 Selection Controls

| # Options | Pattern |
|-----------|---------|
| ≤2 | Toggle (für Ja/Nein) oder 2 Radios |
| 3–4 | Radio-Group |
| 5–7 | Radio oder Dropdown (beides OK) |
| >7 | Dropdown / Combobox |
| >20 | Searchable Combobox |

### 4.3 Form-Layout

**Single-Column** ist Pflicht (Baymard: 78% 1st-try vs 42%).

Exceptions für zusammengehörige Felder:
- City + ZIP
- Vorname + Nachname

### 4.4 Inline Validation

| Timing | Effekt |
|--------|--------|
| on-keystroke | ❌ Premature, frustriert |
| **on-blur** | ✅ **Standard** — nutzer hat fertig getippt |
| on-submit | ⚠️ Zu spät für lange Forms |

### 4.5 Accessibility-Pflicht

- Jedes Input hat `<label>` (sichtbar oder `.sr-only`)
- Error-Container mit `role="alert"` + `aria-live="assertive"`
- Error-Message verlinkt via `aria-describedby`
- Required-Indicator nicht nur rot — auch `required` + Text "(Pflicht)"

---

## 5. Feedback & Overlays

### 5.1 Modal / Dialog

**Pflicht:**
- Focus-Trap (kein Tab nach außen)
- Initial-Focus auf erstes interaktives Element oder Close-Button
- Escape-Key schließt
- Backdrop-Click schließt (außer bei Daten-Verlust-Gefahr)
- Backdrop-Opacity 0.32 (M3)
- `<dialog>` Element bevorzugt, sonst `role="dialog" aria-modal="true"`

```html
<dialog>
  <form method="dialog">
    <h2>Bestätigen</h2>
    <p>Wirklich löschen?</p>
    <button type="button" autofocus>Abbrechen</button>
    <button value="confirm">Löschen</button>
  </form>
</dialog>
```

### 5.2 Toast / Snackbar / Banner

| Pattern | Dauer | Aktion |
|---------|-------|--------|
| Toast | 2–4s | Auto-Dismiss + Pause-on-Hover |
| Snackbar | 2–4s | + Undo-Aktion |
| Banner | persistent | + Dismiss-Button |
| Inline-Alert | persistent | Kontext-spezifisch |

**Never** bei kritischen Aktionen (Zahlung, Löschen) auto-dismiss.

### 5.3 Tooltip vs. Popover

| Tooltip | Popover |
|---------|---------|
| ≤2 Zeilen | Beliebig |
| Nur dekorativ/hint | Kann interaktiv sein |
| Auf Hover/Focus | Auf Click |
| `aria-describedby` | `role="dialog"` + Focus-Trap wenn interaktiv |

**Nie** essentielle Info nur in Tooltip.

### 5.4 Progress Indicators

| Pattern | Use-Case |
|---------|----------|
| Determinate Bar | Upload-Progress |
| Spinner | 1–4s Wait |
| Skeleton | >4s Wait, Layout-Shape bekannt |
| Indeterminate Bar | Unknown Duration |

---

## 6. Empty & Error States

### 6.1 Empty States

- Positive Formulierung: "Noch keine Projekte" statt "Keine Projekte"
- Illustration oder Icon
- 1–2 CTAs max
- Onboarding-Hint ("So erstellst du dein erstes Projekt:")

### 6.2 Error Pages (404, 500)

- Konkrete Ursache wenn möglich
- Navigation zurück (Home, Sitemap, Kontakt)
- Keine stack-traces in Production

### 6.3 Offline-Patterns

- Service-Worker Offline-Fallback
- "Keine Verbindung"-Banner
- Cached-Content bleibt sichtbar

---

## 7. Virtualisierung (ab 500+ Items)

- `@tanstack/virtual` (10–15KB, framework-agnostisch)
- `react-window` (6KB, React-only)
- DOM-Nodes konstant ~50–80 statt 10K

---

## 8. Anti-Patterns Summary

| ❌ Anti-Pattern | Quelle |
|------------------|--------|
| Hamburger auf Desktop | Matrix A #133 |
| Placeholder als Label | Matrix A #130 |
| Validation on-keystroke | Matrix A #127 |
| Mehrspaltige Forms | Matrix A #131 |
| Carousel auto-play >5 Items | Matrix A #142 |
| Card-Click-Inconsistenz | Matrix A #141 |
| Icon-Nav ohne Tooltip | Matrix A #135 |
| Dialog ohne Escape | Matrix A #144 |
| Critical Info nur in Tooltip | Matrix A #143 |
| Timed Critical Notifications | WCAG 2.2.4 |

---

## 9. Quellenverweise

- **Primär:** `Wissen/UI Pattern Library — Expertenwissen für Interface-Komponenten.md`
- **NNG Research:** https://www.nngroup.com/
- **Baymard Institute:** https://baymard.com/
- **ARIA Authoring Practices:** https://www.w3.org/WAI/ARIA/apg/
- **Regel-Index:** Plan §15 Matrix A #126-146
