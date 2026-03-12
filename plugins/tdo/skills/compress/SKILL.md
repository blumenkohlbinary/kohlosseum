---
name: compress
description: "Einzeldokument-Kompression via TDO v11.2.1. Nutze wenn der User 'komprimiere', 'kuerze Text', 'verdichte', 'compress' sagt. Dynamische Kompression, komplett lossless."
argument-hint: "[text oder @datei]"
context: inherit
allowed-tools: Read, Write
---

# /compress — Einzeldokument-Kompression

Komprimiere ein einzelnes Dokument komplett verlustfrei mittels TDO v11.2.1. Die Kompressionsrate ist dynamisch — sie richtet sich nach dem Waste-Anteil des Textes (gut geschrieben = wenig Kompression, schlecht geschrieben = hohe Kompression).

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
Metrics: [X] → [Y] chars (-[Z]%) | Waste-Anteil: [W]% | Dynamisch
Gates: Faktisch ✅ | Struktur ✅ | Qualitaet ✅ | CoVe ✅
Protected: [N] elements | Skeleton: [N] claims | Domain: [type]
```

## Edge Cases

- **Sehr kurzer Text** (<100 Woerter): Warnung, Kompression versuchen
- **Bereits komprimierter Text** (Score-1-2 < 5%): Dokument UNVERAENDERT zurueckgeben. Meldung: "Text bereits optimal. Waste-Anteil: [X]%. Keine Kompression noetig."
- **Gut geschriebener Text** (Score-1-2 10-25%): Leichte Kompression (15-30%). Nur Waste entfernen.
- **Code/Tabellen-lastiger Text**: Nur Fliesstext komprimieren, Code/Tabellen zeichenidentisch bewahren
- **PII erkannt**: REJECT mit Erklaerung
