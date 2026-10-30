# mind-cleaner — Historie der Bloecke

Herleitung, Messungen und Vorfaelle hinter den bash-Bloecken von `skills/mind-cleaner/SKILL.md`, umgezogen aus den
Kommentaren der Bloecke (ZIEL 5, Etappe 58). ⛔ Lies das, BEVOR du einen Block aenderst oder wenn ein
Schritt rot ist — der Lauf selbst braucht es nicht. Je Abschnitt: die Ueberschrift, unter der der Block
stand, und die Kommentarzeilen woertlich.

## ## ⛔ PFLICHTSCHRITTE — dieser Skill fuehrt aus, was hier steht (NEU v5.25.0)

```text
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
```

```text
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
```

## ## Step 1: Messen, was da ist

```text
# oder positional: ... bestandsaufnahme.py <verzeichnis>   (beides seit v5.20.1)
```

## ## Step 5: Umziehen — die Gates, alle müssen halten

```text
# v5.108.0 — Umzug nach docs/ (Klasse DOCS): <s.md> ist die Datei unter docs/
```

## ## `--paths-sonde` — misst, ob `paths:` überhaupt filtert (NEU v5.108.0)

```text
#    ⛔ v5.115.0: OHNE Merker (Tausch lief von Hand, wie im Zustellplan 15.09.) geht es auch:
#       --auswerten "$PROJ" --seit "YYYY-MM-DD HH:MM:SS" [--datei <rule.md>]
#       ohne --datei ALLE Rules mit paths: — je Rule ein Urteil, eines fuer den Bestand,
#       Satz fuer file-handling.md („paths: filtert — gemessen <Datum>, <Projekt>, n Rules,
#       Nachladen bei Dateiberuehrung"). Der Satz kommt erst mit dem ZWEITEN Projekt.
#    Ladeprotokoll SEIT dem Merker aus einer ANDEREN Sitzung: geladen mit session_start ->
#    filtert NICHT (rc 1) · geladen nur mit path_glob_match -> filtert (rc 0) · neue Sitzung,
#    Rule fehlt -> filtert (rc 0) · keine neue Sitzung -> noch nicht messbar (rc 3)
#    Ergebnis: $MIND_DEBUG_DIR/paths-sonde-<ts>.md + der Satz fuer file-handling.md (mit Datum)
```

## ### ⛔ Step 8: Protokollieren — PFLICHT (NEU v5.21.0)

```text
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
```
