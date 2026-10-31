# Das Kontext-Tor — die gemeinsame Vorschrift für alle Commands

> **Rules, Dokus, CLAUDE.md und Memory existieren AUSSCHLIESSLICH für das, was
> Claude nicht ohnehin weiß.** Alles andere ist Kosten ohne Gegenwert — und
> verdrängt eine Regel, die trägt.

⛔ **Diese Datei steht EINMAL und wird von allen Commands nur GENANNT.** Sie in
jeden Command zu kopieren wäre genau das Duplikat, gegen das sie gebaut ist.
Dieselbe Bauform wie [bestands-pass.md](bestands-pass.md).

**Nutzer-Auftrag 30.08.2026, wörtlich:**

> *„überall es wird immer mehr, es darf nicht sein — führe was ein wo der
> Context durch läuft: ist es irgendwo schon, ist es selbsterklärend, ist es im
> Code schon erklärt. … in den Context-Dateien soll kein unwichtiger Müll
> stehen, er ist begrenzt, wertvoll und kostet Geld."*

Bis v5.25.0 arbeitete das Plugin nur **rückwärts** — es prüfte Bestände, die
schon da sind. Es gab **kein Tor beim Hineinschreiben.** Deshalb wächst alles.

---

## Die Pruefliste A1–D10

Nutzer 29.10.2026: *„mind cleaner soll autonom arbeiten und er soll die neuen fragen auch drin haben“* —
die Pruefliste A1–D10 ersetzt die acht Fragen vom 30.08.2026. Die alten gehen darin auf (rechte Spalte).

| # | Frage | wer beantwortet sie | mechanisch? | frueher |
|---|---|---|---|---|
| **A1** | Fehlt es sonst? (Code, andere Datei, eigenes Wissen — und stimmt das Wissen fuer DIESES System?) | `cleaner_tor` (Extremfall) · `cleaner_duplikate` · `cleaner_aussagen --code` | ⚠ teilweise | A1, B1, B2 |
| **A2** | Bringt es spuerbar und oft etwas? | Urteil | ✗ | — |
| **A3** | Geht es ohne nicht richtig? | Urteil | ✗ | — |
| **B4** | Jede Sitzung (Rule/CLAUDE.md) oder nur manchmal (Command/`paths:`)? | `cleaner_einordnung` · `cleaner_grenzen` · D1 | ⚠ teilweise | B3 |
| **B5** | Anweisung oder Beleg (→ Archiv)? | `cleaner_tor` | ⚠ teilweise | A3 |
| **B6** | Muss es ohne Ausnahme gelten (→ Hook/Test)? | Urteil | ✗ | — |
| **C7** | Hart formuliert, Verbot mit Alternative | `cleaner_tor` (C7 weich, C7b unspezifisch) | ✅ / ⚠ | C1, C2 |
| **C8** | Kein Widerspruch zum Bestand | `cleaner_duplikate --widersprueche` | ✅ ja | — |
| **C9** | Workaround mit Messdatum und Ablaufzeichen | Urteil | ✗ | — |
| **W1** | Wohin gehoert es? — aus einer Korrektur gelernt, nur hier → Memory · persoenliche Vorliebe → `~/.claude/CLAUDE.md` · Auftrag/Plan/Zwischenstand → `.md` im Projekt · Themenwissen ausserhalb des Projekts → `docs/wissen/<thema>.md` + EINE Zeile in `CLAUDE.md` (v5.175.0; Arbeitsmaterial nie) · Aussage ueber EINE Code-Stelle → Kommentar dort (`file-handling.md` → Context files, v5.172.0) | Urteil · Code-Stelle: `cleaner_einordnung --wohin` (`⭐CODE-KOMMENTAR?`) | ⚠ nur die Code-Stelle | — |
| **D10** | Deckel — wer anlegt, zahlt aus dem Bestand | `mind_kontext_bilanz --vergleichen` · `cleaner_tor --memory` | ✅ ja | — |
| **R1** | Beim Aufraeumen: stimmt es noch? | `cleaner_tor` · `cleaner_belege` | ⚠ teilweise | A2 |

