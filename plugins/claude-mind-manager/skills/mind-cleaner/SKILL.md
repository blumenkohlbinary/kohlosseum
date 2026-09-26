---
name: mind-cleaner
description: |
  [Mind Manager] Raeumt Regelbestaende auf: misst, was da ist und was wirklich laedt,
  ordnet jede Regeldatei in Hook · Skill · Slash-Command · bleibt-Rule ein und zieht
  auf ein ok einen ganzen PLAN um (v5.110.0: mehrere Dateien, ein ok, Stopp am ersten
  gebrochenen Gate) — mit Erhaltungs-Gate, Pfad-Gate, Memory-Gates und Rueckweg.

  ⛔ Der Vorgabelauf AENDERT NICHTS. Er berichtet. Ein Plan entsteht erst auf "ok",
  angewendet wird erst nach Freigabe des Plans. Hooks werden nur GEMELDET, nie
  gebaut — dafuer gibt es --hook-bauen auf ausdrueckliche Ansage.

  Use when the user says "mind cleaner", "regeln aufraeumen", "startkontext kuerzen",
  "was kann weg aus den rules", "regel zu skill machen", or "/mind-cleaner".
allowed-tools: Bash, Read, Glob, Grep, Edit, Write
---

# /mind-cleaner — Regelbestände aufräumen

## ⛔ PFLICHTSCHRITTE — dieser Skill fuehrt aus, was hier steht (NEU v5.25.0)

```
PFLICHTSCHRITTE
bestandsaufnahme
cleaner_audit
cleaner_einordnung
cleaner_grenzen
cleaner_leitplanke
cleaner_ratsche
cleaner_rebuild
cleaner_tor
cleaner_umzug
cleaner_wirkung
ladeprotokoll_auswertung
mind_debug_write
mind_snapshot
```

**Vor dem ersten Schritt, ohne Ausnahme:**

```bash
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { CLAUDE_PLUGIN_ROOT=$(jq -r '.plugins["claude-mind-manager@kohlosseum"][0].installPath // empty' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null); [ -n "$CLAUDE_PLUGIN_ROOT" ] && { CLAUDE_PLUGIN_ROOT=$(cygpath -u "$CLAUDE_PLUGIN_ROOT" 2>/dev/null || printf '%s' "$CLAUDE_PLUGIN_ROOT"); echo "WARN: CLAUDE_PLUGIN_ROOT war leer — Rueckfall auf installed_plugins.json: $CLAUDE_PLUGIN_ROOT (v5.107.0)" >&2; }; }   # v5.107.0 Rueckfall
[ -n "$CLAUDE_PLUGIN_ROOT" ] || { echo "ERROR: \$CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 1; }
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ=$(mind_projekt_wurzel)    # v5.80.0: der Ordner mit rollen.md, sonst cwd
# ⛔ v5.77.0: DIE VERSION DIESES SKILL-TEXTS. lib.sh vergleicht sie mit
#    basename "$CLAUDE_PLUGIN_ROOT" und meldet VERSIONSBRUCH, wenn ein alter
#    Text gegen neuen Code laeuft (Rita bekam am 10.09.2026 den Text aus 5.2.0).
#    ⚠ Wird beim Release nachgezogen; das Zaehl-Gate prueft alle zehn.
#    ⛔ v5.125.0: DIESELBE Bash wie mind_schritt_start — sonst rc 1, keine Startzeile (Etappe 37 §3).
MIND_SKILL_VERSION="5.124.0"
# ⛔ v5.77.0: DIE VERSION DIESES SKILL-TEXTS. lib.sh vergleicht sie mit
#    basename "$CLAUDE_PLUGIN_ROOT" und meldet VERSIONSBRUCH, wenn ein alter
#    Text gegen neuen Code laeuft (Rita bekam am 10.09.2026 den Text aus 5.2.0).
#    ⚠ Wird beim Release nachgezogen; das Zaehl-Gate prueft alle zehn.
MIND_SKILL_VERSION="5.135.0"
mind_schritt_start "$PROJ" mind-cleaner bestandsaufnahme cleaner_audit cleaner_einordnung cleaner_grenzen cleaner_leitplanke cleaner_ratsche cleaner_rebuild cleaner_umzug ladeprotokoll_auswertung mind_debug_write mind_snapshot
```

**Nach JEDEM Schritt** — auch nach einem, der entfaellt:

```bash
mind_schritt <name> gelaufen              "$(wc -c < "$AUSGABE")" "$PROJ"
mind_schritt <name> "gelaufen:5/11"       "$BYTES" "$PROJ"   # TEILABDECKUNG
mind_schritt <name> "uebersprungen:<grund>" 0      "$PROJ"
mind_schritt <name> "fehler:<grund>"      -1       "$PROJ"
```

⛔ **`uebersprungen` ist ein gueltiger Status und braucht einen GRUND.** Ein Schritt,
der legitim entfaellt (`--dry-run`, kein Git, kein Quellbaum), ist kein Fehler — aber
sein Entfallen gehoert in den Bericht statt zu verschwinden.

⛔ **v5.67.0: EINEN PFLICHTSCHRITT AUSZULASSEN, WEIL ER TEUER AUSSIEHT, IST VERBOTEN.**
Nutzer-Auftrag 10.09.2026: *„die sollen alles fahren"*. ⭐ Die Trennlinie:

| | |
|---|---|
| ⛔ **verboten** | gar nicht **starten**, aus Ruecksicht auf Kontext, Zeit oder Kosten |
| ✅ **erlaubt** | starten und **scheitern lassen** — `bytes:0` faengt die Bilanz |

Ein gestarteter Agent, der stirbt, ist ein **Befund**. Ein nie gestarteter ist eine
**Luecke, die wie ein Ergebnis aussieht**. ⚠ „Ressourcengrund" ist deshalb **kein**
zulaessiger `uebersprungen:`-Grund — er stand in keinem Skill und ist beim Lauf
entstanden. Seit v5.67.0 macht eine Teilabdeckung den Lauf zum **Teilsync**: die
Schuld bleibt liegen, bis wirklich alles gefahren ist.

⭐ **`gelaufen:5/11` ist die TEILABDECKUNG und der Anlass dieses Baus.** Am 30.08.2026
lief `cleaner_leitplanke.py` ueber 5 von 11 Dateien und wurde als **Bereichspruefung**
berichtet. Der Fehler war nicht ein fehlender Aufruf, sondern ein gelaufener, der
weniger abdeckte als der Bericht behauptete. `5/11` ist eine gueltige Antwort;
sie als `11/11` zu berichten ist es nicht.
⚠ **`X/Y` mit X=Y (`1/1`) zaehlt seit v5.113.0 als voll** — vollstaendig heisst trotzdem
`gelaufen`, nicht `1/1` (Noras Lauf 11, 16.09.2026). ⛔ **Nachquittieren geht nur im SELBEN
Block:** die Bilanz nimmt den letzten Eintrag je Block×Name; ein Nachtrag in einem spaeteren
Block heilt nichts — den Block erneut fahren (mind-all 2.96a-R).
⛔ **Eine geloeschte oder leere Schritt-Quittung wird nicht nachgetippt — der Block wird neu
gefahren** (v5.116.0, Doros Creator-Lauf 16.09.2026: 39 Schritte in 5 s nachgetippt, Bilanz 39/39).
Die Bilanz erkennt getippte Bloecke (Starts < `MIND_SCHRITT_MIN_S` = 60 s auseinander, >= 5 Schritte
in 10 s) als FORMAL, der Lauf ist teil.

⛔ **Die Bytezahl ist Pflicht, wo ein Schritt etwas ausgeben MUSS.** Am selben Tag
lief `cleaner_belege.py` und seine Ausgabe wurde weggegreppt — aus Sicht einer
naiven Quittung waere das „gelaufen". `0` meldet die Bilanz als **LEER**; `-1`
heisst „nicht gemessen" und zaehlt nicht.

**Im Bericht, als erste Zeile des Self-Checks:**

```bash
mind_schritt_bilanz "$PROJ"
```

⛔ **Fehlt diese Zeile oder nennt sie `FEHLT`, ist der Bericht unvollstaendig** und
darf zurueckgewiesen werden. Rueckgabe **2 heisst: gar keine Quittung** — der Lauf
hat nie begonnen zu quittieren, und das ist NICHT „nichts zu melden".

