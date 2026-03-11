# Error Recovery — Referenzdokument

## Fehler-Erkennung (nach jeder Stage)

```
NACH JEDER STAGE:
1. Lies pipeline-state.json
2. Pruefe status:
   - "OK" → Weiter zur naechsten Stage
   - "FAIL" → Error Recovery anwenden
   - "COMPLETE" → Pipeline abgeschlossen
```

## Severity-basierte Recovery

| Severity | Bedingung | Aktion |
|----------|-----------|--------|
| **minor** | 1-3 kleine Fehler | Stage re-run mit Patch-Hinweisen |
| **major** | 4-10 Fehler oder fehlende [UNIQUE:Dn] | Zurueck zur vorherigen Stage, Kompression reduzieren, re-run |
| **critical** | >10 Fehler oder Protected Elements veraendert | STOP → User informieren, Teilergebnis bereitstellen |
| **source-imbalance** | Coverage <90% fuer eine Quelle | Unique Content restaurieren, Gate 4 re-run |

## Retry-Logik

```
MAX_RETRIES = 3

Fuer jede Stage:
  attempts[stage_N] = 0

  Bei FAIL:
    attempts[stage_N] += 1
    IF attempts[stage_N] <= MAX_RETRIES:
      → Recovery-Aktion anwenden
      → Stage re-dispatchen
    ELSE:
      → STOP
      → Teilergebnis + Fehlerbericht ausgeben
      → User informieren
```

## Recovery-Aktionen pro Stage

| Stage | Minor Recovery | Major Recovery |
|-------|---------------|----------------|
| 1 Parser | Re-parse fehlerhaftes Dokument | Manuell parsen (ohne Agent) |
| 2 Dedup | Fehlende Tags nachtragen | Re-run mit gelockerter Duplikat-Schwelle |
| 3 Contradiction | Fehlende Typen nachpruefen | Re-run mit allen 6 Typen erzwungen |
| 4 Merger | Fehlende Attributionen ergaenzen | Re-run ohne Kompression |
| 5 Architect | Blueprint korrigieren | Manuell strukturieren |
| 6 Coherence | Terminologie-Fixes nachtragen | Re-run mit weniger Ton-Anpassungen |
| 7 Verification | Patches anwenden, re-check | Zurueck zu Stage 4 |
| 8 Finalizer | Fehlende Sektionen ergaenzen | Checkliste-Items manuell pruefen |

## Pipeline-Cleanup

### Nach erfolgreichem Abschluss

```
STANDARD: .tdo-pipeline/ Verzeichnis behalten (fuer Nachvollziehbarkeit)

MIT --keep-pipeline Flag:
  → Verzeichnis explizit beibehalten

OHNE --keep-pipeline:
  → User fragen: "Pipeline-Artefakte behalten oder loeschen?"
```

### Bei Fehler

```
BEI STOP:
  → .tdo-pipeline/ IMMER beibehalten
  → Teilergebnis in stage-8-final.md (als DRAFT markiert)
  → pipeline-state.json zeigt Fehlerdetails
  → User kann manuell eingreifen oder re-run anfordern
```
