# bestands-pass — Historie der Bloecke

Herleitung, Messungen und Vorfaelle hinter den bash-Bloecken von `skills/bestands-pass/SKILL.md`, umgezogen aus den
Kommentaren der Bloecke (ZIEL 5, Etappe 58). ⛔ Lies das, BEVOR du einen Block aenderst oder wenn ein
Schritt rot ist — der Lauf selbst braucht es nicht. Je Abschnitt: die Ueberschrift, unter der der Block
stand, und die Kommentarzeilen woertlich.

## ### ⭐ DER LAUF — eine Datei, ein Agent, drei Gates (v5.78.0)

```text
# 0b ⛔ v5.123.0 (Etappe 33 §2): STUFE-3-KORREKTUREN aus frueheren Laeufen mitgeben — der Agent
#    sieht sie sonst nicht. Gemessen 17.09.2026: zum ZWEITEN Mal „die SUMME kann wachsen, waehrend"
#    → „waechst" in backup-usage.md, obwohl Etappe 24 §1 es korrigiert hatte. Merker je Datei:
#    <projekt>/.claude/archiv/<name>.stufe3.md, Zeilen `unantastbar: „<Wortlaut>"  # Datum, Grund`.
#    Jede Zeile geht WOERTLICH in den Auftrag: „NICHT anfassen, byteweise erhalten: „…"" —
#    und mind_verdichtung_pruefen ist rot, wenn ein Wortlaut im Ergebnis fehlt (Schritt 2).
#    Wer in Stufe 3 einen Satz korrigiert, traegt ihn dort ein — sonst korrigiert er ihn wieder.
```

```text
# 2  Das Gate — entscheidet, ob angewendet wird. Seine Ausgabe IST das Deponat (verdichten-<skill>.txt,
#    angehaengt); seit v5.125.0 traegt sie die Zeile „Vorher-Fassung  md5 <hash>  <pfad>" — der
#    Fingerabdruck der Fassung, gegen die Stufe 1/2 gemessen haben (Schritt 4 prueft ihn).
```

```text
# 4  Anwenden — NUR ueber mind_verdichtung_anwenden (v5.125.0, Etappe 37 §2). Es vergleicht die
#    Live-Datei mit dem md5 aus dem Deponat und kopiert nur bei Gleichheit; weicht er ab: rc 1
#    „Deponat veraltet — Datei seit dem Deponieren geaendert, neu verdichten", KEIN cp.
#    ⛔ Ritas Lauf 18.09.2026: .nachher.md von 22:51, CLAUDE.md danach zweimal geaendert (23:41,
#       `Auftraege/`-Zeile und ihre eigene `CLAUDE_PROJECT_DIR`-Korrektur); das Deponat sagte trotzdem
#       „✅ anwenden", weil Stufe 1/2 gegen die Fassung von 22:51 massen — ein cp haette den Fix
#       zurueckgedreht und die Zeile geloescht. Ein blankes `cp` steht hier deshalb nicht mehr.
```