⚠ **Was die Quittung nicht kann:** sie erzwingt keinen Schritt, sie macht sein Fehlen
sichtbar — wie `decision:block` und die Agent-Quittung. Und sie misst nicht die GUETE:
ein Werkzeug, das laeuft und Unsinn liefert, quittiert als `gelaufen`.

## ⛔ Der Ablauf ist dreistufig, und jede Stufe braucht ein OK

```
1. BERICHT     /mind-cleaner [--bereich global|projekt|alles|memory]   aendert NICHTS
      ↓  Nutzer sagt ok
2. PLAN        /mind-cleaner --plan [--bereich …]        EIN Plan ueber ALLE Befunde (v5.110.0)
      ↓  Nutzer gibt den Plan frei — „ok" oder „ok ohne 3,7"
3. ANWENDEN    cleaner_plan.py --anwenden <plan> [--ohne 3,7]   ALLES in einem Lauf
               /mind-cleaner --umzug <datei> · --rebuild <datei>   der Einzelfall (--nur)
```

**Nutzer-Entscheidung 24.08.2026, wörtlich:** *„er soll erstmal berichten dann wenn ich
ok gebe plan schreiben und anwenden"*.
⛔ **v5.110.0 — Nutzer 14.09.2026, wörtlich:** *„ja mach einen plan über mehrere dateien und
auch mind memory muss das gefixt werden mit einem ok"*. Das ersetzt „GENAU EINE Datei je
Umzug" (24.08.); die 73 liegengebliebenen Audit-Befunde vom 25.08. waren der Preis.
Bericht → Plan → ok bleiben drei Schritte — nur das „eine Datei" fällt.

```bash
# 2  der Plan: ALLE Befunde der Gruppen 2–4 (Umzüge, docs/-Ziele, paths:-Vorschläge,
#    Archivierungen, Zeiger) in EINE Datei, je Zeile Datei · Klasse · Ziel · Gates · Rückweg
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_plan.py" --neu "$PROJ" --nur projekt
#    -> $MIND_DEBUG_DIR/laeufe/<ts>_plan.md; UMZUG/DOCS-Zeilen brauchen `kurz=<pfad>` —
#       die vorbereitete Kurz-Rule schreibt die Sitzung VOR dem ok in den Plan
# 3  das eine ok: gemeinsamer Snapshot (eine Einheit, wie /mind-all), dann Zeile für Zeile
#    mit den bestehenden Gates; bricht EIN Gate, stoppt der Lauf — davor bleibt, danach
#    NICHT ANGEWENDET, der Plan trägt je Zeile den Status, der Bericht nennt die Zeile
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_plan.py" --anwenden <plan> [--ohne 3,7]
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_audit.py" --bereich "$PROJ"   # Pflicht danach
```

⭐ **v5.115.0 (Veras erster Lauf im Zustellplan, 16.09.2026 — acht Befunde):**
- **ZEIGER-Zeilen stehen je Dateipaar EINMAL im Plan** („n doppelte Marken zwischen a + b"),
  die Marken selbst in `<plan>.anlage.md` (Abschnitt je Paar). 1 823 Zeilen, davon 1 796
  ZEIGER, waren kein Plan, sondern ein Protokoll. `--anwenden` liest beide, ZEIGER bleibt „nur gemeldet".
- **DOCS-Zug aus dem MEMORY:** die Indexzeile in `MEMORY.md` zeigt direkt auf `docs/<name>.md`,
  **kein Stub bleibt zurueck, das Topic ist weg** (im Snapshot unter `memory/`). Bis 5.114.0 blieb
  der Stub, die Themenzahl sank nicht, der Memory-Deckel blieb rot. Danach
  `Learnings/memory_gates.py <snapshot>/memory --wurzel "$PROJ"` — Gate 3 liest den docs-Zeiger als
  gueltig, Gate 1/1b zaehlen den ausgelagerten Inhalt als wiedergefunden.
  ⛔ **v5.131.0: `--wurzel` ist hier nicht mehr Komfort.** Gate 3 prueft damit auch, ob `CLAUDE.md`
  oder `.claude/rules/*.md` noch auf eine entfernte `memory/<name>.md` zeigen (Veras Fund 23.09.2026,
  zwei tote Zeiger eine Woche unbemerkt). Ohne `--wurzel` und ohne auffindbares Projekt steht
  „Rules-Zeiger ungeprueft" im Bericht — das ist eine Luecke, kein gruenes Gate. **Nur melden:**
  die Rules gehoeren dem arbeiter, das Memory der sync-Rolle; der Bericht nennt Datei:Zeile.
  ⛔ **v5.117.0 (Veras fuenf Zuege im Zustellplan):** die Zeile heisst
  `- [Titel](docs/<name>.md) — <alter Aufhaenger> (umgezogen nach docs, lies zuerst dort)` —
  Pfad PROJEKTRELATIV, der alte Aufhaenger bleibt (description nur ohne Aufhaenger, YAML-Escapes
  aufgeloest), der Zeiger steht EINMAL, `MEMORY.md` behaelt ihre Zeilenenden. Schon geschriebene
  Zeilen der 5.115.0-Form zieht `cleaner_plan.py --reparieren-index <memory-dir> --projekt "$PROJ"
  --snapshot <sicherung>` nach (Aufhaenger aus dem Snapshot).
- ⛔ **UNANTASTBAR (v5.117.0, Veras Audit setzte den AKTIVEN Roster als Plan-Zeile 1 ARCHIV):**
  der Roster (`rollen.md` mit Rollentabelle), `CLAUDE.md`/`CLAUDE.local.md` und `MEMORY.md`
  bekommen nie ARCHIV/UMZUG/DOCS — im Audit Gruppe 9 „nur Meldung" **bei JEDEM Urteil** (v5.128.0,
  Etappe 40 §1: Ritas Audit 19.09. führte den gepflegten Roster unter 5a „STREICHEN" und CLAUDE.md
  unter 1/2, weil die Umlenkung nur bei VERALTUNGS-/SCHWACHER KANDIDAT griff), im Plan MELDUNG, und
  `--anwenden` bricht an einer von Hand geschriebenen Zeile dazu. Und **„nie ueberarbeitet" ist
  erst ein Fossil**, wenn die Datei aelter als `MIND_BELEG_FRISCH_TAGE` (21) ist UND das Projekt
  seit ihrer Anlage mindestens 5 Commits hat — sonst „zu jung fuer ein Urteil" (Gruppe 5a).
- **Memory-Dateien sind nie HOOK-KANDIDAT** (`type:` im Frontmatter): Lessons ZITIEREN Pfade und
  Funktionen — das `keine-annahmen`-Fehlurteil, am Memory reproduziert (8 von 40). Klasse `BLEIBT MEMORY`.
