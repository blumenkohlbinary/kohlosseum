# Prüfsammlungen

**Am gebauten Paket fahren, nicht am Quellbaum** (`~/.claude/rules/fertig-heisst-fertig.md` §1):

> ⛔ **Bis v5.7.5 tat das keine dieser Sammlungen.** Drei von fünf setzten `CLAUDE_PLUGIN_ROOT`
> per `export` hart auf den Quellbaum und **überschrieben damit, was der Aufrufer mitgab** —
> die Anweisung darunter war also wirkungslos, und „am gebauten Paket geprüft" war eine
> unbelegte Behauptung. Heute steht dort `${CLAUDE_PLUGIN_ROOT:-…}`.
>
> **Die Gegenprobe, die das belegt** — mit unerreichbarer Wurzel *müssen* sie scheitern:
>
> ```bash
> CLAUDE_PLUGIN_ROOT=/gibt/es/nicht bash tests/test_precompact.sh && echo "ROT: Wurzel wird ignoriert"
> ```

```bash
export CLAUDE_PLUGIN_ROOT=~/.claude/plugins/cache/kohlosseum/claude-mind-manager/<version>
CLAUDE_PROJECT_DIR="<Workspace Claude Mind Manager>" bash "$CLAUDE_PLUGIN_ROOT/tests/alle.sh"
```

⛔ **`CLAUDE_PROJECT_DIR` ist der WORKSPACE** (`Claude Mind Manager`, mit `tools/`, `Learnings/`,
`.claude/archiv/`) — nicht das Plugin-Verzeichnis: mit dem Plugin-Pfad ueberspringen
`test_bestandspass.sh` und `test_verdichten.sh` je einen Fall still, und `test_d1_wohin.py`
meldet seit v5.114.0 rc 3 „nicht messbar" statt gruen.
⭐ **Seit v5.114.0 liegt JEDES Fixture unter einem Pfad MIT Leerzeichen** (`<Temp>/Mind Test <pid>/`,
`tests/lib_test.sh`, von jeder Sammlung gesourct): v5.113.0 war 75/75 gruen und brach an jedem
echten Projektpfad, weil kein Fixture eines hatte.

⛔ **Seit v5.13.0 ist das der EINZIGE richtige Aufruf.** Hier stand bis v5.12.0 eine Liste
von fünf einzelnen Aufrufen — wer sie abarbeitete, hatte danach das Gefühl, alles geprüft zu
haben. Am 23.08.2026 stellte sich heraus, dass `test_precompact.py` in keinem einzigen Lauf
je dabei war. **Die Liste in dieser README war Teil des Fehlers**, nicht seine Behebung.

`alle.sh` **findet** die Sammlungen (`find`, keine gepflegte Liste), fährt jede und meldet
`gefunden / gefahren / grün`. Weicht die Zählung ab, bricht er mit Rückgabe 2 ab.

Zwei Werkzeuge prüfen sich selbst und laufen **nicht** über `alle.sh`:

```bash
python "$CLAUDE_PLUGIN_ROOT/references/claudemd_pipeline.py" --selbsttest
python "$CLAUDE_PLUGIN_ROOT/references/slug_regression.py" --live
```