⛔ **Neue Detektoren nur nach Messung** (Messung im Entwicklungs-Workspace, 29.10.2026, 56 Context-Dateien): C9 7 Kandidaten,
0 echt · „Verbot ohne Alternative“ 265 Kandidaten, schon die ersten trugen ihre Alternative · B6 0. Diese drei
bleiben Urteile — das Tor erzwingt die Antwort, es gibt sie nicht.
⭐ **Zeilenweise:** `--datei` listet die Treffer je Frage UND je Zeile (`── je Zeile ──`); eine Zeile mit zwei
Treffern steht einmal, mit beiden Kuerzeln.

⛔ **A1 (Code, andere Datei), B4, C8 und D10 werden von `cleaner_tor` NICHT beantwortet, sondern GENANNT.** Die
Klasse `instrument-nachgebaut` steht mit **7** Vorkommen im Debug-Ordner, Bilanz
~250 · 11 · 9 · 7 Fehltreffer — **kein einziger Nachbau war besser als das
Original** (`werkzeuge-zuerst.md`).

---

## Zwei Richtungen — beide oder keine

| Richtung | wann | Wirkung |
|---|---|---|
| **VORWÄRTS** | vor jedem `ADD` / `NEW_FILE` | ohne Quittung ist der Lauf ein **Teilsync** |
| **RÜCKWÄRTS** | `/mind-cleaner --audit`, ganzer Bestand | Kandidatenliste für den Bericht |

⛔ **Nur vorwärts ließe den Altbestand stehen; nur rückwärts ist der Zustand von
heute, der nachweislich wächst.**

```bash
# VORWAERTS — vor der Ergaenzung
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_tor.py" --text "<die neue Zeile>"

# RUECKWAERTS — ueber eine bestehende Context-Datei
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_tor.py" --datei "<datei.md>"
```

## Die Quittung

```
tor=<datei>:A1/A2/A3:B4/B5/B6:C7/C8/C9:D10
   (die Skills haengen :D1=… und seit v5.172.0 :W1=<hier>/<memory>/<vorliebe>/<auftrag>/<wissen>/<code> an)
z.B.  tor=CLAUDE.md:fehlt/oft/noetig:jede/regel/nein:hart/frei/n-a:gezahlt
```

⛔ **Ein `ADD` ohne Tor-Quittung macht den Lauf zum Teilsync** — dieselbe
Kopplung wie Bestands-Pass (v5.22.0) und Schritt-Quittung (v5.25.0). Ohne sie
wäre das Verfahren wieder das, was `PFLICHT` **67 mal** war: Prosa im
Ausfallpfad.

---

## ⭐ Warum C1 die ⚠-Vorbehalte NICHT frisst

Der Auftrag lautete *„alle Regeln hart formuliert, keine Ausnahmen"*. **Ich habe
dem widersprochen, und der Widerspruch steht im Code.**

**Hart formuliert und ehrlich formuliert sind nicht dasselbe.** Dieser Bestand
ist voll von Sätzen wie *„⚠ Beide Schwellen sind GERATEN, nicht gemessen"* —
das sind **keine weichen Regeln**, sondern **harte Aussagen über schwache
Belege**. Sie sind der Grund, warum der Bestand etwas taugt.

| ⛔ weich — wird gemeldet | ✅ hart über Unsicherheit — NIE gemeldet |
|---|---|
| *„man sollte vorher sichern"* | *„sichern. ⚠ Ob es reicht, ist ungemessen."* |
| *„möglichst nicht löschen"* | *„NIE löschen."* |

**Der Test ist die HANDLUNG, nicht der Ton:** Weiß ich nach dem Satz, was ich
**tun** soll? Dann ist er hart, auch mit Vorbehalt.

⛔ **Das Zeichen ⛔ befreit ABSICHTLICH NICHT.** *„⛔ möglichst nicht löschen"*
ist der gemischte Fall und gehört gehärtet.

