# Der Bestands-Pass — jeder Skill sieht sich seinen eigenen Bestand an

> Gemeinsame Vorschrift für `mind-claudemd`, `mind-memory`, `mind-rules`, `mind-files`
> und `mind-update`. Jeder Skill nennt in seinem eigenen Block nur noch **seinen Bereich**
> und zeigt hierher. **NEU v5.22.0.**

## ⛔ Wozu

**Nutzer-Auftrag 27.08.2026:** *„die anderen skills sollen von vorne rein sauber arbeiten,
ähnlich wie der mind cleaner — nicht immer mehr und mehr. Auch gucken: braucht man das,
kann das weg, steht das schon woanders."*

Der Anlass ist gemessen: `/mind-all` ist eine **Anhänge-Maschine**. Fünf Skills tragen nach,
keiner sieht je zurück. An **einem Tag** wuchs der immer geladene Kontext eines Projekts um
**+19 460 B (+21 %)** auf 2 601 Zeilen und 138 Anweisungen. `references/budget-thresholds.md`
nennt **>400 Zeilen** als die Schwelle, ab der die Befolgung auf 71 % fällt, und **~100–150**
als die Zahl der Anweisungen, die ein Modell verlässlich hält.

⭐ **Bei ausgeschöpftem Budget ist Anhängen kein Zuwachs mehr, sondern ein TAUSCH** — jede
neue Anweisung verdrängt eine alte. Der Tausch wurde bisher nirgends benannt.

Das Gegengewicht `/mind-cleaner` steht **bewusst außerhalb der Kette** und ist **nicht
autonom** (Nutzer-Entscheidung 24.08.2026). Es kann also nicht der Weg sein, auf dem der
Bestand routinemäßig geprüft wird. Deshalb prüft ihn jeder Skill selbst — klein, regelmäßig,
und **ohne zu handeln**.

## ⛔ Die Grenze — am 10.09.2026 verschoben, und zwar um genau EINE Klasse

> **Nutzer-Entscheidung, wörtlich:** *„alle dürfen kürzen nur mind cleaner macht es tiefer
> und genauer wichtig es müssen richtige kriterien ausgearbeitet werden was bleiben soll"*

⛔ **Hier stand bis dahin: „Der Pass MELDET. Er schneidet nicht, verschiebt nicht, löscht
nicht."** Der Satz gilt weiter — für alles, was unten nicht ausdrücklich erlaubt ist.

### ⭐ Was ein Skill kürzen darf, und warum nur das

Gemessen 10.09.2026 an beschriftetem Material, das niemand dafür präpariert hat
(`docs/plugin/d1-trefferquote.md`). D1 hat drei Klassen; **eine** besteht ihre
Positivkontrolle:

```
BREMSE     Leitplanke 34 %  gegen Command-Volltext  7 %   Faktor 4,9  -> trägt
ANLEITUNG  Volltext   26 %  gegen Leitplanke       25 %   1 Punkt     -> trägt NICHT
BELEG      Archiv     12 %  gegen Volltext         13 %   −1 Punkt    -> VERKEHRT HERUM
```

⛔ **Deshalb wird NICHT nach Klasse umgezogen, sondern nach SUBTRAKTION:**

> **Was `BREMSE` markiert, BLEIBT. Der Rest des Absatzes darf gehen.**

⭐ **Das ist der ganze Trick und der Grund, warum überhaupt gehandelt werden darf:** man
muss nur der Klasse trauen, die bestanden hat. Ob der Rest „ein Beleg" oder „eine
Anleitung" ist, wird gar nicht behauptet — er ist schlicht **nicht die Bremse**.

| erlaubt | ⛔ verboten |
|---|---|
| einen als **`TEILBAR`** markierten Absatz teilen: Bremse bleibt, Rest ins Archiv | umziehen, **weil** D1 den Absatz `ANLEITUNG` nennt |
| dabei den **Doppelzeiger** setzen — Command **und** Pfad | umziehen, **weil** D1 ihn `BELEG` nennt |
| die Entlastung in **Bytes** melden | `UNBESTIMMT` anfassen — der Ort bleibt |

