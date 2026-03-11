---
name: cove-verifier
description: "Chain-of-Verification: Claims extrahieren, Verifikationsfragen generieren, ISOLIERT beantworten, Diskrepanzen patchen. Entity-Extraktion-Verifikation."
allowed-tools: Read, Write
disable-model-invocation: true
user-invocable: false
---

# CoVe Verifier v1.0

Interner Skill fuer adversariale Faktenverifikation. Wird vom `verification-agent` ueber `skills:`-Referenz aufgerufen. Nicht direkt vom User nutzbar.

## Konzept

Chain-of-Verification (CoVe) ist ein adversarialer Ansatz zur Faktenverifikation. Anstatt den komprimierten/fusionierten Text direkt mit dem Original zu vergleichen, werden Claims ISOLIERT verifiziert — das verhindert Bestaetigungsfehler (Confirmation Bias).

## Input

Erwartet:
- Zu verifizierender Text (fusioniert/komprimiert)
- Originaldokumente (`.tdo-pipeline/input/`)
- Protected Registry (`.tdo-pipeline/protected-registry.json`)

## CoVe-Protokoll (4 Phasen)

### Phase 1 — Claims extrahieren

Extrahiere JEDE faktische Aussage als eigenstaendigen Claim:

```
CLAIMS:
[C1] "Umsatz stieg 2024 um 12% auf 247.3 Mio EUR" | Quelle: [D1]
[C2] "Unternehmen wurde 2018 gegruendet" | Quelle: [D2]
[C3] "CEO Mueller kuendigte Expansion nach Asien an" | Quelle: [D1,D3]
[C4] "Die randomisierte Studie umfasste 500 Teilnehmer" | Quelle: [D2]
```

**Claim-Typen:**
- Numerisch: Zahlen, Prozente, Messwerte
- Temporal: Daten, Zeitraeume, Reihenfolgen
- Entitaet: Namen, Organisationen, Orte
- Kausal: Ursache-Wirkung-Beziehungen
- Attributiv: Eigenschaften, Merkmale, Zustaende

### Phase 2 — Verifikationsfragen generieren

Fuer JEDEN Claim eine spezifische, beantwortbare Frage:

```
[C1] → "Wie hoch war der Umsatzanstieg 2024 laut Originaldokument D1?"
[C2] → "In welchem Jahr wurde das Unternehmen laut Originaldokument D2 gegruendet?"
[C3] → "Was kuendigte CEO Mueller bezueglich Expansion an, laut D1 und D3?"
[C4] → "Wie viele Teilnehmer hatte die Studie laut Originaldokument D2?"
```

**Fragenregeln:**
- Frage muss OHNE den zu verifizierenden Text beantwortbar sein
- Frage muss auf das Originaldokument verweisen
- Frage muss spezifisch genug fuer eine eindeutige Antwort sein

### Phase 3 — ISOLIERT beantworten

**KRITISCH: Beantworte jede Frage NUR anhand der Originaldokumente.**
Den zu verifizierenden Text dabei NICHT lesen.

```
[C1] Antwort: "Laut D1: Umsatzanstieg 12%, auf 247.3 Mio EUR" ✅
[C2] Antwort: "Laut D2: Gruendungsjahr 2018" ✅
[C3] Antwort: "Laut D1: Expansion nach Asien; D3: Expansion nach Suedostasien" ⚠️
[C4] Antwort: "Laut D2: 512 Teilnehmer, nicht 500" ❌
```

### Phase 4 — Abgleich + Patch

Vergleiche isolierte Antworten mit Claims:

| Status | Bedeutung | Aktion |
|--------|-----------|--------|
| ✅ MATCH | Claim stimmt mit Original ueberein | Keine Aktion |
| ⚠️ PARTIAL | Teilweise korrekt, unvollstaendig | Claim ergaenzen/praezisieren |
| ❌ MISMATCH | Claim weicht vom Original ab | Claim durch Original ersetzen |
| MISSING | Claim hat keine Quelle im Original | Claim ENTFERNEN (Halluzination) |

**Patch-Protokoll:**
```
[C3] PARTIAL → Patch: "CEO Mueller kuendigte Expansion nach Suedostasien an [D3]"
     (Praezisere Formulierung aus D3 hat Vorrang vor allgemeiner aus D1)

[C4] MISMATCH → Patch: "512 Teilnehmer" statt "500 Teilnehmer"
     (Exakter Wert aus Original restauriert)
```

## Entity-Extraktion-Verifikation

Zusaetzlich zum Claim-basierten CoVe:

### Entitaeten-Abgleich

1. Extrahiere ALLE benannten Entitaeten aus Originaldokumenten:
   - Personen (Name, Titel, Funktion)
   - Organisationen (Name, Typ, Ort)
   - Orte (Name, Land, Region)
   - Produkte (Name, Version, Spezifikation)

2. Extrahiere ALLE benannten Entitaeten aus verifiziertem Text

3. Vergleiche:
   - Fehlende Entitaet im Output → WARNUNG (moeglicherweise Informationsverlust)
   - Veraenderte Entitaet → FEHLER (muss korrigiert werden)
   - Neue Entitaet im Output → KRITISCH (Halluzination → entfernen)

## Output-Format

```
=== CoVe Verification Report ===
Claims verifiziert: [N]
  ✅ MATCH: [N] ([%])
  ⚠️ PARTIAL: [N] ([%]) — gepatcht
  ❌ MISMATCH: [N] ([%]) — korrigiert
  MISSING: [N] ([%]) — entfernt

Entity-Check:
  Gesamt: [N] | Korrekt: [N] | Korrigiert: [N] | Entfernt: [N]

Patches angewendet: [N]
[Liste der Patches mit Begruendung]

Verifikations-Urteil: BESTANDEN / DURCHGEFALLEN
```

## Qualitaetsregeln

1. **Isolierung**: Antworten NIEMALS aus dem zu verifizierenden Text ableiten
2. **Quellenprioritat**: Protected Registry > Originaldokument > Kontext
3. **Null-Toleranz fuer Halluzinationen**: Jeder Fakt ohne Quelle = ENTFERNEN
4. **Patch-Transparenz**: Jeder Patch wird dokumentiert und begruendet
5. **Keine stille Korrektur**: Alle Aenderungen im Report sichtbar