⭐ **Und der NEBENSATZ ist keine Regel.** Im deutschen Hauptsatz steht das
Modalverb an zweiter Stelle (*„man sollte VORHER sichern"*), im Nebensatz am
Ende (*„den Befund, den der Agent finden sollte"*). **Gemessen:** ohne diese
Unterscheidung waren **beide** C1-Treffer im ganzen Skill-Bestand Fehlalarme —
zweimal derselbe Satz.

---

## ⛔ Was das Tor NICHT kann

- **A1, A2, A3, B6, C7b und C9 bleiben Urteile.** Ob ein Modell etwas weiß, steht in keiner
  Datei. Das Tor erzwingt eine **Antwort**, nicht die richtige — dieselbe
  Mechanik wie die Agent-Quittung (v5.19.0): sie zwingt keinen Agenten zu
  arbeiten, sie macht sein **Fehlen** sichtbar. Das hat gereicht.
- **Es verhindert kein Wachstum.** Es macht jedes `ADD` begründungspflichtig.
- **Es misst Form, nicht Bedeutung.** Jeder Treffer ist ein **Kandidat**; die
  Liste sieht ein Mensch durch — wie beim COMMAND-Vorschlag aus `mind-cleaner`
  Step 3.
- ⚠ **Ob weniger Kontext besser befolgt wird, ist für DIESEN Bestand nicht
  belegt.** Die Richtung ist es (SFEIR, 20 gestapelte Regeln: 96 % → 60,4 %),
  der Betrag nicht.

---

## Der Memory-Deckel — nur für `/mind-memory`

```bash
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_tor.py" --memory "<memory-dir>"
```

**Nutzer-Auftrag:** *„keine Memory-Dateien so viele, dass diese nicht mehr
geladen werden, keine Ausnahmen."*

⛔ **„Wird nicht mehr geladen" ist NICHT messbar — gemessen 30.08.2026.**
139 Topic-Dateien über 14 Projekte, **0** auffindbare Abrufe in den Transkripten
— aber die **Positivkontrolle fällt durch**: `claudeMd`, `auto-memory` und
`Contents of` kommen dort **ebenfalls null mal** vor, obwohl sie nachweislich
eingespielt werden. Der eingespielte Kontext steht gar nicht im Transkript.

**Ein Deckel auf beobachteten Ladungen wäre ein Instrument, das nichts misst** —
die häufigste Fehlerklasse dieses Projekts (**71** Vorkommen im Debug-Ordner).

**Er stützt sich stattdessen auf die belegte Grenze** (wörtlich in
`claude.exe` 2.1.237): *„Return a list of filenames … **(up to 5)**. Only
include memories … **based on their name and description**."*

| Dateien | Ampel | Folge |
|---|---|---|
| bis 15 | grün | in ~3 Anfragen ist alles einmal erreichbar |
| 16–25 | gelb | Meldung mit den schwächsten `description` |
| über 25 | **ROT** | ⛔ `ADD` nur gegen Zusammenführung — eine rein, eine raus |

⛔ **Die drei Zahlen sind GESETZT, nicht gemessen**, und deshalb Regler
(`MIND_MEMORY_MAX_GRUEN` / `_MAX_GELB` / `_DESC_MIN` / `_DESC_MAX`) — dieselbe
Begründung wie bei den drei v5.5.0-Reglern: *eine hartkodierte Zahl aus einer
unbestätigten Quelle ist eine Behauptung.* ⛔ **Das Plugin setzt sie nie selbst**
(claude-mem #2836).

⭐ **Der wirksamere Hebel ist NICHT die Dateizahl, sondern die `description`** —
sie ist der **einzige** Zugang des Auswählers, er sieht nie den Inhalt. Deshalb
prüft der Deckel sie zuerst.

⛔ **Vor einer Zusammenführung sichern**, danach `$CLAUDE_PLUGIN_ROOT/references/memory_gates.py` —
Zusammenführen **löscht eine Datei** (`backup-usage.md`).

---

## ⚠ Die Falle beim Bauen: zwei Module, ein stdout-Puffer

`sys.stdout = io.TextIOWrapper(sys.stdout.buffer, …)` am Modulkopf war in drei
Werkzeugen **bedingungslos**. Wer stdout selbst einhüllt und dann importiert,
hängt **zwei** Wrapper an denselben Puffer; wird einer eingesammelt, schließt er
den Puffer des anderen, und jedes weitere `print()` bricht mit
`I/O operation on closed file` — **nach** der letzten erfolgreichen Ausgabe,
also an der falschen Stelle. Zweimal am 30.08.2026 gemessen, seither idempotent
(`cleaner_leitplanke`, `cleaner_stichprobe`, `cleaner_wirkung`).
Prüffall: `tests/test_kontext_tor.sh`, Fall 8.