⚠ **Der teuerste Fehlgriff, den diese Regel verhindert:** D1 nennt **25 %** der
Leitplanken-Absätze `ANLEITUNG`, also *„gehört in den Command"*. Genau die hat der Nutzer
selbst als Leitplanke stehengelassen. **Eine Hand, die nach `ANLEITUNG` umzieht, räumt
seine Bremsen aus.**

⛔ **Der tiefe Schnitt bleibt `/mind-cleaner`**, dessen Nicht-Autonomie unberührt ist
(Bericht → OK → Plan → OK, 24.08.2026). Was die fünf dürfen, ist der flache Schnitt an
einem Absatz, den ein **gedecktes** Merkmal ausweist.

⭐ **Das Erfolgsmaß ist neu:** nicht die Zeilenzahl der Wurzeldatei, sondern der **immer
ladende Anteil in BYTES**. Ein Lauf, der 40 Zeilen von einer immer-ladenden Datei in eine
andere immer-ladende schiebt, hat **0** erreicht — und meldet das mit der Zahl.
Das Umzugs-Gate `ENTLASTUNG` (v5.71.0) prüft genau das.

---

## ⭐ VERDICHTEN — der zweite Weg, und er braucht KEINE Schutzliste

> **Nutzer-Auftrag 10.09.2026:** Platz entsteht nicht nur durch Wegräumen, sondern durch
> **Verdichten** und **Zusammenführen** — ohne dass eine Einzelinformation verschwindet.

⛔ **Die naheliegende Bauform ist gemessen ausgeschlossen.** Man könnte vorher
klassifizieren, was stehenbleiben muss. Gemessen 10.09.2026
(`docs/plugin/d1-trefferquote.md`): eine Schutzliste auf `BREMSE` **übersieht 40 %** der
Leitplanken-Absätze, 28 % davon tragen **kein Formmerkmal** und sind über die Form
grundsätzlich nicht erreichbar.

> ⭐ **Deshalb nicht vorher KLASSIFIZIEREN, sondern hinterher NACHWEISEN.**
> Verdichten läuft frei. Danach misst ein Instrument, ob jede Einzelaussage des Originals
> im Ergebnis wiederzufinden ist.

⭐ **Der Unterschied ist grundsätzlich:** eine Schutzliste muss **vollständig** sein — bei
60 % Reichweite unmöglich. Eine Nachweisprobe muss nur **Marken** finden, die eine
Umformulierung überleben. Genau darauf ist das Gate gebaut: Code-Spans, Zahlen mit
Einheit, ALLCAPS-Namen. ⛔ Fließtext-Substantive **bewusst nicht** — die verschwinden beim
Umschreiben, und das Werkzeug war deswegen schon zweimal blind.

### Der Pflichtschritt

```bash
python "$CLAUDE_PLUGIN_ROOT/references/doc-templates/coverage_gate.py" \
       <ergebnis.md> <original.md>
```

⛔ **Diesen Pfad benutzen, nicht `tools/coverage_gate.py`.** Die Datei unter `tools/` ist
die **installierte Kopie** in einem Nutzerprojekt — `mind-files` legt sie dort an, wenn das
Projekt eine bekommt. ⚠ Ein Skill darf sich nicht darauf verlassen, dass sie existiert;
die **Vorlage im Plugin** ist immer da. Beide sind heute bytegleich, und **wer eine von
beiden ändert, ändert die andere mit** — sonst widersprechen sich zwei Messungen.

| Rückgabe | heißt |
|---|---|
| **0** | alle Prüfpunkte belegt |
| **1** | offene Punkte, **einzeln gelistet** |
| ⛔ **3** | **Messung UNGÜLTIG** — die Negativkontrolle im Lauf hat angeschlagen. Kein bestandenes Gate, kein Ergebnis |

