# Usability Guide für design-forge

**Quellen:** `Wissen/Accessibility & Usability für UIGUI Design-Plugins — Vollständige Referenz.md` (§5 Usability-Heuristiken)
**Scope:** Nielsen's 10, Fitts, Hick, Jakob, Doherty, Gestalt
**Verwendet von:** `interaction-auditor`, `layout-auditor` (Fitts/Gestalt), `performance-auditor` (Doherty)

---

## 1. Nielsen's 10 Heuristiken

### H1: Visibility of System Status
- Loading-Indicators, Progress-Bars
- Breadcrumbs zeigen Position
- Unread-Counter, Saved-Status

### H2: Match Between System and Real World
- Metaphern (Shopping-Cart, Trash-Bin)
- Sprache der Nutzer (nicht System-Jargon)

### H3: User Control & Freedom
- Undo / Redo
- Escape aus jedem Flow
- Cancel-Button bei Dialogen

### H4: Consistency & Standards
- Jakob's Law — Standard-Patterns nutzen
- Innerhalb Projekt: gleiche Farben/Spacing/Icons für gleiche Konzepte

### H5: Error Prevention
- Constraints (disabled bis required filled)
- Confirmation bei destruktiven Aktionen
- Smart Defaults

### H6: Recognition rather than Recall
- Sichtbare Options statt Memorieren
- Breadcrumbs, Recently-Used, Suggested-Items

### H7: Flexibility & Efficiency of Use
- Keyboard-Shortcuts für Power-User
- Command-Palette (Cmd+K)
- Saved-Filters

### H8: Aesthetic & Minimalist Design
- Progressive Disclosure
- 60-30-10 Farbregel
- White-Space als Design-Element

### H9: Help Users Recognize, Diagnose & Recover from Errors
- Konkrete Error-Messages (nicht "Invalid input")
- Fix-Hints direkt im Error
- Error-Location-Hint (welches Feld)

### H10: Help & Documentation
- Contextual Help (Tooltip auf Hover)
- Searchable Docs
- Onboarding-Tour (skippable!)

---

## 2. Fitts's Law

```
MT = a + b × log₂(D/W + 1)
```
MT = Movement-Time, D = Distance, W = Width

**Implikationen:**
- ≥24×24px (AA) / ≥44×44px (AAA) Target-Size
- Größere/näher platzierte Targets = schneller
- Corners/Edges sind "unendlich groß" (Maus rastet ein)

**Error-Rate bei verschiedenen Sizes:**
| Size | Error-Rate |
|------|-----------|
| 44×44 | 3% |
| 24×24 | 15% |
| 16×16 | >40% |

---

## 3. Hick's Law

```
T = b × log₂(n + 1)
```
T = Decision-Time, n = Choices

**Regeln:**
- Top-Level-Options ≤7 (Miller's Magic Number)
- Progressive Disclosure für komplexe Flows
- "Recommended" Default reduziert Choice-Paralysis

---

## 4. Jakob's Law

> "Users spend most of their time on OTHER sites. They prefer your site to work the same way as all the other sites they already know."

**Implikationen:**
- Logo oben links → Homepage
- Cart oben rechts
- Form-Submit unten rechts
- Nicht willkürlich abweichen (nur mit klarem Nutzer-Vorteil)

---

## 5. Doherty Threshold

**System-Response ≤400ms** für optimale Produktivität.

**Techniken:**
- Optimistic UI (Update sofort, sync async)
- Skeleton Screens
- Perceived Performance > Real Performance

---

## 6. Gestalt-Prinzipien

| Prinzip | UI-Anwendung |
|---------|---------------|
| **Proximity** | Innen-Padding ≤ Außen-Margin |
| **Similarity** | Gleiche Farbe/Size/Form = gleiche Funktion |
| **Closure** | Button-Border suggeriert Geschlossenheit |
| **Continuity** | Scrolling entlang klarer Pfade |
| **Figure-Ground** | Fokus-Element vs. Hintergrund |
| **Common Fate** | Gleiche Animation → gleiche Gruppe |
| **Symmetry** | Card-Grid mit gleich-dimensionierten Items |

---

## 7. Weitere Gesetze

### 7.1 Miller's Law (7±2 Chunks)
Short-Term-Memory: 5–9 Items.
→ Menus, Navigation-Tabs, Form-Sections nicht länger.

### 7.2 Peak-End Rule
Nutzer erinnern Peak-Moment + End-Moment überproportional.
→ Onboarding-Abschluss = Feier-Moment.

### 7.3 Serial-Position-Effect
Erste + letzte Items werden besser erinnert.
→ Primary-CTA an Start oder Ende, nicht Mitte.

### 7.4 Law of Common Region
Elemente in gemeinsamer Region (Card, Container) = gruppiert.
→ Form-Sections in visuellen Containern.

### 7.5 Tesler's Law (Conservation of Complexity)
Jedes System hat inhärente Komplexität — entweder User trägt sie oder Developer.
→ Smart Defaults, Auto-Fill, Inferenz.

### 7.6 Postel's Law
> Be conservative in what you do, liberal in what you accept.

→ Input-Forms akzeptieren viele Formate (trim Spaces, tolerant zu E-Mail-Casing etc.).

---

## 8. Usability-Testing

### 8.1 Methoden
| Methode | Sample | Zweck |
|---------|--------|-------|
| Heuristic Evaluation | 3–5 Experten | Schnell-Check gegen Nielsen's 10 |
| Cognitive Walkthrough | 1 Analyst | Task-Completion-Schritte |
| Moderated Usability-Test | 5 Nutzer | Deep-Qualitative |
| A/B-Test | 1000+ | Quantitativ |
| Remote Unmoderated | 20+ | Skaliert |

### 8.2 SUS-Score (System Usability Scale)

10 Fragen, 5-Punkt-Likert. Score-Range:
- >80: Excellent
- 68: Average
- <50: Unacceptable

---

## 9. Leitprinzipien

1. **Jakob's Law respektieren** — Standard wenn möglich
2. **≤7 Top-Level-Optionen** — Hick's Law
3. **≥24×24 Target-Size** — Fitts + WCAG 2.5.8
4. **Specific Error Messages** — Nielsen H9
5. **Consistent Patterns** — Nielsen H4

---

## 10. Quellenverweise

- **Primär:** `Wissen/Accessibility & Usability für UIGUI Design-Plugins — Vollständige Referenz.md` §5
- **Nielsen's 10:** https://www.nngroup.com/articles/ten-usability-heuristics/
- **Laws of UX:** https://lawsofux.com/
- **Regel-Index:** Plan §15 Matrix A #31-36
