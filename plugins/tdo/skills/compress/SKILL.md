---
name: compress
description: "Einzeldokument-Kompression via TDO v11.2. Nutze wenn der User 'komprimiere', 'kuerze Text', 'verdichte', 'compress' sagt. Ziel: 45-55% verlustfrei."
argument-hint: "[text oder @datei]"
context: inherit
allowed-tools: Read, Write
---

# /compress — Einzeldokument-Kompression

Komprimiere ein einzelnes Dokument verlustfrei auf 45-55% der Originallaenge mittels TDO v11.2.

## Input erkennen

Analysiere `$ARGUMENTS`:

1. **Text direkt angegeben** → Verwende den Text als Input
2. **@dateiname referenziert** → Lies die Datei via Read-Tool
3. **Keine Argumente** → Frage: "Bitte Text bereitstellen — direkt einfuegen oder mit @dateiname referenzieren."

## Verarbeitung

Fuehre den `text-density-optimizer` Skill (TDO v11.2) mit dem erkannten Input aus:

### Schritt 1 — Domain-Detection
Erkenne den Domain-Typ des Textes (General/Medical/Legal/Financial/Scientific/Code/Mixed) und passe das Kompressionsziel entsprechend an.

### Schritt 2 — TDO v11.2 Stufen 0-5

Fuehre alle 6 Stufen des TDO v11.2 aus:
- **Stufe 0**: Strukturierte Vorverarbeitung (Token-Scoring, Protected Registry, Dedup, Domain-Detection)
- **Stufe 1**: Skeleton-Extraktion (hierarchischer Outline aller Hauptaussagen)
- **Stufe 2**: Enhanced Chain-of-Density-Kompression (5 Iterationen, Multi-Kategorie-Erhaltung)
- **Stufe 3**: Verifikation (3 Gates + Fraktale Ebenen + Skeleton-Abgleich)
- **Stufe 4**: Self-Consistency-Check (3 Versionen, Fakten-Vereinigung)
- **Stufe 5**: Adversarial Fact-Check (CoVe-Protokoll)

### Schritt 3 — Ergebnis mit Metriken ausgeben

## Output-Format

```
[Komprimierter Text]

---
Metrics: [X] → [Y] chars (-[Z]%) | Target: 45-55%
Gates: Faktisch ✅ | Struktur ✅ | Qualitaet ✅ | CoVe ✅
Protected: [N] elements | Skeleton: [N] claims | Domain: [type]
```

## Edge Cases

- **Sehr kurzer Text** (<100 Woerter): Warnung ausgeben, Kompression trotzdem versuchen
- **Bereits komprimierter Text** (>6 Fakten/Satz): Konservatives Ziel (-10-15%)
- **Code/Tabellen-lastiger Text**: Nur Fliesstext komprimieren, Code/Tabellen zeichenidentisch bewahren
- **PII erkannt**: REJECT mit Erklaerung