⛔ **KEINE SCHWELLE. 100 % oder rot.** „Ohne Verlust" ist binär. Es gibt keine Quote, ab
der ein Verlust in Ordnung wäre.
⛔ **Ein offener Punkt wird EINZELN angesehen, nie pauschal nachgetragen.** Die
Stichwortwahl ist heuristisch — ein Punkt kann als offen erscheinen, obwohl er sinngemäß
übertragen wurde. Deshalb listet das Gate sie einzeln.

### ⭐ Die Zusicherung hat DREI Stufen — und Stufe 1 allein reicht nicht

⛔ **Gemessen 10.09.2026** (`docs/plugin/coverage-empfindlichkeit.md`): eine
**markenerhaltende** Verdichtung entfernte **34 %** von `werkzeuge-zuerst.md` — und das
Gate meldete **100 %**. Das ist kein Fehler des Gates; es ist die Bauart einer guten
Verdichtung. Sie behält genau das, wonach das Gate sucht.

| Stufe | wer bürgt | Aussage |
|---|---|---|
| **1 maschinell, hart** | `coverage_gate.py` | keine **markierte** Aussage ist verschwunden. ⛔ 100 % oder rot |
| **2 maschinell, ausweisend** | derselbe Aufruf, Zeile `AUSWEIS:` | **wieviel markenfreier Text entfernt wurde** — die Menge, die **kein** Instrument geprüft hat |
| **3 menschlich, PFLICHT** | der Leser | der ganze Wort-Diff wird **gelesen**. ⛔ Ein Lauf ohne Stufe 3 wendet NICHT an — er legt das Ergebnis zur Durchsicht ab (Anton, 11.09.2026) |

**Pflichtzeile im Bericht jedes Verdichtungslaufs:**

```
coverage 78/78 (100 %)   ·   markenfrei entfernt: 3053 B von 4847 B (63,0 %)
⚠ Diese 3053 B hat kein Instrument geprueft.
```

⛔ **Stufe 2 ist KEIN Gate und wird nie eins.** Markenfreien Text zu entfernen ist genau
das, was eine gute Verdichtung **tun soll** — ein Schwellwert darauf würde jeden
gelungenen Lauf anschwärzen. Sie **meldet eine Zahl**, sie urteilt nicht. Dieselbe Doktrin
wie `cleaner_leitplanke.py`: Kandidaten, kein Urteil.

⭐ **Das Vorbild steht im Haus: die Deckel-Schuld.** Man darf anlegen — man muss es
**ausweisen**. Hier: man darf verdichten — man muss ausweisen, **wieviel davon ungeprüft
blieb**. Der Nutzer hat „alle dürfen kürzen" gesagt; er hat nicht gesagt „ohne
Rechenschaft".

### ⭐ DER LAUF — eine Datei, ein Agent, drei Gates (v5.78.0)

**Kalibriert 11.09.2026** an `manager-chats.md` (`docs/plugin/verdichten-kalibrierung.md`):
Agent −5,65 %, Marker exakt, Stufe 3 sauber. Antons Handfassung (−10,7 %) ist unter diesem
Gate **rot** — 2 ⛔, 5 ⚠, 3 Verbote verloren. Ein Instrument, das die Referenz des
Auftraggebers anschwärzt, weil sie es verdient, ist eines, dem man trauen kann.

