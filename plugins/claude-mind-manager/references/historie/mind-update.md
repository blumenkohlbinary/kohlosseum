# mind-update — Historie der Bloecke

Herleitung, Messungen und Vorfaelle hinter den bash-Bloecken von `skills/mind-update/SKILL.md`, umgezogen aus den
Kommentaren der Bloecke (ZIEL 5, Etappe 58). ⛔ Lies das, BEVOR du einen Block aenderst oder wenn ein
Schritt rot ist — der Lauf selbst braucht es nicht. Je Abschnitt: die Ueberschrift, unter der der Block
stand, und die Kommentarzeilen woertlich.

## ## ⛔ PFLICHTSCHRITTE — dieser Skill fuehrt aus, was hier steht (NEU v5.25.0)

```text
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
```

```text
# ⛔ v5.97.0 — VERDICHTEN und die fuenf Context-Skills NUR mit ARTEFAKT: ohne --datei
#    wird `gelaufen` zu `uebersprungen:kein-artefakt`, und die Bilanz zaehlt FORMAL.
#    Drei Laeufe (10.–12.09.2026) trugen dieselben getippten Bytes; Zahlen tippt die Hand.
```

```text
  # ⛔ v5.135.0: die Datei wird GEPRUEFT, nicht nur genannt — Pfad und Byte-Zahl stehen in der
  #    Quittung, und ein schneller Block gilt damit nicht mehr als nachgetippt
  #    (`references/bestands-pass.md`: „Ein pruefbares Artefakt schlaegt die Zeitregel").
```

## # Backtick-Spans mit mindestens einem / oder \ — und [^`\n], NICHT [^`]:

```text
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
```

```text
# ⛔ Existenz NUR ueber `mind_pfad_lebt` pruefen, NIE mit blossem `test -e`.
# Bash expandiert `~` in Anfuehrungszeichen NICHT: `test -e "~/.claude/rules/x.md"`
# ist immer falsch, die Datei mag mit 68 Zeilen dort liegen. Ergebnis war DEAD,
# und bei <=5 DEAD wird AUTONOM GELOESCHT. Gemessen und reproduziert 21.08.2026
# (`tests/test_lib_v511.sh`, Befund aus `APP - Palvedo`).
```

## ### 3c: Commit-Coverage-Gate (deterministisch — objektiver Knowledge-Gap)

```text
# Commit-Coverage: welche Feature-Commits sind NICHT in den Context-Dateien?
# Stichwort-Wahl (N1-Fix): zuerst dev.NN, dann der conventional-commit-SCOPE
# (feat(SCOPE):), erst zuletzt ein Subject-Token — Stopwords ausgeschlossen.
# Grep-Ziele als ARRAY, nie als Zeichenkette: ein Pfad mit Leerzeichen zerfaellt sonst in
# Stuecke — derselbe Fehler, der in v5.2.1 die Rotation lahmlegte (xargs +
# "Plugin - Entwicklung"). Die Zusatzziele kommen aus der CLAUDE.md SELBST; es wird nicht
# geraten, welche Datei "kanonisch" ist. Gemessen: 2 -> 17 Ziele im Zustellplan-Projekt.
```

```text
# v5.153.0: MEMORY_MAIN kam aus Step 1 — einem anderen Prozess. Leer war das zweite Ziel "".
```

```text
# ⛔ v5.147.0 (Etappe 56 §5, CK3): OHNE CONVENTIONAL COMMITS MISST DAS GATE NICHTS — und sagt es.
#    CK3: 0 von 30 (deutsche Commits), Palvedo ebenso; dann kam gar keine Zeile, und das las
#    sich wie „keine Luecken“. Jetzt steht NICHT ANWENDBAR da, keine Zahl.
```

```text
  # KEIN -F: grep -iF auf UTF-8 (deutsche Umlaute in MEMORY.md) wirft auf Git-Bash/MSYS
  # "Aborted (core dumped)" -> non-zero -> falsche GAPs (real 2026-07-15: 24 Fake-GAPs aus
  # dem Crash). grep -qi (ohne -F) ist verifiziert crash-frei; Keys sind regex-safe. v4.1.0-Fix.
```

```text
    # Sichtbar machen statt verschweigen: ohne belastbares Stichwort ist der Commit
    # UNGEPRUEFT, nicht unauffaellig. Genau diese Stille war der Defekt bis v5.5.1.
```

## ### ⛔ Agent-Quittung — PFLICHT, vor UND nach jedem Agent (NEU v5.14.0)

```text
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
```

```text
                                            #   oder unbekannt = rc 2, nichts geschrieben (18.09.: vier Streuner-Ordner im cwd)
# ... Agent laeuft (run_in_background: false — der tool_result IST die Rueckgabe) ...
# ⛔ v5.94.0: die Bytes kommen aus einer DATEI, nie aus dem Kopf. Den tool_result
#    mit `Write` nach $PROJ/.claude-mind/agent-<bereich>.md legen, dann:
```

## ## Step 5d: ⛔ Das Kontext-Tor — PFLICHT vor jedem `ADD` (NEU v5.26.0)

```text
# 3) D1 "WOHIN?" — NEU v5.39.0, eingehaengt v5.40.0.
#    Das Tor oben sagt OB etwas hinein darf. D1 sagt WOHIN es gehoert.
```

## ## Step 5d: ⛔ Der Bestands-Pass — PFLICHT, auch bei leerem Befund (NEU v5.22.0)

```text
# 1b) Art 6 (v5.90.0): ungegatete BESTANDSZAHLEN als Kandidaten — mind-update ist der
#     haeufigste Lauf, deshalb hier ueber Projekt UND ~/.claude. ⛔ Er urteilt nie, rc 0.
```

## ## Step 6.1: Drift-Report + Knowledge-Sync-Report (nach Self-Check-Block)

```text
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
```