- ⛔ **v5.120.0 (Etappe 29, Ottos Plan-Lektuere Zustellplan 17.09.2026), fuenf Befunde:**
  **(1)** eine `ZAHLENDRIFT`-Zeile traegt BEIDE Fundstellen `<datei>:<zeile> „<satz>"` ↔ `<datei>:<zeile> „<satz>"`
  (Satz auf 120 Zeichen gekuerzt), im Plan UND in der Anlage — Otto liess 14 Zeilen liegen, weil nur Marke und
  Zahlen dastanden. **(2)** eine Marke ohne Buchstaben oder Ziffer (`. **` aus der Backtick-Paarung ueber zwei
  Spans) zaehlt nirgends: `cleaner_duplikate.marken`, `cleaner_umzug.marken`, `coverage_gate.checkpoints`
  (Verdichten-Gate, Umzug, Duplikate — eine Regel, alle Zaehler). **(3)** Plan-Zeile 1 ist „offen" wie alle —
  Prueffall; am Plan 0034 nicht reproduzierbar (die Datei trug „offen", `lies_plan` liest es).
  **(4)** Memory-Nachschlagewerk (imp < 0,15, kein Gebot) → **DOCS zuerst**, COMMAND hoechstens als zweiter
  Vorschlag (Nutzer 14.09.2026: Nachschlagewerk → `docs/`) — vorher COMMAND unter `~/.claude/skills/`.
  **(5)** fuehrt `MEMORY.md` die Datei unter einem Abschnitt mit **Status-Wort** (`HAUPTBEFUND`, `LAUFEND`,
  `OFFEN`, `AKTUELL` — `INDEX_STATUS`, erweiterbar per `MIND_INDEX_STATUS="HAUPTBEFUND,LAUFEND,…"`), ist sie ein
  aktiver Auftrag: DOCS/COMMAND/ARCHIV gesperrt → `BLEIBT MEMORY (Status im Index)`. Die Form (imp 0,07) sieht
  den Status nicht — `loeser-ist-schlecht.md` („⛔ HAUPTBEFUND — zuerst lesen") stand als DOCS im Plan.
- ⛔ **v5.121.0 (Etappe 31, Otto 17.09.2026): ein `[[Wikilink]]` auf ein nach `docs/` umgezogenes Thema ist TOT** —
  Claude Code loest `[[name]]` als `memory/<name>.md` auf, der docs-Zeiger in der Indexzeile rettet ihn nicht
  (`MEMORY.md:20` → `[[karten-vereinheitlichung]]` nach dem 16.09.-Zug). Der DOCS-Zug schreibt deshalb `[[name]]`
  im GANZEN Memory-Verzeichnis inkl. `MEMORY.md` auf `` `docs/<name>.md` `` um (Zeilenenden je Datei erhalten;
  die Traeger liegen VORHER im gemeinsamen Snapshot), und `Learnings/memory_gates.py` Gate 3 liest Wikilinks
  auch im Index: gueltig nur, wenn `<name>.md` im Memory liegt; schon vorher tote Links sind Meldung, kein Bruch.
- **`paths:` schon gesetzt → `BLEIBT (paths gesetzt)`**, Vorschlag nur „Sonde", nie „setzen".
- **Gruppe 5a fuer Memory: „nicht messbar (kein Git)"** mit Beleg aus Datei-Zeiten, `[[Verweisen]]`
  und Index-Eintrag — die Git-Quelle greift ausserhalb des Repos nie, und „Historie nicht messbar"
  las sich wie „ohne Beleg → streichen".
- **`cleaner_belege` zaehlt nur Verstoesse DIESES Projekts** (Fremdtreffer getrennt: „n in anderen
  Projekten") und trifft Stichwoerter als **ganzes Wort** — Zustellplans `rollen.md` hatte „4
  Verstoesse" aus zwei anderen Projekten, einer ueber „Kontrollen".
- **Bestand auf der PLATTE ist nicht der Dauerkontext:** `bestandsaufnahme.py` und
  `mind_kontext_bilanz` trennen „laedt beim START" (ohne `paths:`, zaehlt im Deckel) von „laedt bei
  BERUEHRUNG" (`paths:`, Zeile 3 `BERUEHRUNG=<n> BERUEHRUNG_B=<bytes>`). Zustellplan: 874 kB auf
  der Platte, 131 kB beim Start.

⛔ **`/mind-memory` bleibt AUTONOM** (Nutzer 15.09.2026: *„oh man /mind-memory arbeitet
autonom und mind cleaner nicht"*) — das ok gehört NUR zum Cleaner, weil er über alles
hinweg eingreift. Was mind-memory aus dieser Reihe bekommt, ist allein v5.109.0 (alle
Memory-Verzeichnisse, nie über Slugs mergen) — autonom angewendet wie seit v5.0.0.

⛔ **Das weicht bewusst von den v5.0.0-Skills ab**, die autonom anwenden. Der Grund steht
im Entwurf und gilt: hier wird die **Wissensbasis zerschnitten**, nicht eine Zahl korrigiert.
Ein falsch herausgeschnittener Satz fällt erst auf, wenn er gebraucht wird — und dann fehlt er.

Weitere Aufrufe:

```
/mind-cleaner --audit              der Fuenf-Gruppen-Bericht (NEU v5.18.0)
/mind-cleaner --nachmessen         nach einer NEUEN Sitzung: hat der Umzug gewirkt?
/mind-cleaner --hook-bauen <datei> Hook erzeugen — NUR auf ausdrueckliche Ansage
```

## ⭐ `--audit` — der Bericht, in dem alles zusammenläuft

```bash
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_audit.py" \
       --bereich "$PROJ" --nur global|projekt|alles|memory
```

Er fährt **alle sechs Werkzeuge** und legt fünf Gruppen vor — **Gruppe 5 zuerst:**

```
5a  kein Verstoss vorliegend            vielleicht spaeter messbar
5b  GRUNDSAETZLICH NICHT LOGGBAR        ⭐ der Kern, nicht der Rest
1   belegt noetig                       bleibt, wo es ist
2   falsch platziert                    Ort A -> Ort B, mit Zielpfad
3   doppelt                             eine Stelle wird Zeiger — nur echte Inhalts-Dopplung (gemeinsamer Satz) oder ZAHLENDRIFT; blosse Nennung derselben Datei/Marke zaehlt als Zahl (v5.129.0)
4   belegt veraltet                     ins Archiv, mit Beleg
7   SKILLS-BESTAND (v5.111.0)           BLEIBT · ZU LANG · ZU WEICH · OHNE ZEIGER · TOT-VERDACHT · ZURUECK IN RULE · DOPPELT
8   TOTE REGLER (v5.111.0)              MIND_*-Variablen in settings.json ohne Leser — nur melden
```

⭐ **Gruppe 7 (v5.111.0, Etappe 17 §2):** die `description`s aller Skills sind Dauerkontext
(45 ≈ 7 300 Token, immer geladen) — der Cleaner zog Dateien DORTHIN und prüfte sie nie. Bestand
`~/.claude/skills/*/SKILL.md`; **Plugin-Skills werden nur GEMELDET** (sie gehören dem Plugin).
Gemessen wird: Länge (`MIND_SKILL_DESC_MAX`, Vorgabe 600; Kappung 1 536), Direktivität
(`ALWAYS invoke when…` — gemessen half direktiver Stil), Zeiger aus einer Kurz-Rule (Pfad
4/4 gegen Auswahl 20–84 %), Aufruf `/<name>` in Transkripten der letzten `MIND_SKILL_TOT_TAGE`
(Vorgabe 30) Tage, gleiche description = DOPPELT. Nichts davon wird angewendet ohne Plan-OK.
⭐ **Gruppe 8 (§4):** `MIND_*` in `settings.json`, das kein Hook/Skill/Werkzeug mehr LIEST
(Zuweisung, nicht Prosa) — **Nutzerdatei, nur du.** Gemessen 14.09.2026: drei tote Regler.

⛔ **Gruppe 5 steht oben, nicht unten.** Sie ist das ehrliche Maß dafür, wie viel der Lauf
wirklich wusste. Ein Bericht, der sie ans Ende schiebt, behauptet Sicherheit, die er nicht hat.

⭐ **Und 5b ist der Kern.** Urteils- und Prozessregeln (`keine-annahmen`, `plan-mode`,
`ursache-vor-reparatur`, `fertig-heisst-fertig`) erzeugen kaum je einen maschinell
erfassbaren Verstoß. Sie landen dort **nicht weil sie unbeobachtet blieben, sondern weil sie
unbeobachtBAR sind.** Wer 5b für eine Restmenge hält, liest den Bericht falsch.

**Zwei Belegquellen statt Selbsteinschätzung** (`cleaner_belege.py`):

| Quelle | was sie zeigt |
|---|---|
| `Debug/index.jsonl` | datierte Verstöße — wie viele, wie alt, wann zuletzt |
| Git-Historie | **Ein-Commit** = seit Anlage nie überarbeitet („Init Fossilization") |

⛔ **Die Modell-Alterung ist NICHT eingebaut — die Behauptung stand hier zu Unrecht.**
Bis v5.20.1 warb dieser Abschnitt mit *„hören sie an einem Modellwechsel auf?"*. Das Wort
*Modell* kam in `cleaner_belege.py` **null mal** vor.

**Gemessen 25.08.2026, warum es (noch) nicht lohnt:**

```
Modellwechsel sind ableitbar   claude-opus-4-7  ab 29.05. · 4-8 ab 04.06. · 5 ab 29.07.
Debug-Befunde                  142, ältester 20.08., jüngster 25.08.
davon VOR dem letzten Wechsel  0
```

**Trennschärfe heute: null.** Jede Regel wäre „nicht entscheidbar". Der Bau ist
zurückgestellt, bis das Debug-Fenster einen Modellwechsel überspannt — die Datenquelle
(`~/.claude/projects/<slug>/*.jsonl`, Feld `message.model`) ist dann ohne Handpflege da.

⛔ **Die Frage *„würdest du das auch ohne die Regel tun?"* wird NICHT gestellt.** Sie ist
nicht zuverlässig beantwortbar: am 24.08.2026 wurden **vier Regeln gebrochen, die wörtlich in
der geladenen `CLAUDE.md` standen**. Vorher hätte die Selbsteinschätzung bei jeder gelautet:
*„das mache ich sowieso richtig."*

⚠ **Die Stichwortbildung war zuerst viel zu locker** — `nicht`, `gegen`, `Regeln` als
Stichworte schrieben `env-vars.md` **56 von 106** Befunden zu, und Gruppe 5b blieb **leer**.
**Eine Belegquelle, die fast alles belegt, belegt nichts.**

---

## Step 0: Bereich bestimmen

`--bereich` steuert, wo gearbeitet wird. **Nutzer-Entscheidung 24.08.2026:** *„alles aber
ich kann dann angeben ob global oder lokal nur der projekt ordner"*.

| Wert | Bestand |
|---|---|
| `global` | `~/.claude/rules/` + `~/.claude/CLAUDE.md` |
| `projekt` | `$PROJ/.claude/rules/` + `CLAUDE.md`, `.claude/CLAUDE.md` **und `CLAUDE.local.md`** des Projekts (v5.111.0; alle drei laden beim Start) **+ das Memory des Projekts** (v5.107.0) **+ im Rollen-Aufbau die Roster-Unterordner** — deren `CLAUDE.md` und `.claude/rules/*.md`, Bericht `<ordner>/<name>` (v5.111.0; Creator: 22 Dateien, vorher unsichtbar) |
| `memory` | **nur** das Memory: `~/.claude/projects/<slug>/memory/*.md` ohne `MEMORY.md` (v5.107.0) — **im Rollen-Aufbau ALLE Slugs: Wurzel + je Roster-Ordner** (`mind_memory_dirs`, `learnings_quellen.memory_pfade`, v5.109.0); Bericht `memory[<ordner>]/<name>`; ⛔ ein Fakt in zwei Slugs ist ein Duplikat-BEFUND, nie ein Merge |
| `alles` *(Vorgabe)* | alles davon |

⛔ **v5.107.0 — das Memory ist VOLLWERTIGER Bestand.** Nutzer-Entscheidung 14.09.2026,
wörtlich: *„nein mind cleaner ist für alles da"* — auf die Antwort, Memory sei Sache von
`/mind-memory`. Seither laufen Bestandsaufnahme, Einordnung, Kontext-Tor (A1–C2), Duplikate
gegen Rules und CLAUDE.md in **beide** Richtungen, `--umzug` und `--rebuild` auch über die
Topic-Dateien. Der Pfad kommt **immer aus dem Slug** (`learnings_quellen.memory_pfad`,
`cleaner_duplikate._memory_dir`), nie aus dem Projektordner; der Bericht nennt jede Datei als
`memory/<name>`.
⛔ **Unverändert nicht autonom** — Bericht → OK → Plan → OK — **und für Memory kommen die
vier Gates aus `mind-memory` 4.0c dazu.** Vor JEDEM anwendenden Schritt an einer Topic-Datei:

```bash
TS=$(date +%Y%m%d_%H%M%S); B="C:/CD/KOHLEKTIV/_claude_backups/${TS}_memory"
MEM=$(python -c "import sys; sys.path.insert(0,'$CLAUDE_PLUGIN_ROOT/references');
from learnings_quellen import memory_pfad; print(memory_pfad(r'$PROJ') or '')")
[ -n "$MEM" ] && mkdir -p "$B" && cp "$MEM"/*.md "$B/"
# … --umzug / --rebuild --anwenden auf memory/<name> …
python Learnings/memory_gates.py "$B"        # Erhaltung · kein Umbenennen · Verweise · Beschreibung
```

Bricht ein Gate: zurück aus `$B`, Befund in den Bericht. Ohne Sicherung wird nichts angewendet.

⛔ **Fremdklon-Schutz ist Pflicht, nicht Kür.** Vor jeder Datei:

```bash
python -c "import sys; sys.path.insert(0,'$CLAUDE_PLUGIN_ROOT/references');
from learnings_quellen import upstream_datei; print(upstream_datei(PROJ, PFAD))"
```

Gehört die Datei nicht dem Nutzer (Upstream, Fremdklon), wird sie **gelistet, nie angefasst**.

---

## Step 1: Messen, was da ist

```bash
python "$CLAUDE_PLUGIN_ROOT/references/bestandsaufnahme.py" --ordner <verzeichnis>
# oder positional: ... bestandsaufnahme.py <verzeichnis>   (beides seit v5.20.1)
```

Größe, Dateizahl, Zusammensetzung. Die Kontrolle des Werkzeugs ist ein **synthetischer
Prüftext**, keine echte Datei — die erste Fassung kontrollierte gegen zwei benannte Dateien
und verweigerte dadurch die Arbeit an jedem anderen Ordner. Sie prüfte den **Ordner** statt
das **Instrument**.

## Step 2: Messen, was wirklich lädt

```bash
python "$CLAUDE_PLUGIN_ROOT/references/ladeprotokoll_auswertung.py"
```

⛔ **„Nicht im Protokoll" heißt NICHT „lädt nicht".** Gezählt werden **Ladevorgänge, keine
Tokens** — ein Budget lässt sich daraus nicht ableiten.

⭐ **Der teuerste Einzelbefund dieses Werkzeugs:** Unterverzeichnisse in `rules/` **laden
mit**. Am 23.08. kamen **267 von 920** Ladevorgängen aus einem `archive/`-Ordner, der
angelegt worden war, **um den Bestand zu kürzen**. Die Kürzung hatte ihn verdoppelt.
Wer den Umfang eines Regelbestands misst, misst **rekursiv**.

## Step 3: Einordnen

```bash
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_einordnung.py" --verzeichnis <pfad>
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_einordnung.py" --selbsttest
```

Sechs Wege, nach dem **Moment der Erkennbarkeit** (v5.108.0: zwei dazu):

| woran erkennbar? | → |
|---|---|
| am **Werkzeugaufruf** (Pfad, Endung, Befehlswort) | **Hook** |
| an der **Aufgabe**, oder der Nutzer ruft es **beim Namen** | **Command** (`/name`) |
| **gar nicht** — es **erklärt** statt anzuweisen, kein Aufruf-Anker (imp < 0,15, kon < 0,30) | **DOCS**: `docs/<name>.md` + Zeiger-Satz am alten Ort — 0 B Dauerkontext, der Pfad trägt 4/4 |
| an **benannten Dateien** — Gebote für `x.py`, Datei-Listen (dat ≥ 0,30) | **RULE-PATHS**: Rule behalten, `paths:` setzen, Ladung **messen** (`--paths-sonde`); steht `paths:` schon: **BLEIBT (paths gesetzt)**, nur Sonde (v5.115.0) |
| **gar nicht**, gilt vor jedem Eingriff | **bleibt Rule** |

⛔ **v5.108.0 — passen ZWEI Klassen, stehen BEIDE im Bericht, mit Grund.** Nutzer (14.09.2026):
ein reines Nachschlagewerk (32 kB, Imperativdichte 0,03) gehört nach `docs/` mit Zeiger, nicht
in einen Command; und wo Arbeit Datei-Bearbeitung ist, ist `paths:` „sehr gut". Richtig wären
ZWEI Vorschläge gewesen — `einordnen()` liefert sie als `vorschlaege` (Reihenfolge = Rang),
`--audit` druckt `DOCS — … | ODER COMMAND — …`. Gemessen 14.09. an 14 Rules eines Projekts:
1× DOCS+COMMAND, 4× RULE-PATHS als zweite Klasse.
⛔ **v5.112.0 — ALLGEMEIN, in jedem Projekt (Nutzer 14.09., 23:40):** kein Dateiname und kein
Projektpfad im Code. Das **DOCS-Ziel** wird je Projekt abgeleitet — vorhandener Doku-Ordner
`docs/`, sonst `knowledge/`, sonst `doc/`; fehlt jeder: `docs/` anlegen und im Plan nennen
(`cleaner_plan.docs_ziel`), Zeiger-Satz relativ zur Projektwurzel. **RULE-PATHS** erkennt die
Bindung aus dem Rule-Text selbst: Backtick-Pfade, die im Projekt **existieren** (wie
`mind_pfad_lebt`) — ein toter Pfad bindet nichts, `.claude/rules/*.md` zählt nicht. Die
**Sonde** wählt ihre Rule in jedem Projekt selbst (kleinste mit lebendem Dateibezug) und
meldet, ob schon ein Ergebnis aus einem **anderen** Projekt liegt — der Satz für
`kontext-anlegen.md` gilt erst mit zwei.

⛔ **Hier standen bis v5.27.0 VIER Wege — „Skill" und „Slash-Command" getrennt.**
Das sind nicht zwei Dinge: ein Command **ist** das, was du mit `/name` tippst, und
`lokal`/`global` sagt nur, wo seine Datei liegt. Nutzer-Befund, wörtlich: *„ich will
keine Skill-Typen, woher soll ich wissen dass es 2 gibt."*
⚠ **Und die Prosa versprach mehr als der Code hatte:** `cleaner_einordnung.py` gab
nie eine Klasse `SLASH-COMMAND` aus — nur `HOOK-KANDIDAT`, `COMMAND`, `UNKLAR`. Wer
auf das vierte Urteil wartete, wartete auf eines, das es nicht gibt.

⛔ **Die harte Kante: was ERZWUNGEN werden muss, wird NIE ein Command.** Das ist keine
Vorsicht, sondern Herstelleraussage — die Skills-Doku sagt bei nachlassender Wirkung
*„…or use hooks to enforce behavior deterministically"*.

⛔ **Das Werkzeug nennt seine eigenen Fehlurteile** (24.08.2026) — und seit v5.128.0 (Etappe 40 §2)
mit dem NACHGEMESSENEN Stand statt dem alten Satz in jedem Bericht:

- `autonom-arbeiten.md` → damals **SKILL** bei Imperativdichte **0,00**; heute imp 0,17 → **UNKLAR**
  (die Datei wurde umgeschrieben, die Klasse SKILL gibt es nicht mehr). Die Klasse bleibt:
  **Deutsche Prosa befiehlt ohne Schlüsselwort.** Ein deutsches Signal (NICHT/SOFORT/verboten/
  kein Grund) wurde am 19.09.2026 an 54 Dateien gemessen — 12 wechseln die Klasse, keine geprüft —
  und deshalb **nicht** eingebaut; ein synthetischer Fall im Selbsttest hält die Klasse fest.
- `keine-annahmen.md` → damals **HOOK-KANDIDAT**, weil sie **andere Regeldateien zitiert**; seit
  28.08.2026 im Archiv, der Fall kann nicht mehr auftreten. Eine Zitierung ist kein Aufruf-Anker
  (Selbsttest „Zitat-Regel kein Hook").

**Daraus folgt und ist nicht verhandelbar:** ein COMMAND-Vorschlag wird **nie ohne menschliche
Bestätigung** angewendet.

## Step 4: Die Leitplanke herausschneiden — der schwierigste Teil

**Was bleibt, muss allein tragen; was geht, muss vollständig sein.**

**Was in der Kurz-Rule bleibt:** das Verbot · die Entscheidung in einem Satz · die Zahl, die
man vor dem Anfangen wissen muss · **der Pfad zum Volltext** · **der Command-Aufruf**.
**Was in den Command geht:** Herleitung · Belege · Messreihen · Fallen · Beispiele.

⭐ **Die Trennlinie in einem Satz — Bremse gegen Anleitung:**

> Eine **Bremse** hält dich vom Falschen ab, **bevor** du merkst, dass du nachschlagen
> solltest — sie muss in der Rule stehen, sonst kommt sie zu spät. Eine **Anleitung**
> brauchst du erst, **während** du arbeitest; dann hast du den Command ohnehin geladen.

*„suspend nur auf ausdrückliche Ansage"* ist eine Bremse — wer aufräumen will, lädt keinen
Skill dafür. *„834–941 MB/s, wer weniger misst, hat seinen Aufbau gemessen"* ist Anleitung.

### Werkzeug (NEU v5.24.0) — es legt Kandidaten vor, es schneidet nicht

⛔ **Hier stand bis v5.23.1 „Hier gibt es kein Werkzeug."** Das stimmte, und es war der Grund,
warum `workstation-fernzugriff` nach dem Umzug mit **63 Zeilen** liegenblieb, während die
vier Geschwister bei 19–33 lagen — mit MAC-Adressen, Durchsatztabellen und
`sudoers`-Dateinamen darin. Kein Gate hat je danach gefragt.

```bash
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_leitplanke.py" \
       --verzeichnis "$ZIEL_RULES" --skills "$HOME/.claude/skills"
```

Es meldet drei Formklassen als **Kandidaten**: `adresse` (IP/MAC) · `syspfad` (`/etc`, `/usr`,
`/var`) · `befehl` (Codezeile mit konkreten Argumenten, ohne `<platzhalter>`/`$VARIABLE`).
Dazu Zeilenzahl gegen die **im Lauf gemessene** Korpus-Spanne, den Bremsanteil und ob der
Zeiger Pfad **und** Command nennt.

⛔ **Zahlen sind ausdrücklich KEINE Klasse.** Im echten Bestand trägt die Bremse ihre Messung
mit („834–941 MB/s" steht *in* der Fehlmessungs-Warnung). Ein Filter, der Zahlen meldet,
schneidet die Bremse weg.

⛔ **Eine Zeile mit ⛔/⚠/NIE/NUR wird nie Kandidat** — auch dann nicht, wenn eine Adresse
darin steht. `10.10.10.1 ZUERST, sonst ist das ein BEFUND` **ist** die Bremse.

⚠ **Kandidat ist kein Urteil.** Ob ein Satz Bremse oder Anleitung ist, ist eine
Bedeutungsfrage; mechanisch entscheidbar sind nur Formmerkmale. Die Liste sieht ein Mensch
durch — genau wie beim COMMAND-Vorschlag aus Step 3.

## Step 5: Umziehen — die Gates, alle müssen halten

⛔ **Hier stand „vier Gates", während die Tabelle darunter fünf führte** — falsch seit
v5.24.0, als `INHALT` dazukam. Eine Zahl in einer Überschrift veraltet lautlos; deshalb
steht hier keine mehr. Wer zählt, zählt die Tabelle.

```bash
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_umzug.py" \
  --alt <snapshot/alt.md> --kurz <neue-kurz.md> --skill <skills/<name>/SKILL.md>
# v5.108.0 — Umzug nach docs/ (Klasse DOCS): <s.md> ist die Datei unter docs/
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_umzug.py" \
  --alt <snapshot/alt.md> --kurz <neue-kurz.md> --skill <docs/<name>.md> --ziel docs
```

⭐ **`--ziel docs` (v5.108.0):** BESCHREIBUNG und DOPPELZEIGER entfallen (docs/ ist kein
Command), dafür ist **ZEIGER** Pflicht — der alte Ort zeigt **direktiv** auf die Datei („lies
zuerst `docs/…`"), nicht beiläufig. ERHALTUNG, ENTLASTUNG, PFAD, INHALT gelten wie bisher.

| Gate | prüft |
|---|---|
| **ERHALTUNG** | `Zeilen(Kurz) + Zeilen(Skill) ≥ Zeilen(Alt)` — Umziehen verschiebt, es kürzt nicht |
| ⭐ **ENTLASTUNG** (NEU v5.71.0) | die Kurz-Rule ist in **BYTES** kleiner als die alte. ⛔ Ohne dieses Gate bestand ein Umzug, der **nichts entlastet**, alle übrigen: `ERHALTUNG` zählt über beide Orte und ist blind dafür, ob der **immer ladende** Anteil gesunken ist. ⚠ Es fordert eine Richtung, kein Maß — eine Mindestquote wäre eine gesetzte Zahl |
| **ERREICHBARKEIT** | die Kurz-Rule trägt **kein** `paths:`/`globs:` — eine Leitplanke mit Ladebedingung ist keine. ⭐ **Ausnahme (v5.108.0):** `paths:` **und** der Rumpf nennt die Dateien der Muster → kein Bruch, Grund im Bericht `erreichbarkeit: paths-gebunden an <dateien>` — eine Bremse für `x.py` darf laden, wenn `x.py` angefasst wird. `globs:` bleibt Bruch (filtert nicht) |
| ⭐ **PFAD** | die Kurz-Rule nennt den **Zielpfad wörtlich** |
| **BESCHREIBUNG** | ≥ 40 Zeichen, und Name+description unter der Kappung bei **1 536** `[DOKU]` |
| ⭐ **INHALT** (NEU v5.24.0) | jede **Marke** der alten Regel ist in Kurz **oder** Skill wiederzufinden |
| ~ *Hinweis* `COMMAND` | die Kurz-Rule nennt `/<name>`. **Kein Bruch** — der Pfad trägt |

### ⭐ Warum Gate 5 nötig war — gemessen am eigenen Lauf, 28.08.2026

`ERHALTUNG` zählt **Zeilen**. Beim Kürzen von `workstation-fernzugriff` (63 → 36) war der
Skill 705 Zeilen lang: `36 + 705 ≥ 63` hält mühelos — und der Punkt *„das `-i` ist meist
nötig, `gnome-session` hält einen block-Inhibitor"* wäre trotzdem verschwunden. Er stand
**nur** in der alten Rule. Gefunden hat ihn erst ein von Hand danebengelegtes
`coverage_gate.py`. Gate 5 macht diese Handarbeit zum Gate.

⚠ **Es schließt AUSLASSUNG aus, nicht VERTAUSCHUNG.** Eine Marke, die vom richtigen an den
falschen Ort wandert, sehen beide Gates nicht. Die menschliche Bestätigung bleibt Pflicht.

⛔ **Der Command ersetzt den Pfad NICHT.** Er ist ein Hinweis, kein Gate — die Messung unten
sagt Pfad **4/4** gegen Command-Auswahl **20–84 %**. Wer den Pfad später entfernt, „weil der
Command ja dasteht", macht den Umzug wieder unzuverlässig.

### ⭐ Warum das PFAD-Gate das wichtigste ist — gemessen 24.08.2026

| Zugriffsweg | Trefferquote |
|---|---|
| Kurz-Rule in `rules/` | **100 %** (Ladeprotokoll, 884× `session_start`) |
| Volltext über den **Pfad** | **4 von 4** (eigene Sonden, je 1 Werkzeugaufruf) |
| Volltext über **Command-Auswahl** | **20–84 %** (Vercel-Evals, 200+ Tests) |

Ein Zeiger auf einen Command-**Namen** verlässt sich auf die 20-%-Mechanik. Ein Zeiger auf
einen **Pfad** nicht. ⚠ Die aussagekräftigste Sonde nannte die Datei **beiläufig**
(*„Alles Weitere steht in …"*, ohne Verbotszeichen) — und wurde trotzdem gelesen.

⛔ **Die Gates schließen VERLUST aus, nicht VERTAUSCHUNG.** Ein Umzug, der die Leitplanke in
den Command schiebt und die Erklärung in der Rule lässt, besteht **alle vier**.

## Step 6: Die `description` schreiben

- sagt **worum** es geht, nennt die **Auslösewörter**, die ein Nutzer wirklich benutzt
- ⛔ **kein Änderungsprotokoll** — im Zustellplan lag eine mit **1 033** Zeichen, die
  `v13..v34` aufzählte
- ⚠ **Die 200-Zeichen-Grenze aus der Memory-Welt gilt hier NICHT.** Memory hat einen eigenen
  Auswähler mit Grenze 5; Skills haben **keinen** (am Binärprogramm 2.1.237 nachgesehen).
  Die Kappung liegt bei 1 536. Gemessen half **direktiver Stil**, nicht Kürze.

### ⛔ Step 5b: Stille Kappungen — PFLICHT vor jedem Umzug (NEU v5.17.0)

```bash
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_grenzen.py" --ziel <zieldatei> --dazu <inhalt>
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_grenzen.py" --bestand "$PROJ"
```

**Ein Werkzeug, das eine stille Grenze nicht kennt, verschiebt Inhalt an einen Ort, wo er
lautlos abgeschnitten wird.** Vorher war der Text zu lang, nachher ist er **weg** — ohne Meldung.

| Grenze | Wert | Verhalten |
|---|---|---|
| `MEMORY.md` | 200 Zeilen **oder** 25 KB | ⛔ **still** weg |
| ⭐ **`paths:`-Budget** | **1 000 Muster** | ⛔ Muster bleibt unexpandiert → **die Regel feuert nie mehr** |
| `@`-Import-Tiefe | 4 Hops | ⛔ still nicht aufgelöst |
| Skill-`description` | 1 536 Zeichen | ⛔ in der Liste gekappt |
| HTML-Kommentare | — | ⛔ **vor jeder Injektion entfernt** |
| Hook-Ausgabe | 10 000 Zeichen | Rest in Datei |
| Datei | 4 MiB | **laut** übersprungen |

⭐ **Das `paths:`-Budget ist die gefährlichste.** Alle anderen kappen Inhalt. Diese eine macht
eine **ganze Regel unwirksam**, ohne dass sich etwas Sichtbares ändert. ⚠ `{a,b,c}` zählt
**expandiert** — drei Muster, nicht eins.

⛔ **HTML-Kommentare sind keine Ablage.** Wer Inhalt dort „archiviert", hat ihn **gelöscht**,
nicht versteckt. Rückgabe **2 heißt NICHT MESSBAR** — kein bestandenes Gate.

## Step 7: Nachmessen und zurückrollen

```
1. Erhaltungs-Gate          nichts verloren?
2. bestandsaufnahme.py      um wie viel ist der Bestand gefallen?
3. NEUE Sitzung + Ladeprotokoll   ist die Datei WEG aus session_start?
4. erst dann die naechste
```

⛔ **Schritt 3 kann der Befehl NICHT selbst** — er braucht eine frische Sitzung. Bis das
Protokoll es belegt, heißt der Lauf **„verschoben, Wirkung unbestätigt"**.

### ⭐ Step 7a: Das Wirkungs-Gate — hat die Korrektur die Kennzahl bewegt?

**Nutzer-Befund 30.08.2026, wörtlich:** *„`cleaner_duplikate.py` hat mir 447
Duplikate gemeldet … Ich habe die Zahl gelesen und trotzdem nur umgeräumt. **Ein
Duplikat, das umzieht, ist immer noch ein Duplikat** — jetzt nur in zwei
Dateien, die beide immer laden."*

⛔ **Modularize ist NICHT Deduplizieren.** Modularize **verschiebt** — die Summe
bleibt gleich, und der Command sagt das selbst (*„Modularize spart KEINEN
Kontext"*). Deduplizieren macht eine Stelle zum **Zeiger**; erst dann fällt die
Summe. Beides sieht im Bericht gleich erfolgreich aus.

```bash
W="$CLAUDE_PLUGIN_ROOT/references/cleaner_wirkung.py"
python "$W" --vorher  "$PROJ"                       # VOR dem Anwenden
# … anwenden …
python "$W" --nachher "$PROJ" --erwartet duplikate,zeilen
```

⭐ **Der Fingerabdruck eines verschobenen statt behobenen Duplikats:**
`wurzelzeilen` fällt, **`zeilen` bleibt stehen**. Genau diese Schere meldet das
Gate mit Rückgabe 1.

⛔ **PFLICHT nach jedem `--umzug` und jedem `--rebuild --anwenden`.** Ein
Werkzeug ohne Aufrufer ist ein totes Werkzeug — dieselbe Kern-Invariante wie
„kein Tool ohne Companion-Rule", eine Ebene höher.

⚠ **Es misst die KENNZAHL, nicht die GÜTE.** Ein Umbau, der die Zahl senkt und
den Inhalt verstümmelt, kommt hier grün durch. Dafür sind die Gates aus Step 5.

### ⛔ Step 7c: Das Kontext-Tor rückwärts — über den GANZEN Bestand

`--audit` fährt es seit v5.26.0 als **Gruppe 6** mit; die Vorschrift steht in
[references/kontext-tor.md](../../references/kontext-tor.md). Die fünf
Context-Commands fragen **vor** dem `ADD`, `--audit` fragt über den **Bestand**.

⛔ **Nur vorwärts ließe den Altbestand stehen; nur rückwärts ist der Zustand von
heute, der nachweislich wächst.** Beide Richtungen oder keine.

### ⭐ Step 7b: Die Ratsche — damit aufgeräumt auch aufgeräumt BLEIBT (NEU v5.17.0)

```bash
# beim Archivieren — der Grund ist PFLICHT
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_ratsche.py" \
       --archiviere <datei> --grund "<warum es weggeht>" --projekt "$PROJ"

# bei jedem Lauf
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_ratsche.py" --pruefe --projekt "$PROJ"
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_ratsche.py" --verlauf --projekt "$PROJ"
```

⛔ **Sie misst WIEDERAUFERSTEHUNG, nicht Bytes.** Eine Größenbremse wäre falsch: ein Bestand
**darf** wachsen, neues Wissen ist kein Fehler. **Eine Bremse gegen legitimes Wachstum ist
eine Bremse gegen Lernen.**

Was nicht passieren darf, ist etwas anderes — dass etwas **bewusst Herausgenommenes**
unbemerkt zurückkommt:

> *„`MIND_NOTFALL_TOKENS` wurde am 22.08. archiviert (Grund: im Code entfallen) und steht
> seit dem 24.08. wieder in `CLAUDE.md`."*

⚠ **Eine Wiederauferstehung ist NICHT automatisch ein Fehler.** Vielleicht wurde damals zu
Unrecht archiviert. Die Ratsche meldet **mit Vorgeschichte**, sie urteilt nicht.

⛔ **Die Ratsche misst SAETZE, nicht Woerter (v5.129.0, Etappe 41).** Gemessen 19.09.2026 am
Workspace: 71 „Wiederauferstehungen" — `DISPATCH`, `JEDEN`, `mind-all`, `knowledge/` … Marken aus
archivierten Belegen, die als Vokabular in jeder Regel stehen; kein archivierter Satz war zurueck.
Ein Eintrag traegt seit v5.129.0 seine normalisierten Saetze (`MIND_RATSCHE_SATZ_MIN`, 30 Zeichen);
auferstanden ist ein Satz, der wieder in einer geladenen Datei steht. Alt-Eintraege ohne Saetze
(01.–03.09.2026) sind **nicht messbar** — der Bericht sagt es; ihre spezifischen Marken
(`MIND_RATSCHE_MARKE_MIN` 16 Zeichen, kein blanker Ordnername, kein kurzes ALLCAPS-Wort) stehen
hoechstens als schwaches Signal, nie als Befund (rc 0).

⛔ **Ohne `--grund` gibt es keinen Eintrag.** *„X ist zurück"* ohne *„warum es wegging"* hilft
beim nächsten Mal niemandem.

⚠ **`--verlauf` ist KEIN Gate.** Er schreibt eine Zeile je Lauf mit Dateizahl und Bytes je
Ablage — eine Kurve, die man ansehen kann. Nichts bricht daran ab.

## `--rebuild` — KÜRZEN, und zwar durch VERSCHIEBEN (NEU v5.21.0)

**Dein AUDIT/REBUILD-Auftrag vom 24.08.2026, wörtlich:** *„Behalte nur die Regeln, bei denen
du ohne sie tatsächlich Fehler machen würdest. Formuliere diese Regeln so kurz wie möglich
und verschiebe alles andere in einen archive-Ordner (**niemals dauerhaft löschen**)."*
Präzisiert am 25.08.2026: das Kriterium ist *„würdest du das **VERSTEHEN** ohne diese Rule"* —
nicht „würdest du es tun".

⛔ **Bis v5.20.2 stand hier „NIE kürzen".** Das war keine Nutzer-Entscheidung (Commit
`82efd0d` dokumentiert alle anderen namentlich, diese nicht) und setzte **kürzen** mit
**löschen** gleich. Hier wird nichts gelöscht: jeder Satz landet in der Kurzfassung oder im
Archiv, und der Weg zurück steht offen.

```bash
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_rebuild.py" --bereich "$PROJ" <regel.md>
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_rebuild.py" --bereich "$PROJ" <regel.md> --auto
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_rebuild.py" --bereich "$PROJ" <regel.md> --auto --anwenden
```

⛔ **`--anwenden` geht NUR zusammen mit `--auto`** (sonst rc=2). Ohne `--auto` ist der Lauf ein
Vorschlag, und die Auswahl der Sätze gehört dir.
⛔ **Eine Datei je Lauf** — im Code gezählt, nicht als Prosa behauptet. Ein Rebuild schneidet
die Wissensbasis; zwei auf einmal heißt zwei Schnitte, die niemand einzeln angesehen hat.

### Das Gate: SATZ-Identität, gefahren VOR dem Schreiben

| | |
|---|---|
| 1 VOLLSTÄNDIG | jeder Satz aus ALT steht in KURZ **oder** im ARCHIV |
| 2 VERSCHOBEN | kein Satz steht in **beiden** (sonst kopiert statt verschoben) |
| 3 NICHTS ERFUNDEN | kein Satz in KURZ/ARCHIV, der nicht in ALT stand |
| 4 ZEIGER | die Kurzfassung nennt den **Archivpfad wörtlich** |

⛔ **Das ERHALTUNGS-Gate aus Step 5 taugt hier NICHT.** Es zählt Zeilen, und ein Archiv mit
Kopf und Datum hat **immer** mehr Zeilen als das Entnommene — es ist trivial grün. Sein
eigener Docstring sagt es: *„Die Gates schliessen VERLUST aus, nicht VERTAUSCHUNG."*

⛔ **rc=2 heißt: die Datei wurde NICHT angefasst.** Geschrieben wird erst nach den Gates, und
dann atomar.

### Drei Sperren, die kein Gate ersetzen kann

Alle drei sind **Vertauschung, nicht Verlust** — kein Satz geht verloren, alle vier Gates
bleiben grün, und die Datei ist trotzdem schlechter. Gefunden wurden alle drei beim **Ansehen
eines Diffs**, nicht von einer Zusicherung:

- **Überschrift** — `## Was ein Snapshot enthaelt` wanderte mit seinem Absatz ins Archiv, die
  Tabelle darunter blieb überschriftenlos zurück (gemessen an `env-vars.md`, 26.08.2026).
- **Tabellenzeile** — `zerlege()` gibt jede Zeile als eigenen Satz zurück; eine mittendrin
  entnommene Zeile zerreißt die Tabelle.
- **Rückbezug** — entfernt wurde *„Teilentwarnung seit 17.08.2026: … lokales Git-Repo"*,
  stehen blieb *„Die Lücke bleibt **trotzdem** bestehen"*. Das „trotzdem" zeigt ins Leere.

⚠ Die Rückbezug-Sperre ist eine **Heuristik**: sie findet den sprachlichen Rückbezug, nicht
den gedanklichen. Ihr Fenster (50 Zeichen) steht zwischen einer Positiv- und einer
Negativkontrolle und kostet gemessen 1–2 von 16–20 Kandidaten. Sie fällt zur sicheren Seite:
**ein Fehlalarm heißt, der Satz bleibt.**

### Was `--auto` bewegen darf

**Nur BELEGE.** ⛔ **Prosa nie** (352 von 620 Aussagen im gemessenen Bestand), ⛔ **gemischt
nie** (da steckt ein Gebot drin), ⛔ **`autonom-arbeiten.md` gar nicht** — sie meldet
**0 Gebote bei 31 Kandidaten**, das dokumentierte Fehlurteil des Einordners. Eine Datei, deren
Einordnung nachweislich falsch ist, wird nicht automatisch zerschnitten.

### Der Rückweg

Das Archiv liegt unter `.claude/archiv/` — **außerhalb jedes Ladepfads**. Das ist der ganze
Punkt: `geladene_dateien()` ist rekursiv, ein Archiv unter `rules/` **lädt weiter mit**.
Zurück geht es mit `cleaner_ratsche.py --entarchiviere <n>`; die Archivdatei nennt den Befehl
in ihrer eigenen Kopfzeile.

## `--paths-sonde` — misst, ob `paths:` überhaupt filtert (NEU v5.108.0)

`kontext-anlegen.md` sagt: *„dass `paths:` filtert, ist dokumentiert, nicht nachgemessen."*
Gemessen 14.09.2026 in einem Projekt: 14 Rules, 865 kB, alle `globs:`, alle laden beim Start;
2 766 Ladevorgänge im Protokoll, nie `path_glob_match`. Die Sonde misst es in **zwei Schritten**,
weil nur der Mensch eine neue Sitzung starten kann:

```bash
# 1  nach dem OK des Cleaners — die Sonde AENDERT eine Datei (wie jeder Umzug)
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_paths_sonde.py" --start "$PROJ" [--datei <rule.md>]
#    kleinste Rule mit Datei-Bezug, Sicherung nach _claude_backups/<ts>_paths-sonde/,
#    globs: -> paths: nur im Frontmatter, Merker .claude-mind/paths-sonde (datei, ts, sid, sicherung)
#    -> „neue Sitzung starten, dann /mind-cleaner erneut"  ⛔ die Sitzung startet der Mensch
# 2  im naechsten Lauf, wenn der Merker liegt
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_paths_sonde.py" --auswerten "$PROJ"
#    ⛔ v5.115.0: OHNE Merker (Tausch lief von Hand, wie im Zustellplan 15.09.) geht es auch:
#       --auswerten "$PROJ" --seit "YYYY-MM-DD HH:MM:SS" [--datei <rule.md>]
#       ohne --datei ALLE Rules mit paths: — je Rule ein Urteil, eines fuer den Bestand,
#       Satz fuer kontext-anlegen.md („paths: filtert — gemessen <Datum>, <Projekt>, n Rules,
#       Nachladen bei Dateiberuehrung"). Der Satz kommt erst mit dem ZWEITEN Projekt.
#    Ladeprotokoll SEIT dem Merker aus einer ANDEREN Sitzung: geladen mit session_start ->
#    filtert NICHT (rc 1) · geladen nur mit path_glob_match -> filtert (rc 0) · neue Sitzung,
#    Rule fehlt -> filtert (rc 0) · keine neue Sitzung -> noch nicht messbar (rc 3)
#    Ergebnis: $MIND_DEBUG_DIR/paths-sonde-<ts>.md + der Satz fuer kontext-anlegen.md (mit Datum)
```

⛔ **Rückweg ist die Sicherung** (der Merker nennt sie: `cp "<sicherung>" "<datei>"`); die Sonde
stellt nicht selbst zurück. ⚠ Die neue Sitzung darf die Datei, die die Rule nennt, **nicht
anfassen** — sonst misst sie den Treffer statt den Start.

## `--hook-bauen <datei>` — nur auf ausdrückliche Ansage

**Nutzer-Entscheidung 24.08.2026:** *„erstmal nur melden und wenn ich dann sage er soll es
bauen kann er es"*.

⛔ Ein Hook, der falsch blockt, **legt die nächste Sitzung lahm**. Deshalb: im Bericht steht
nur *„das wäre ein Hook-Kandidat, hier ist der Auslöser"*. Gebaut wird erst auf diesen
Aufruf — mit Prüffall, und ohne Eintrag in `hooks.json`, bis der Prüffall grün ist.

---

## Hard Constraints

- ⛔ **NIE ohne Snapshot.** Schlägt `mind_snapshot` fehl, bricht der Lauf ab.
- ⛔ **NIE ohne Plan mehr als eine Datei.** Seit v5.110.0 wendet EIN Plan mit EINEM ok
  alle Zeilen an — je Zeile mit Status, Snapshot als Einheit, Stopp am ersten gebrochenen
  Gate. Ohne Plan bleibt es bei einer Datei (`--nur`).
- ⛔ **NIE eine Leitplanke wegnehmen, ohne Ersatz an ihrer Stelle.**
- ⛔ **NIE behaupten, Kontext sei gespart.** Erst das Ladeprotokoll einer **neuen** Sitzung
  belegt das.
- ⛔ **NIE bei gebrochenem Gate trotzdem umziehen** — listen statt anwenden.
- ⛔ **NIE eine Datei anfassen, die nicht dem Nutzer gehört** (`upstream_datei()`).
- ⛔ **NIE LÖSCHEN.** Kein Satz verschwindet. **Kürzen heißt hier VERSCHIEBEN ins Archiv**
  (`.claude/archiv/`, liegt in keinem Ladepfad — gegen `geladene_dateien()` geprüft).
  Nutzer-Auftrag 24.08.2026, wörtlich: *„Formuliere diese Regeln so kurz wie möglich und
  verschiebe alles andere in einen archive-Ordner (**niemals dauerhaft löschen**)"*.
  ⛔ **Das Kürzen gilt NUR für `--rebuild`.** `--umzug`, `--plan` und `--hook-bauen`
  nehmen weiterhin keinen Satz aus einer lebenden Datei.
  ⚠ Bis v5.20.1 stand hier „NIE kürzen" — ohne Nutzer-Zuschreibung und im direkten
  Widerspruch zum Auftrag oben. **Kürzen war mit Löschen verwechselt worden.**

## Was der Befehl ausdrücklich NICHT tut

- **Entscheiden, was Leitplanke ist.** Er schlägt vor, der Nutzer bestätigt.
- **Den `paths:`/`globs:`-Widerspruch auflösen.** Er wird ausgewiesen, beide Seiten genannt.
- **Behaupten, der Umzug habe sich gelohnt.** ⚠ Dass ein großer Startkontext schadet, ist
  seit 24.08.2026 belegt (20 gestapelte Regeln: 96 % → 60,4 % Befolgung). **Ob 135 → 28 KB
  der richtige Betrag war, folgt aus keiner Quelle.** Belegt ist die Richtung, nicht der Betrag.


### ⛔ Step 8: Protokollieren — PFLICHT (NEU v5.21.0)

```bash
mind_debug_write "$PROJ" "mind-cleaner" "$ABSCHNITT" "$BEFUNDE"
```

**Bis v5.20.1 protokollierte KEIN einziges Cleaner-Werkzeug** — `grep -c "mind_log|logging"`
über alle acht ergab **0**, und `/mind-cleaner` meldete **nichts** an `MIND_DEBUG_DIR`,
während `/mind-all` es tut.

⛔ **Die Folge ist gemessen:** die zwei Werkzeugfehler vom 25.08.2026 (positionales Argument
still verworfen · Stamm `sicherung` gegen deutsche Prosa) sind **nur deshalb** bekannt, weil
sie zufällig auffielen. In der Wiederholungserkennung wären sie nie gelandet.

⚠ **Ein Lauf, der nichts findet, protokolliert das ebenfalls.** Ein Werkzeug, das schweigt
weil es soll, und eines, das schweigt weil es kaputt ist, sind sonst nicht zu unterscheiden
— dieselbe Lehre wie v5.3.1 (zwei Hooks mit 0 Log-Aufrufen) und v5.19.0 (die Quittung lag im
Ausfallpfad).

**Klassen für die Befundzeilen:** `instrument-misst-nichts` (das Werkzeug traf seinen
Gegenstand nicht) · `lauf-unvollstaendig` (ein Pflichtteil entfiel) · `doku-veraltet`.

## Self-Check — PFLICHT im Bericht

```
=== /mind-cleaner — Self-Check ===
[Bereich]        global | projekt | alles          Dateien: <n>
[Fremdklon]      <n> Dateien uebersprungen (nicht Eigentum des Nutzers)
[Step 1 Bestand] <bytes> in <n> Dateien (REKURSIV gezaehlt)
[Step 2 Laden]   <n> Ladevorgaenge / <n> Sitzungen — oder "kein Protokoll, KEINE Aussage"
[Step 3 Einordnung] Hook <n> · Skill <n> · Command <n> · bleibt <n> · unklar <n>
[Gates]          nur bei --umzug: <je Gate OK/BRUCH>
[Stufe]          BERICHT | PLAN | ANGEWENDET
[Wirkung]        unbestaetigt bis zum Ladeprotokoll einer NEUEN Sitzung
[Protokoll]      <n> Zeilen nach $MIND_LOG_FILE · <n> Befunde nach MIND_DEBUG_DIR
                 oder "still: nichts zu melden" — ein Lauf, der schweigt, sagt WARUM
```

⛔ Fehlt eine Zeile, ist der Bericht unvollständig und darf zurückgewiesen werden.