```bash
# 0  Snapshot — der Rückweg, BEVOR irgendetwas passiert
SNAP=$(mind_snapshot "$PROJ" "pre-verdichten") || exit 1
VORHER=$(mind_kontext_bilanz "$PROJ" | sed -n 's/.*BYTES=\([0-9]*\).*/\1/p')

# 1  EIN Agent je Datei: model sonnet, Denkstufe low, EIN Auftrag, die Datei benannt.
#    ⛔ Höchstens 2 gleichzeitig. Rückgabe: <ergebnis>.md und <bericht>.md im Scratchpad.
#    Der Auftrag trägt WÖRTLICH die Regeln aus dem Kasten unten — der Agent sieht nichts.

# 2  Das Gate — entscheidet, ob angewendet wird
mind_verdichtung_pruefen "$DATEI" "$ERGEBNIS" "$BERICHT" || { echo "verworfen"; exit 0; }

# 3  ⛔ STUFE 3: den Wort-Diff GANZ lesen (git diff --no-index --word-diff). Ohne Leser:
#    NICHT anwenden — Ergebnis, Bericht und Diff ablegen, Pfad melden, hier aufhören.
# 4  Anwenden, dann das ERFOLGSMASS — und zurück, wenn es nicht kleiner wurde
cp "$ERGEBNIS" "$DATEI"
NACHHER=$(mind_kontext_bilanz "$PROJ" | sed -n 's/.*BYTES=\([0-9]*\).*/\1/p')
if [ "$NACHHER" -ge "$VORHER" ]; then
  echo "⛔ Dauerkontext nicht kleiner ($VORHER -> $NACHHER B) — Snapshot zurück. Verschoben statt gekürzt."
  python tools/rollback.py restore "$(basename "$SNAP")"
fi
```

**Der Kasten für den Agenten — wörtlich in den Auftrag:**

| darf | darf NICHT |
|---|---|
| Sätze umformulieren und kürzen — **auch** in ⛔/⚠/⭐-Absätzen | Zahlen, Daten, Code-Spans, Pfade, Nutzer-Zitate ändern |
| Doppelungen zusammenziehen | ALLCAPS-Verbote (NIE, NUR, MUSS, KEIN …) entfernen oder klein schreiben |
| Herleitungen auf Datum + Zahl eindampfen | die **Anzahl** von ⛔ ⚠ ⭐ verringern — er zählt am Ende nach |
| einen ⛔/⚠/⭐-Absatz ganz entfernen, wenn er überholt ist — **nur benannt:** `entfernt: ⛔ „…"` im Bericht | einen ⛔-Absatz in einen Nachbarn einschmelzen |
| ⭐ **benannte Überholt-Kandidaten** des Aufrufers entfernen (aus dem Deckel-Ausweis, aus `cleaner_belege.py`) — benannt | raten, was überholt ist. ⛔ Was nur in einer **anderen** Datei steht, kann er nicht wissen — Kalibrierung: „sync-Rolle ist ABSPRACHE" war laut `rollen.md` hinfällig, der Agent sah einen Absatz mit eigener Aussage und ließ ihn, zu Recht |

⛔ **Das Kriterium für eine Bremse ist das ⛔ am Absatzanfang** — nicht NUR/KEIN im Absatz.
Die Wörter stehen in Prosa ständig; der erste Agent hielt daran 19 freie Absätze für Bremsen
und erreichte 0,2 %.
⛔ **Gezählt wird jedes ⛔/⚠/⭐-ZEICHEN, auch in Codeblöcken und Tabellen** — nicht nur
Absätze. Jedes entfernte wird benannt, und **eine Benennung zählt nur, wenn ihr Zitat im Ergebnis
nicht mehr vorkommt** (v5.79.0). Gemessen am ersten echten Lauf (`hooks.md`, 11.09.2026): drei
⛔ in einem Codeblock unbenannt → rot; zwei ⚠ als entfernt benannt, aber nur umformuliert →
das alte Gate war zufrieden.

⭐ **Der Ertrag hängt am AUFRUFER, nicht am Agenten.** Kalibrierung ohne benannte
Kandidaten: −5,65 %. `hooks.md` mit acht benannten Überholt-Kandidaten: −14,9 %,
`env-vars.md` mit sieben: −16,3 % (11.09.2026). Der Agent darf nicht raten, was überholt
ist — wer den Lauf startet, gibt die Kandidaten mit, oder er bekommt 5 %.

