---
name: dare-text-merger
description: "DARE-Text Fusion: BASE-Content identifizieren, DELTAS berechnen, sparsifizieren, reskalieren, mergen mit gewichteter Konsensbildung."
allowed-tools: Read, Write
disable-model-invocation: true
user-invocable: false
---

# DARE-Text Merger v1.0

Interner Skill fuer gewichtete Multi-Dokument-Fusion. Wird vom `graph-merger-agent` ueber `skills:`-Referenz aufgerufen. Nicht direkt vom User nutzbar.

## Konzept

DARE-Text (Drop And REscale for Text) ist ein Algorithmus zur Fusion mehrerer Textdokumente, inspiriert vom DARE-Ansatz fuer Modellmerging. Er identifiziert gemeinsame Grundlagen (BASE), berechnet dokumentspezifische Abweichungen (DELTAS), eliminiert redundante Deltas (Sparsifizierung), und rekombiniert alles zu einem kohaerenten Output.

## Input

Erwartet Dateien in `.tdo-pipeline/`:
- `stage-1-parsed/*.json` — Geparste Dokument-Strukturen
- `stage-2-deduped.md` — Deduplizierter Content mit [UNIQUE:Dn] Tags
- `stage-3-contradictions.md` — Widerspruchsbericht

## Algorithmus

### Schritt 1 — BASE-Content identifizieren

Finde Inhalte, die in ALLEN (oder Mehrheit der) Dokumente vorkommen:

```
Fuer jedes Fakt-Cluster:
  IF Fakt in >= 50% der Dokumente:
    → BASE-Content (Konsens)
  ELSE:
    → DELTA (dokumentspezifisch)
```

**BASE-Content** bildet das Fundament des fusionierten Dokuments. Er wird NICHT weiter komprimiert, da er bereits validiert ist.

### Schritt 2 — DELTAS berechnen

Fuer jedes Dokument D_i:
```
DELTA_i = D_i - BASE
```

DELTA enthaelt:
- Einzigartige Fakten ([UNIQUE:Di])
- Zusaetzliche Details
- Spezifische Perspektiven
- Abweichende Formulierungen

### Schritt 3 — Sparsifizierung

Entferne DELTA-Elemente, die:
- Redundant zu anderen DELTAS sind (gleicher Fakt, andere Quelle)
- Unter einem Relevanz-Schwellwert liegen (reine Fuellwoerter)
- Widersprueche enthalten (laut stage-3-contradictions.md)

**NIEMALS sparsifizieren:**
- [UNIQUE:Dn] markierte Inhalte
- Zahlen, Daten, Zitate
- Kausalbeziehungen
- Quellenspezifische Evidenz

### Schritt 4 — Reskalierung

Nach Sparsifizierung sind Luecken im Text entstanden. Reskaliere:

1. Gewichte die verbleibenden DELTAS basierend auf Quellanzahl:
   - Delta in 1 Quelle: Gewicht 1.0 (behalten, [UNIQUE:Dn] markieren)
   - Delta in 2+ Quellen: Gewicht proportional zur Quellenanzahl
2. Fuege Uebergangssaetze ein wo DELTAS zusammentreffen
3. Stelle sicher, dass der reskalierte Text fluessig lesbar ist

### Schritt 5 — Merge mit gewichteter Konsensbildung

```
MERGED = BASE + sum(reskalierte_DELTAS)
```

**Konsens-Regeln:**
- BASE-Fakten: Hoechste Prioritaet, immer im Output
- DELTA mit [UNIQUE:Dn]: Immer behalten, mit Source Attribution [Dn]
- DELTA ohne Markierung: Behalten wenn informationsreich, sonst verwerfen
- Widersprueche: NICHT aufloesen, sondern annotieren (laut Contradiction Report)

### Schritt 6 — Source Attribution

Jeder fusionierte Satz erhaelt Quellenmarker:
```
"Der Umsatz stieg um 12% [D1] auf 247.3 Mio EUR [D1,D2]."
"Die neue Produktlinie wurde im Q3 eingefuehrt [UNIQUE:D2]."
```

## Output

Fusionierter Text mit:
- [D1], [D2], [D3] Quellenmarkern
- [UNIQUE:Dn] fuer dokumentspezifische Inhalte
- Widerspruchs-Annotationen wo relevant
- Konsens-Zusammenfassung am Ende

## Qualitaetsregeln

1. **Kein Informationsverlust**: BASE + alle nicht-redundanten DELTAS muessen im Output sein
2. **Source Traceability**: Jeder Satz muss mindestens einen [Dn]-Marker haben
3. **Kein stilles Aufloesen**: Widersprueche werden annotiert, NICHT entschieden
4. **[UNIQUE:Dn] Schutz**: Einzigartige Inhalte werden NIEMALS entfernt
5. **Kohaerenz**: Output muss als einzelnes Dokument lesbar sein, nicht als Patchwork
