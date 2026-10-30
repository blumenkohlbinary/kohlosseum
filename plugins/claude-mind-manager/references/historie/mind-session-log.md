# mind-session-log — Historie der Bloecke

Herleitung, Messungen und Vorfaelle hinter den bash-Bloecken von `skills/mind-session-log/SKILL.md`, umgezogen aus den
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

## ## Step 1: Argumente parsen

```text
# v3.3.0 NEU: `combined` Arg → altes Verhalten (1 File ab letztem Command)
```

```text
# v3.3.1 NEU: `all-commands` oder `--all-commands` Arg → alle Slash-Commands (nicht nur mind-*)
# H1-Fix Skill-Review: Regex toleriert sowohl bare als auch --prefix-Form
```

```text
# Thema (optional, fuer Output-Filename im combined-Mode)
# Default: aus letztem gefundenen Slash-Command-Namen ableiten (Step 3)
```

## ## Step 2: JSONL-Datei finden

```text
# Slug + Projects-Dir (v3.2.2: zentralisiert in lib.sh)
# hash_project_dir() in lib.sh kapselt cygpath
# M3-Fix: $CLAUDE_PLUGIN_ROOT Guard
```

```text
# ⛔ v5.69.0: HIER STAND EIN RUECKFALL AUF DAS NEUESTE PROJEKT.
#    `[ ! -d "$PROJECTS_DIR" ] && PROJECTS_DIR=$(ls -td .../projects/*/ | head -1)`
#    Fehlte der Slug-Ordner, schob er IRGENDEIN anderes Projekt unter — und
#    der Sync haette den Chat eines FREMDEN PROJEKTS als Quelle genommen.
#    ⭐ Nachgestellt 10.09.2026: 25 Projekt-Ordner lagen dort, gewaehlt wurde
#       der nach Aenderungszeit juengste. `mind_transkript_pfad` faengt das
#       NICHT — sie rechnet ihren Slug selbst, kommt leer zurueck, und der
#       Rueckfall las dann aus dem fremden Ordner.
#
# ⛔ STREICHEN FUEGT KEIN VERHALTEN HINZU. Der Abbruch steht schon weiter
#    unten (`kein Session-JSONL` -> exit 1); der Rueckfall hat ihn nur
#    verhindert. ⭐ Ein ausgefallener Lauf hinterlaesst NICHTS, ein falsch
#    gespeister hinterlaesst FALSCHES.
#
# ⚠ Der Ausloeser ist KEIN kaputter Slug: `slug_regression.py` bestand alle
#   12 Faelle, und live trafen 3 von 3 echten Projekten. Es ist ein Projekt,
#   in dem NIE eine Sitzung lief — dort gibt es nichts zu syncen, und der
#   Abbruch ist die richtige Antwort, nicht die harte.
```

```text
  # ⚠ Ein Treffer, der NICHT aus der eigenen Kennung stammt (Hook-Vorgabe
  #   oder die alte cwd-Heuristik), ist ebenfalls ein Rueckfall — er kann
  #   richtig sein, belegt ist er nicht.
```

## ### Per-Command-Mode (v3.3.0 Default)

```text
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
```

```text
  # v3.3.1: ALL_COMMANDS Arg ans Python-Script weitergeben (Default "no" → Filter mind-*)
```

```text
  # Fallback: keine Commands gefunden -> ganze JSONL als 1 Range (mode=combined)
```

## ### Thema-Extraction (combined-Mode, fuer Filename)

```text
# Thema aus letztem Slash-Command ableiten falls nicht aus Args gesetzt
# v3.2.2: jq oder Python-Fallback statt grep — robust gegen lange JSON-Strings.
# Alter Pattern `[^<]+` matched ueber JSON-Inhalt hinaus (Bug aus Session 2026-05-29 Log 3).
```

```text
  # N1-Fix v3.2.2: Fallthrough zu Python wenn jq fehlte ODER leeres Resultat lieferte
```

## ## Step 4: Path-Setup + Python-Parser Heredoc

```text
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
```

## ### Loop ueber Ranges

```text
    # v3.3.0 per-command: HHMM-Prefix fuer Eindeutigkeit bei Mehrfach-Aufruf
    # TS-Format: 2026-05-30T14:23:45.123Z -> HHMM=1423
```

## ### Bilanz (im Chat, NICHT in Output-Datei)

```text
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
```

```text
# v3.3.1: Filter + Dedup Stats aus Python-Helper
```