| Datei | Prüffälle | Gegenstand |
|---|---|---|
| `test_teil1.sh` | 15 | Token-Schwellen, Mahnung, Zwang, `lib.sh`-Ausfall |
| `test_debug.sh` | 12 | Debug-Ordner, Wiederholungserkennung, Zeilenenden |
| `test_precompact.sh` | 11 | Chat-Rettung, Arbeitsstand, `sync-stand`, Fail-open |
| `test_toolrule.sh` | 7 | Tool→Rule-Nachweis, auch für Werkzeuge im Wurzelverzeichnis |
| `test_compact_faellig.sh` | 18 | ⛔ `COMPACT-FAELLIG` ist **entfallen** (v5.65.0) — die Sammlung sichert zu, dass er weg ist, und hält fest, wohin jede alte Zusicherung gegangen ist |
| `test_keine_panik.sh` | 6 | kein Hook darf behaupten, das Fenster sei voll |
| `test_skill_einstieg.py` | 6 | nur echte `SKILL.md`/`agents/`/`commands/` gelten als Einstieg |
| `test_ladeprotokoll.sh` | — | `instructions-loaded.sh`, auch bei unbekanntem Schema |
| `test_lib_v511.sh` | — | die `lib.sh`-Funktionen aus v5.11.0 |
| `test_fremdklon.py` | — | Fremdklon-Erkennung, mit Negativkontrolle |
| **`test_sampler_filter.py`** | 16 | **NEU v5.13.0** — die Kategorie-Filter gegen FESTE Sätze |
| **`test_zeilenenden.sh`** | 27 | **NEU v5.13.0** — CRLF-Anteil, Snapshot-Zweige, Vergleichszahl |
| **`test_pfadklassen.py`** | 16 | **NEU v5.13.0** — Aufzählungen sind keine toten Pfade |
| **`test_quittung.sh`** | 20 | **NEU v5.14.0** — Agent-Quittung: leer gegen STUMM |
| **`test_negativfall.sh`** | 12 | **NEU v5.14.0** — kann die Sperre selbst rot werden? |
| **`test_lib_ungedeckt.sh`** | 20 | **NEU v5.14.0** — die drei Funktionen ohne Prueffall |
| **`test_kontext_bilanz.sh`** | 23 | **NEU v5.22.0** — `mind_kontext_bilanz`: Negativkontrolle +1000 B, Topic-Dateien zaehlen NICHT mit, CRLF, fehlender Umbruch |
| `test_precompact.py` | — | Hook gegen ein echtes Transkript |

⚠ **`test_precompact.py` wählt sein Transkript als `kandidaten[1]`** — das zweitkleinste
`.jsonl` im Projektordner, je nach Sitzungsbestand also ein anderes. Am 23.08.2026 war sie
deshalb erst rot und Minuten später grün, ohne dass sich eine Zeile geändert hatte.
**Sie kann einen Defekt anzeigen, aber nie ausschließen.** Dafür gibt es seit v5.13.0
`test_sampler_filter.py` mit festen Eingaben. Beide bleiben: die eine prüft den Hook im
Ganzen, die andere den Filter.

## ⛔ Jede Sammlung enthält eine Gegenprobe, die scheitern KANN

Das ist keine Zierde. Eine Messung ohne Negativkontrolle liefert weiter Zahlen und greift am
Fehler vorbei — siehe `~/.claude/rules/messung-vor-glauben.md` §1. Konkret hier:

- **`test_teil1.sh`** sabotiert `lib.sh` und verlangt, dass der Schuld-Zwang **trotzdem** blockt.
- **`test_precompact.sh`** sabotiert **nur** die Übergabe-Marke und verlangt, dass Chat-Rettung,
  Auftrag und `OPEN` trotzdem entstehen.
- **`test_toolrule.sh`** fährt einen blinden Stub gegen denselben Fall und verlangt, dass er
  **durchfällt**. Ohne diesen Lauf wäre nicht belegt, dass die übrigen Zusicherungen überhaupt
  etwas messen — und genau das war der Defekt, den diese Sammlung fängt: der Wurzel-Fix von
  v5.7.1 stand nur im **Kommentar**, die Variable wurde gesammelt und nie benutzt.
- **`test_debug.sh`** prüft, dass zwei **verschiedene** Klassen **kein** `WIEDERHOLT` erzeugen —
  ohne diesen Fall wäre die Wiederholungserkennung nicht von „meldet immer WIEDERHOLT" zu
  unterscheiden.

## ⛔ Ein Prüffall greppt die MARKE, nie den Satz

