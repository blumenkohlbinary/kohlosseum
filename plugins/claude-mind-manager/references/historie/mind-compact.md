# mind-compact — Historie der Bloecke

Herleitung, Messungen und Vorfaelle hinter den bash-Bloecken von `skills/mind-compact/SKILL.md`, umgezogen aus den
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

## ## Step 1: JSONL finden (gleicher Code wie mind-session-log Step 2)

```text
# Slug + Projects-Dir (v3.2.2: zentralisiert in lib.sh)
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

## ## Step 2: Args parsen

```text
# v3.3.0: keine Args definiert (--save-to-claudemd in v3.3.1 geplant, siehe Step 6)
# Skill akzeptiert beliebige Args ohne Verarbeitung — defensive
```

## ## Step 3: Ausgelieferten Extraktor benutzen (v5.6.0 — KEIN Heredoc mehr)

```text
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
```

```text
# v5.6.0: ausgelieferte Datei statt /tmp-Heredoc (Befund 9)
```

```text
# Output-Datei fuer JSON-Zwischenergebnis — v5.126.0: je Sitzung im Projekt, nicht fest /tmp
# (kollidierte zwischen Sitzungen, Etappe 38 §2); Aufraeumen nach Step 5.
```

## ## Step 5: Vorlage rendern (Markdown-Block fuer User-Copy)

```text
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
```