⛔ **STUFE 3 IST PFLICHT, KEIN ANGEBOT.** Gemessen an beiden echten Läufen, je einmal bei
**100 % Stufe 1 und grünem Marker-Gate:** in `hooks.md` stand `833 431` am falschen Satz
(die Regler-Messung war zu „ohne Regler stimmt sie" geraten); in `env-vars.md` war eine
Richtung umgedreht („850 000, 16 569 früher als gemessen" — die Messung kam früher als die
Formel, nicht umgekehrt). Alle Marken da, Aussage falsch. Das Gate misst ERWÄHNUNG, nie
Treue — die zweite Richtung von „ohne Verlust" (nichts wird erfunden oder verdreht) hat nur
der Leser. ⛔ **Ein autonomer Lauf ohne Stufe 3 wendet NICHT an:** er legt `ergebnis.md`,
`bericht.md` und den Wort-Diff zur Durchsicht ab und meldet den Pfad. ⚠ Das schränkt „alle
dürfen kürzen" ein — Anton hat es dem Nutzer so gesagt (11.09.2026).

**Der Bericht — drei Zeilen, `mind_verdichtung_pruefen` schreibt sie:**

```
<datei>   Dauerkontext  <vorher> -> <nachher> B  (<-n> B, <p> %)
          Stufe 1       coverage <k>/<k>  100 %   Marker ⛔ n->n · ⚠ n->n · ⭐ n->n · VERBOT n->n
          Stufe 2       markenfrei entfernt <n> B von <m> B  ⚠ ungeprüft
                        ⚠ bei Umformulierung nur GRÖSSENORDNUNG (zeilenweise gezählt)
```

⚠ **Der Stufe-2-Zusatz steht im Bericht, nicht nur in der Doku:** die Zählung ist zeilenweise,
umformulierter Text wandert über Zeilengrenzen. Gemessen: **3 045 B „entfernt" bei 801 B
Gesamtverlust.** Eine Zahl ohne den Zusatz zitiert jemand.

⛔ **Kosten, gemessen:** 274 063 Token, 43 Werkzeugaufrufe, 930 s — für 14 KB. Die Zählpflicht
ist Arbeit. **Deshalb: die GRÖSSTE Datei zuerst, eine je Lauf** — dort ist das Verhältnis
Ertrag zu Token am besten. Nicht die kleinen, „weil sie billig sind".

⛔ **Die Ertragsschwelle steht VOR dem Lauf, nie hinter dem Urteil (v5.99.0).** Die Frage
„lohnt diese Datei?" wird beantwortet, BEVOR ein Agent startet — an Größe und benannten
Kandidaten. Ist die Analyse gefahren, ist sie BEZAHLT: ein korrektes Ergebnis wird nach
Stufe 3 angewendet, auch wenn es 2 % sind. Gemessen 12.09.2026 (`verdichten-mind-claudemd.txt`):
zwei korrekte Entfernungen, 267 B, „verwerfen: unter 5 %" — 267 B Deckel verschenkt für
nichts, die Token waren schon weg. ⚠ Eine 5-%-Schwelle stand nie in einem Skill; sie war
aus „oder er bekommt 5 %" (oben) abgeleitet. Die 5 % dort sind eine MESSUNG des Ertrags
ohne Kandidaten, keine Schwelle.

### ⚠ Was das Gate NICHT leistet — und es wird nicht weggeredet

- **Gemessen wird ERWÄHNUNG, nicht inhaltliche Treue.** Es schließt **Auslassungen** aus,
  nicht **Verfälschungen**. Ein Stichwort kann dastehen, während der Punkt verstümmelt
  übertragen wurde.
- ⭐ **Deshalb braucht es die zweite Richtung daneben:** *nichts wird erfunden*. Die Methode
  dafür liegt in einem fremden Projekt (`tools/erfindungsprobe.py`) — ⛔ **Methode
  übernehmen, nicht nachbauen; lesen ja, editieren nie.**
- ⚠ **Die absolute Prozentzahl allein ist wertlos.** Aussagekräftig ist der **Zuwachs**
  gegen den Vorher-Stand. Bleibt die Zahl gleich, ist nichts angekommen — egal wie hoch
  sie ist.

⭐ **Warum ein bloßes Melden trotzdem wirkt:** dieselbe Mechanik wie bei der Agent-Quittung.
Die zwingt keinen Agenten zu arbeiten — sie macht sein **Fehlen sichtbar**. Das hat gereicht.

---

## 1 · Die Dauerkontext-Bilanz — Pflichtzeile im Bericht

```bash
[ -n "$CLAUDE_PLUGIN_ROOT" ] || { echo "ERROR: \$CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 1; }
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_kontext_bilanz "$PROJ" --vergleichen
```

Ergibt zwei Zeilen, die **wörtlich in den Bericht** gehören:

```
ZEILEN=2601 ANWEISUNGEN=138 DATEIEN=21 BYTES=165508
Dauerkontext: 2586 -> 2601 Zeilen (+15) · Anweisungen 137 -> 138 (+1)
```

⚠ **Topic-Dateien zählen NICHT mit.** Sie laden höchstens 5 pro Anfrage, über einen
Auswähler, der nur Name und `description` sieht. Ihr Wuchs kostet **Auffindbarkeit**, kaum
Tokens — eine ganz andere Größe. `MEMORY.md` selbst zählt sehr wohl mit.

⚠ **Die Anweisungszahl ist eine Heuristik** (Zeilen mit `MUST`/`NEVER`/`ALWAYS`/⛔). Als
Trend brauchbar, als Absolutwert nicht. **So auch berichten**, nicht als harte Zahl.

### 1b · Art 6 — ungegatete Bestandszahlen, als KANDIDATEN (v5.79.0)

```bash
python "$CLAUDE_PLUGIN_ROOT/references/bestandszahlen_kandidaten.py" "$PROJ" --global
```

```
BESTANDSZAHLEN: 63 Kandidaten · 17 datiert · 28 gegatet · 18 UNGEGATET+UNDATIERT — ein Mensch sieht sie an, kein Gate
  CLAUDE.md:159                    45 Skill           … alle 45 Skill-Beschreibungen …
```

⛔ **Er urteilt nie, Rückgabe immer 0.** Gemessen 11.09.2026 (`docs/plugin/art6-bestandszahlen.md`):
der Versuch, Kandidaten mechanisch als FALSCH zu werten, lag **8 von 8** Mal daneben — jeder
„Fehler“ war ein Referenten-Fehler (*die fünf Context-Skills* sind nicht *alle zehn Skills*).
Finden geht, urteilen nicht. Dieselbe Doktrin wie `cleaner_leitplanke.py`.
⭐ **Was ohne Urteil wegfällt:** datiert (Datum oder Version auf derselben Zeile — ein
Protokoll sagt „damals“) und gegatet (`**<n>** |` in einer Tabelle, das Format von `zaehl_gate.py`).
Messwerte (Zeilen, Byte, Tokens, Sekunden) sind keine Bestandszahlen; „Zeilen“ nur als Limit.
⚠ Die Meldezeile gehört in den Bericht — auch bei `0 Kandidaten`. Erster Träger: `mind-rules`.

## 2 · Die Stichprobe — 3 Einträge, die am längsten ungeprüft sind

```bash
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_stichprobe.py" "$PROJ" \
       --skill <dein-skill-name> --verzeichnis "<dein-bereich>"
```

⭐ **Das ist die Antwort auf „nicht so invasiv".** Kein Skill kämmt seinen ganzen Bestand
durch; jeder sieht sich jedes Mal einen **anderen** kleinen Ausschnitt an. Über viele Läufe
ist der Bestand vollständig abgedeckt, ohne dass ein einzelner Lauf teuer wird.

| Grenze | Wert |
|---|---|
| je Skill | **3** Einträge |
| je `/mind-all`-Lauf | **15** insgesamt, über alle fünf |
| Reihenfolge | am längsten ungeprüft zuerst, bei Gleichstand alphabetisch |

⛔ **Der Rotationszustand ist PROJEKTWEIT, nicht je Skill.** Sonst legen sich fünf Skills
fünfmal denselben Eintrag vor, und der Rest des Bestands wird nie gesehen. Ein Eintrag, den
ein anderer Skill in **diesem** Lauf schon vorgelegt bekam, wird übersprungen.

⚠ **`(nichts)` ist eine gültige Antwort** — leerer Bestand, neues Projekt oder Laufbudget
erschöpft. Ein **fehlender Block** ist es nicht, siehe Abschnitt 5.

## 3 · Die drei Fragen — für JEDEN Eintrag der Stichprobe, EINE Zeile je Eintrag

| # | Frage | Werkzeug | urteilt es? |
|---|---|---|---|
| 1 | **Steht es schon woanders?** | `cleaner_duplikate.py --bereich "$PROJ"` | mechanisch, ja |
| 2 | **Steht es im Code besser?** | `cleaner_aussagen.py <datei> --code <quellbaum>` | ⛔ **nein — legt Kandidaten vor** |
| 3 | **Wird es noch gebraucht?** | `cleaner_belege.py --datei <datei>` | Belege statt Selbsteinschätzung |

⛔ **Frage 2 urteilt bewusst nicht.** *„Der Code sagt WAS, die Regel oft WARUM."* Das
Gegenbeispiel steht in diesem Projekt: `calculate_km` **stand im Code** und verschwand beim
Umbau trotzdem still — die Regel, die das WARUM trug, hätte es verhindert.
**Kandidaten vorlegen, nie streichen.**

⛔ **Frage 1 läuft EINMAL für den ganzen Bereich**, nicht dreimal. `cleaner_duplikate`
arbeitet über eine Ablage, nicht über eine Datei.

**Die Ausgabe je Eintrag ist EINE Zeile:**

```
BESTAND  .claude/rules/env-vars.md   dupl 2 (hooks.md:88, architecture.md:221) · code 0 · beleg: 14 d
```

## 4 · Schon einmal entschieden? — vor jedem Vorschlag

```bash
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_urteile.py" "$PROJ" \
       --pruefen --orte "<stelle-a>" "<stelle-b>"
```

| Rückgabe | was du tust |
|---|---|
| `unbekannt` | melden |
| `gueltig` + `duplikat` | melden |
| `gueltig` + `zielform`/`zeiger` | ⛔ **nicht erneut vorlegen** — bewusst so gelassen |
| `veraltet` | melden, mit dem Hinweis dass der Inhalt sich geändert hat |

⚠ **Widerspricht dein Befund dem Buch, überstimme es nicht — melde den Widerspruch:**
*„Buch sagt `zielform` (mensch, 24.08.), ich sehe ein Duplikat."*

## 5 · Die Quittung — sonst ist Schweigen nicht von Sauberkeit zu unterscheiden

```bash
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_stichprobe.py" "$PROJ" \
       --quittung --skill <dein-skill-name> --geprueft <n> --stichprobe <n>
```

Schreibt `bestand=<skill>:<geprueft>/<stichprobe>` in `analyzed-scopes`.

⛔ **Ein FEHLENDER Block macht den Lauf zum Teilsync.** `(nichts)` ist erlaubt, Schweigen
nicht. Ein Skill, der schweigt weil sein Bestand sauber ist, und einer, der schweigt weil
der Pass ausgefallen ist, sehen von außen **identisch** aus — genau diese Ununterscheidbarkeit
hat v5.3.1 bei zwei Hooks und v5.19.0 bei der Agent-Quittung gekostet. Beide Male war die
Lösung dieselbe: **das Fehlen messbar machen, nicht das Vorhandensein.**

⚠ Außerhalb einer `/mind-all`-Kette gibt es keine `analyzed-scopes`; die Quittung entfällt
dann **still** und ist kein Fehler.

⛔ **Verdichten quittiert IMMER, und `gelaufen` nur mit Artefakt (v5.97.0):**

```bash
mind_schritt verdichten gelaufen --datei "$PROJ/.claude-mind/verdichten-<skill>.txt" "$PROJ"  # die 3 Zeilen von mind_verdichtung_pruefen
mind_schritt verdichten "uebersprungen:kein-kandidat" 0 "$PROJ"
```

Ohne `--datei` schreibt `mind_schritt` `uebersprungen:kein-artefakt`; ohne jede Zeile steht
`verdichten` in `FEHLT`, und `mind_schritt_bilanz --alle` prüft das **je Block**. Gemessen
12.09.2026: zwei volle Läufe, `grep -c verdicht listeverbesserungen.md` = 0 — die Träger
waren nicht unkalibriert, sie waren nicht gelaufen.

---

## Fehlerszenarien — der Pass darf NIE einen Skill töten

| Fall | Verhalten |
|---|---|
| Werkzeug fehlt oder stürzt ab | **fail-open**: `UNGEPRUEFT: <werkzeug>` melden, Skill läuft weiter |
| Urteilsbuch fehlt oder ist unparsbar | wie `unbekannt` behandeln — **nie** als „schon entschieden" |
| Bestand leer / neues Projekt | Stichprobe 0, Meldung `(nichts)` — kein Fehler |
| Kein Quellbaum vorhanden | Frage 2 entfällt, wird als `n/a` **ausgewiesen**, nicht verschwiegen |
| Zwei Skills gleichzeitig | Rotationsstand wird **nach** dem Lesen geschrieben; doppelte Prüfung ist harmlos, doppeltes Auslassen nicht |
| Stichprobe > Bestand | `min(3, Bestand)` |
| Laufbudget erschöpft | `(nichts)` mit Begründung — **nicht** stillschweigend nichts tun |

⛔ **Fail-open ist hier Pflicht, nicht Bequemlichkeit.** Ein Bestands-Pass ist eine
Zusatzleistung; er darf den Sync, für den der Skill eigentlich läuft, unter keinen Umständen
verhindern.

## ⛔ Risiko: fremde Memory-Bestände im gemeinsamen Debug-Ordner

Der Pass liest auch **fremde** Memory-Bestände. In `APP - Zustellplan` stehen dort
**Abonnenten-, Routen- und Geschäftsdaten**. `mind_debug_write` schickt Befundtexte in den
**gemeinsamen** Debug-Ordner aller Projekte.

> **Verbindlich: Ort und Klasse melden, nie Inhalt.**
> `env-vars.md:112 doppelt zu hooks.md:88` — **niemals die Zeile selbst.**

Das ist bereits Regel in `mind-memory` (*„Keine Inhalte fremder Memory-Bestände in Berichte,
Logs oder Commits"*) und hier **mechanisch** gehalten: `cleaner_stichprobe.py` kennt
ausschließlich **Pfade** und hat auf Inhalte gar keinen Zugriff.

## Was der Pass auch danach NICHT kann

- ⛔ *„Braucht man das?"* bleibt ein **Urteil**. Der Pass erzwingt eine **Antwort**, nicht
  die richtige.
- ⛔ **„Steht im Code" heißt nicht „überflüssig".** Siehe Frage 2.
- ⛔ **Ob eine Regel FEHLT**, sieht kein Audit — es sieht nur, was da ist.
- ⚠ **Ob der Umbau die Befolgung hebt, ist nicht belegt.** Die Richtung ist es, der Betrag
  nicht. Die SFEIR-Zahlen sind fremde Messungen, nicht an dieser Maschine erhoben.