**Gemessen 26.09.2026 am Paket 5.135.0:** von **81** Prüfsammlungen greppen **33** mindestens
einmal einen deutschen Wortlaut statt einer maschinenlesbaren Marke — **132 von 945**
Suchmustern, also **14 %**. In Etappe 46 sind daran **zwei** Fälle rot geworden, weil der
FORMAL-Satz um seinen Grund erweitert wurde (`… — nachgetippt, kein prüfbares Artefakt`).
Die Zusicherung war unverändert richtig; nur ihr Suchmuster hing am Satz.

**Also beim Schreiben eines neuen Falls:**

| ✅ greppen | ⛔ nicht greppen |
|---|---|
| `^  FORMAL=4$` · `FORMAL_SKILLS=` · `FEHLT=` · `UNGEPRUEFT=` · `TEILABDECKUNG:` | `(kein prüfbares Artefakt)` · `(= noch nicht quittiert, NICHT tot)` · `(kein Kopf-Block — Bilanz über die ganze Datei…)` |
| JSON-Schlüssel, Zahlen, Rückgabewerte, Pfade | ganze Sätze, Gedankenstriche, Klammer-Begründungen |

⭐ **Die Trennlinie in einem Satz:** ein **Satz** ist für Menschen da und **darf sich ändern** —
eine **Marke** ist für Leser da und **darf es nicht**. Wer den Satz greppt, macht jede
Präzisierung der Meldung zu einem Fehlalarm — und ein Fehlalarm, der oft genug kommt, wird
irgendwann durch Anpassen des Musters statt durch Nachdenken beantwortet.

⛔ **Die 132 vorhandenen Muster werden NICHT auf Verdacht umgebaut.** Ein Massenumbau über 33
Sammlungen wäre ein Schnitt quer durch alle Zusicherungen, ohne dass ein einziger davon
gemessen falsch ist — und er würde genau die Fälle anfassen, die heute halten.
⭐ **Es gilt eine RATSCHE:** umgestellt wird ein Muster **dann, wenn es rot wird**, weil sich
der Satz geändert hat. Wer es dann anpasst, stellt es auf die Marke um statt auf den neuen
Satz. So wandert der Bestand über die Zeit, ohne dass ihn jemand in einem Zug zerschneidet.

⚠ **Grenze der Messung, die dazugehört:** unterschieden wird die **Form** des Suchmusters
(drei zusammenhängende Wörter Prosa oder ein typografisches Zeichen der Meldungssprache),
nicht seine **Absicht**. Ein Muster kann formal Prosa sein und trotzdem genau richtig — etwa
ein wörtlich vorgeschriebener Nutzer-Satz. Die 132 sind eine **Obergrenze**, kein Urteil.

⭐ **Die Marken selbst sind ADDITIV eingeführt** (v5.136.0): kein vorhandener Satz hat sich um
ein Byte geändert, deshalb blieben alle 79 Fundstellen grün, ohne angefasst zu werden.
`test_marken.sh` §5 hält den Rückfall fest (ein Text ohne Marke bleibt lesbar), §6 hält
fest, dass die alten Sätze noch wörtlich dastehen — wer eine Marke einbaut, ist versucht, die
Prosa danach „aufzuräumen", und genau das wäre der Bruch.

⚠ **`test_marken.sh` erhöht die Messung selbst** — mit ihr sind es **34 von 82**
Sammlungen und **133 von 961** Mustern. Die eine neue Wortlaut-Stelle ist §6, die die
alten Sätze ABSICHTLICH greppt. Wer die Zahl nachmisst, sieht sonst einen Zuwachs und
hält ihn für einen Rückfall.

## ⛔ Was hier NICHT hineingehört

**Nichts, was `~/.claude/settings.json` oder Umgebungsvariablen schreibt.** Ein Plugin, das
seine eigenen Regler setzt, macht genau den Fehler von `claude-mem` (#2836): dort wurden so
75 Erinnerungen unsichtbar. Die Schwellen setzt der Mensch von Hand.

Der Beleg der Schwellen-Kalibrierung vom 21.08.2026 liegt deshalb im Workspace unter
`Debug/messungen/`, nicht im ausgelieferten Paket.
