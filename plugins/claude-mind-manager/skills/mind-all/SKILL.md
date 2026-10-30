---
name: mind-all
description: |
  [Mind Manager] Fuehrt ALLE Context-Management-Commands autonom nacheinander aus:
  mind-files -> mind-claudemd -> mind-memory -> mind-rules -> mind-update.
  Alle gefundenen Befunde werden automatisch angewendet (ausser DESIGN), ein
  gemeinsamer Snapshot macht den ganzen Durchlauf als EINE Einheit rueckholbar,
  am Ende steht EIN konsolidierter Bericht.

  Use when the user says "mind all", "alles pruefen", "kompletter context-sweep",
  "fuehre alle mind commands aus", "context komplett aktualisieren",
  or "/mind-all [--ask]".
argument-hint: "[--ask]"
context: inherit
allowed-tools: Read Glob Grep Edit Write Bash Agent
---

# Alle Context-Commands autonom nacheinander

> ⛔ **Warum ein Block so gebaut ist** (Vorfaelle, Messungen, fruehere Fassungen): lies `references/historie/mind-all.md`, BEVOR du einen Block aenderst oder wenn ein Schritt rot ist.

⛔ **Ein Teilsync ist kein Ergebnis und kein Endzustand. Der Lauf endet NUR mit `voll` —
er repariert, bis es voll ist, und stoppt nicht** (Nutzer 10.09.2026 „keine Ausreden",
16.09.2026 woertlich: „teilsync komplett raus aus dem plugin, verboten zu stoppen … es darf
nix uebersprungen werden oder verschoben"; v5.113.0, Step 2.96a-R). Nach zwei
Reparatur-Paessen bekommt der manager eine Nachricht (Information, der Lauf laeuft weiter).
Der Kopf-Block ist erzwungen: ohne ihn bricht jeder der fuenf Skills ab, ein Nachtrag heilt nichts.
Nichts in diesem Skill wird uebersprungen oder verschoben.

## ⛔ PFLICHTSCHRITTE — dieser Skill fuehrt aus, was hier steht (NEU v5.25.0)

```
PFLICHTSCHRITTE
arbeitsstand_render
debug_auswertung
mind_agent_bilanz
mind_check_tools_have_rules
mind_debug_write
mind_hook_health
mind_snapshot
mind_zeilenenden_waechter
```

⛔ **ZUERST das Kontingent (v5.163.0, Nutzer 29.10.2026):** das Werkzeug `get_usage` (`mcp__ccd_session_mgmt__get_usage`) aufrufen und im Kopf-Block `<5h>` und `<woche>` durch `percentUsed` von „5-hour limit“ und „Weekly · all models“ ersetzen — nicht lesbar: `unbekannt`, dann startet nichts. Ab `MIND_KONTINGENT_MAX` (Vorgabe 80 %) startet nichts; Werte und Ruecksetzzeit gehoeren in die Antwort. Notausgang: `--trotz-kontingent`. Die fuenf Skills der Kette pruefen nicht erneut (der Lock sagt es ihnen).

**Vor dem ersten Schritt, ohne Ausnahme:**

```bash
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { CLAUDE_PLUGIN_ROOT=$(jq -r '.plugins["claude-mind-manager@kohlosseum"][0].installPath // empty' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null); [ -n "$CLAUDE_PLUGIN_ROOT" ] && { CLAUDE_PLUGIN_ROOT=$(cygpath -u "$CLAUDE_PLUGIN_ROOT" 2>/dev/null || printf '%s' "$CLAUDE_PLUGIN_ROOT"); echo "WARN: CLAUDE_PLUGIN_ROOT war leer — Rueckfall auf installed_plugins.json: $CLAUDE_PLUGIN_ROOT (v5.107.0)" >&2; }; }   # v5.107.0 Rueckfall
[ -n "$CLAUDE_PLUGIN_ROOT" ] || { echo "ERROR: \$CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 1; }
export CLAUDE_PLUGIN_ROOT   # v5.163.0: sonst sehen die Bloecke sie leer (Ritas Lauf 30.10.)
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ=$(mind_projekt_wurzel)    # v5.80.0: der Ordner mit rollen.md, sonst cwd
mind_kontingent_pruefen "$PROJ" mind-all '$ARGUMENTS' "<5h>" "<woche>" || exit 1   # v5.163.0: VOR mind_schritt_start, dieselbe Bash
# ⛔ v5.77.0: DIE VERSION DIESES SKILL-TEXTS. lib.sh vergleicht sie mit
#    basename "$CLAUDE_PLUGIN_ROOT" und meldet VERSIONSBRUCH, wenn ein alter
#    Text gegen neuen Code laeuft (Rita bekam am 10.09.2026 den Text aus 5.2.0).
#    ⚠ Wird beim Release nachgezogen; das Zaehl-Gate prueft alle elf.
#    ⛔ v5.125.0: DIESELBE Bash wie mind_schritt_start — sonst rc 1, keine Startzeile (Etappe 37 §3).
MIND_SKILL_VERSION="5.172.0"
mind_schritt_start "$PROJ" mind-all arbeitsstand_render debug_auswertung mind_agent_bilanz mind_check_tools_have_rules mind_debug_write mind_hook_health mind_snapshot mind_zeilenenden_waechter
```

**Nach JEDEM Schritt** — auch nach einem, der entfaellt:

```bash
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
mind_schritt <name> gelaufen              "$(wc -c < "$AUSGABE")" "$PROJ"
mind_schritt <name> "gelaufen:5/11"       "$BYTES" "$PROJ"   # TEILABDECKUNG
mind_schritt <name> "uebersprungen:<grund>" 0      "$PROJ"
mind_schritt <name> "fehler:<grund>"      -1       "$PROJ"
```

⛔ **`uebersprungen` ist ein gueltiger Status und braucht einen GRUND.** Ein legitim
entfallender Schritt (kein Git, kein Quellbaum) ist kein Fehler, gehoert aber in den Bericht.

⛔ **v5.67.0: EINEN PFLICHTSCHRITT AUSZULASSEN, WEIL ER TEUER AUSSIEHT, IST VERBOTEN.**
Nutzer-Auftrag 10.09.2026: *„die sollen alles fahren"*. ⭐ Die Trennlinie:

| | |
|---|---|
| ⛔ **verboten** | gar nicht **starten**, aus Ruecksicht auf Kontext, Zeit oder Kosten |
| ✅ **erlaubt** | starten und **scheitern lassen** — `bytes:0` faengt die Bilanz |

Ein gestorbener Agent ist ein **Befund**, ein nie gestarteter eine
**Luecke, die wie ein Ergebnis aussieht**. ⚠ „Ressourcengrund" ist **kein**
zulaessiger `uebersprungen:`-Grund. Seit v5.67.0 macht eine Teilabdeckung den Lauf zum **Teilsync**:
die Schuld bleibt liegen, bis alles gefahren ist.

⭐ **`gelaufen:5/11` ist die TEILABDECKUNG und der Anlass dieses Baus.** 30.08.2026:
`cleaner_leitplanke.py` lief ueber 5 von 11 Dateien und wurde als **Bereichspruefung**
berichtet. `5/11` ist eine gueltige Antwort, als `11/11` berichtet ist sie es nicht.
⚠ **`X/Y` mit X=Y (`1/1`) zaehlt seit v5.113.0 als voll** — vollstaendig heisst trotzdem
`gelaufen`, nicht `1/1` (Nora 16.09.2026). ⛔ **Nachquittieren geht nur im SELBEN
Block:** die Bilanz nimmt den letzten Eintrag je Block×Name; ein spaeterer Block heilt nichts — den Block erneut fahren (mind-all 2.96a-R).
⛔ **Eine geloeschte oder leere Schritt-Quittung wird nicht nachgetippt — der Block wird neu
gefahren** (v5.116.0, Doro 16.09.2026: 39 Schritte in 5 s nachgetippt, Bilanz 39/39).
Die Bilanz erkennt getippte Bloecke (Starts < `MIND_SCHRITT_MIN_S` = 60 s auseinander, >= 5 Schritte
in 10 s) als FORMAL, der Lauf ist teil.

⛔ **Die Bytezahl ist Pflicht, wo ein Schritt etwas ausgeben MUSS.** 30.08.2026:
`cleaner_belege.py` lief, die Ausgabe wurde weggegreppt, eine naive Quittung saehe „gelaufen". `0` meldet die Bilanz als **LEER**; `-1`
heisst „nicht gemessen" und zaehlt nicht.

**Im Bericht, als erste Zeile des Self-Checks:**

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-all/bloecke/pflicht-bilanz.sh"
```

⛔ **Fehlt diese Zeile oder nennt sie `FEHLT`, ist der Bericht unvollstaendig** und
darf zurueckgewiesen werden. Rueckgabe **2 = gar keine Quittung**, NICHT „nichts zu melden".

⚠ **Grenze:** die Quittung erzwingt keinen Schritt (macht Fehlen sichtbar, wie `decision:block`
und die Agent-Quittung) und misst nicht die GUETE: Unsinn quittiert als `gelaufen`.

Ein Snapshot -> 5 Skills sequenziell -> alle Befunde angewendet -> ein Bericht.

## Step -1: Was ist hier schon einmal schiefgegangen? (PFLICHT, NEU v5.7.1)

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-all/bloecke/step-1-debug.sh"
```

⛔ **Das steht VOR Step 0.** Bis v5.7.0 wurde der Debug-Ordner nie *vor* der Arbeit gelesen; 21.08.2026:
die Klasse „Instrumentenkontrolle verglich nur Befund-ANZAHLEN" stand seit dem Vortag darin und wurde am naechsten Tag erneut gebaut. **Sichtbarkeit ohne Lese-Anlass ist wirkungslos.**

Die Ausgabe ist kein Befund und blockt nichts — sie ist eine Erinnerung an drei Zeilen.


## Step 0: Modus + EIN Snapshot fuer den ganzen Durchlauf (PFLICHT)

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-all/bloecke/step0-snapshot.sh"
```

Bricht der Block ab (kein Snapshot), startet KEIN Skill. Ein Hook-Ausfall ist kein Abbruchgrund, gehoert aber in den Schlussbericht, ebenso der VERLAUF-Hinweis. ⭐ Warum die
Bloecke so gebaut sind: Kommentare in `bloecke/*.sh` — lesen, BEVOR ein Block geaendert wird oder wenn ein Schritt rot ist.

**Geretteter Chat (v5.1.0) + offene Schuld (v5.2.1):** Existiert `.claude-mind/rescued/OPEN`,
steht ein Sync aus. `OPEN` nennt die Rettungsdatei und den gesicherten Auftrag.
```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-all/bloecke/step0-rettungen.sh"
```

> ⭐ **v5.160.0 — das Verlaufsbuch zuerst:** `.claude-mind/verlauf/<sid>.md` traegt je Kompaktierung einen Abschnitt (Arbeitsstand + Claudes Zusammenfassung, 20–30 KB); nennt die Rettungsliste dazu `-> Verlaufsbuch (zuerst lesen)`, bekommt der Agent DIESEN Pfad zuerst und die Rettung nur als Rueckfall.
>
> ⛔ **KONTEXT-FLUT-SPERRE (NEU v5.2.1, Hard Constraint).** Die Rettungsdatei `*_chat.md` wird
> **NIE im Hauptkontext gelesen** — kein `Read`, `cat`, `head`/`sed` auf ihren Inhalt
> (417 KB / 555 Beitraege gemessen). Erlaubt nur: **(i)** den **Pfad** an einen Subagenten uebergeben
> (eigener Kontext, Groessen-Guard), **(ii)** zaehlende Aufrufe (`grep -c`, `wc`).
>
> Invariante, keine Empfehlung: Der Lauf wird per Stop-Hook direkt nach einer Kompaktierung erzwungen;
> die Datei im geleerten Kontext loest die naechste Kompaktierung und Rettung aus. Ein `Read` darauf im Hauptfluss ist ein **Abbruchgrund**.

**EIN Snapshot fuer alle 5** — nicht fuenf einzelne. Damit ist der komplette Durchlauf als
eine Einheit zurueckrollbar. Die Einzel-Skills erkennen den laufenden `/mind-all` an der
`analyzed-scopes`-Datei und legen **keinen** zweiten Snapshot an.

**Schlaegt der Snapshot fehl: kein einziger Skill startet.**

## Step 1: Reihenfolge (fest, begruendet)

| # | Skill | Warum an dieser Stelle |
|---|---|---|
| 1 | `mind-files` | Legt fehlende Context-Dateien ueberhaupt erst an — die folgenden koennen nur auditieren, was existiert |
| 2 | `mind-claudemd` | CLAUDE.md ist die Wurzel; Version/Struktur muss stimmen, bevor andere darauf verweisen |
| 3 | `mind-memory` | MEMORY.md + Topic-Files, haeufig Ziel von claude-md-Auslagerungen |
| 4 | `mind-rules check` **+** `migrate` | Rules-Syntax/-Inhalt. **Subcommand PFLICHT:** ohne Argument macht mind-rules nur `list` (zeigt eine Tabelle, fixt nichts) — in der Kette waere das ein Leerlauf |
| 5 | `mind-update` | **Zuletzt** — der uebergreifende Sweep + Knowledge-Sync; profitiert davon, dass 1-4 sauber sind, und deckt den Rest ab |

**Strikt sequenziell.** Nie zwei Skills gleichzeitig, nie ein Skill parallel zu Agents eines
anderen (Anti-Burst `~/.claude/rules/shared-tools.md` (Block „Agents“): nie ≥3 Agents gleichzeitig; im Skill gilt dessen Grenze).

## Step 2: Ausfuehrung je Skill

⛔ **Anwenden IST die Vorschrift — auch im Rollen-Aufbau (v5.168.0, Etappe 65 Nachtrag 3).** Dieser Lauf wendet an, was
die fuenf Skills vorschreiben (`AUTO_MODE=yes`: UPDATE/ENRICH/ADD/NEW_FILE, DESIGN nie), in jeder Context-Datei, die er
bearbeitet — egal, welche Sitzung im Roster eine Datei „besitzt“. Der Roster regelt Handarbeit der Sitzungen; „Report,
do not fix“ der sync-Rolle betrifft Funde AUSSERHALB einer Vorschrift (`manager-chats.md`: „allowed is what a skill
prescribes“). Gemessen im vollen Lauf 30.10.2026: „als Sync darf ich nichts aendern, was dem Arbeiter gehoert“ — 0
angewendet (alt 4). Nicht angewendet wird nur mit Grund im Bericht (DESIGN, Stufe 3 ohne Leser, Overwrite-Guard).

Fuer jeden der 5 in der Reihenfolge oben:

1. **ZUERST die SKILL.md des Skills lesen** — `$CLAUDE_PLUGIN_ROOT/skills/<name>/SKILL.md` —
   und sie dann **vollstaendig** ausfuehren (inkl. Self-Check-Bloecken und Pflicht-Schritten).
   ⛔ **Als Erstes den Kopf-Fence des Skills ausfuehren** (`mind_schritt_start …`), erst danach seine Bloecke (v5.165.0).
   Die Bloecke verweigern sonst den Start mit `KOPF FEHLT` (rc 3). Im A/B-Lauf vom 30.10.2026 wurden sie direkt aus
   `bloecke/` gefahren; ihre Quittungen landeten beim falschen Skill, Ergebnis 17/58, 1/5 echt.
   Nicht aus der Beschreibung improvisieren. **Skill-Logik ausfuehren** wie dort beschrieben — mit den durchgereichten
   Flagge `AUTO_MODE`. Kein erneuter Snapshot (Step 0 hat ihn).
   ⛔ **v5.98.0 — „vollstaendig" heisst: mit seinem EIGENEN Start-Block.** Die erste Bash
   des Skills ist dessen Kopf aus seiner SKILL.md — `MIND_SKILL_VERSION=…` und
   `mind_schritt_start "$PROJ" <skill> <seine Pflichtschritte>` **in derselben Bash** —,
   die letzte ist `mind_schritt_bilanz "$PROJ"`. Dazwischen laufen seine Agenten
   (`context-analyzer`, `project-scanner`) wirklich. `mind_schritt_bilanz --alle` verlangt
   seit v5.98.0 **fuenf Start-Bloecke seit der mind-all-Startzeile**; fehlt einer, ist der
   Skill FORMAL und der Lauf ein Teilsync (`formal-<skill>` in `ungepruef=`). Rita 12.09.2026:
   fuenfmal quittiert, Agent-Quittung echt, trotzdem FORMAL=5 (fuenf Schritte EINES Blocks, context-analyzer/project-scanner liefen nie).
2. **Laufspur schreiben — PFLICHT, nach JEDEM der fuenf** (NEU v5.19.0):
   ```bash
   [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
   mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
   echo "skill=<name>|$LAUF" >> "$SCOPES_FILE"   # nach jedem der 5, ohne Ausnahme
   ```
   ⛔ **v5.30.0: die Laufkennung `|$LAUF` ist PFLICHT.** Sie macht eine Kollision **erkennbar**, wenn die Sperre versagt; ohne sie schweigt das Instrument im
   Ausfall (`werkzeuge-zuerst.md`).
   ⛔ **Sie kommt aus `basename "$SNAPSHOT"`, NICHT aus `CLAUDE_SESSION_ID`.**
   ⭐ **v5.66.0:** `CLAUDE_CODE_SESSION_ID` waere verfuegbar, die
   Kennung benennt aber den LAUF, nicht die Sitzung; die SITZUNGSkennung der Sperre kommt seit v5.66.0 aus der
   Umgebung. `CLAUDE_SESSION_ID` ist in einer Skill-Bash **leer** (gemessen): ein Waechter darauf zaehlt **alle** Zeilen, auch fremde, und **sieht aus,
   als greife er** — schlimmer als keine Sperre.
   **2b · Bericht als DATEI, dann die Quittung mit `--datei` (v5.97.0), IM eigenen Block
   (v5.98.0) — vor dessen `mind_schritt_bilanz`:** den Bericht des Skills (sein
   Self-Check-Block, woertlich) mit `Write` nach `$PROJ/.claude-mind/bericht-<skill>.md`
   legen, dann:
   ```bash
   [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
   mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
   mind_schritt <skill> gelaufen --datei "$PROJ/.claude-mind/bericht-<skill>.md" "$PROJ"
   ```
   ⛔ **Ohne `--datei` schreibt `mind_schritt` `uebersprungen:kein-artefakt`**, und
   `mind_schritt_bilanz --alle` zaehlt den Skill als FORMAL — ebenso ohne
   eigenen Start-Block oder bei zwei Quittungen in derselben Sekunde. Gemessen (10.09. 14:49, 11.09. 21:44,
   12.09. 00:02): getippte Bytes 300/700/400/300, im Lauf 00:02 alle vier in derselben Sekunde.
   **Ein FORMAL macht den Lauf zum Teilsync** (Step 2.96a: `formal-<skill>` in `ungepruef=`).
   ⛔ **Eigener Schluessel, getrennt von den Scope-Marken unten:** `skill=` = *„dieser Teil lief"*, Scope-Marke = *„diese Analyse lief in diesem Modus"*; ein Schluessel haette die
   Dedup-Logik in Schritt 5 verbogen.
   **Ohne diese Zeile ist der Lauf nicht zaehlbar**, Step 2.96a kann `SYNC_LIEF` nicht
   ableiten (bis v5.18.0 fehlte sie: Lauf 24.08.2026 ohne Spur, `analyzed-scopes.done` trug den Vortag).
3. **Scope-Marke schreiben — NUR mit Modus-Angabe** (M3-Fix):
   ```bash
   [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
   mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
   echo "claude-md=mind-claudemd:default" >> "$SCOPES_FILE"   # nach mind-claudemd
   echo "memory=mind-memory:default"      >> "$SCOPES_FILE"   # nach mind-memory
   # KEINE rules-Marke: mind-rules hat gar keinen `Agent` in allowed-tools und macht
   # ueberhaupt keine semantische Analyse — eine rules-Marke wuerde den rules-Agent in
   # Schritt 5 unterdruecken, ohne dass je einer gelaufen waere.
   ```
4. **Ergebnis sammeln** (angewendet / DESIGN / offen / Fehler) fuer den Schlussbericht.

**Scope-Dedup in Schritt 5 — nur bei GLEICHEM Modus (M3-Fix, kritisch):**
`mind-claudemd`/`mind-memory` dispatchen den context-analyzer mit **`mode: default`**
(Quality-Score, Duplikate — **ohne Session-Auszug**). `mind-update` Step 3.5 braucht aber
**`mode: knowledge-sync`** MIT Session-Auszug — das ist eine **andere Analyse mit anderem
Ergebnis**. Deshalb: **ein `:default`-Eintrag darf einen `knowledge-sync`-Dispatch NICHT
unterdruecken.** Uebersprungen wird nur, was mit **demselben Modus** schon lief.

Praktisch heisst das: in der Kette laufen die 4 knowledge-sync-Agents **normal**. Der Dedup
greift erst, wenn ein Skill kuenftig selbst `knowledge-sync` faehrt.

⛔ **Ein Agent mit LEERER Rueckgabe ist ein Problem, kein „unauffaellig" (NEU v5.7.1).**
21.08.2026: der `rules`-Agent meldete „completed" nach 163 s und 31 Werkzeugaufrufen mit **0 Byte**.
„nichts gefunden" waere ein ungeprueftes Feld als geprueft.

**Pflicht bei leerer Rueckgabe:**
1. Den Bereich als **UNGEPRUEFT** in den Bericht schreiben, nicht als „keine Befunde".
2. **Sofort auf den grep-Weg zurueckfallen.** Am 21.08. unter einer Minute, mit dem gesuchten Befund.
3. Den Ausfall als Klasse `agent-gestorben` in die Befundzeilen aufnehmen (Step 2.95).

### ⛔ Wiederholen: HOECHSTENS EINMAL, und nur mit engerem AUFTRAG (NEU v5.21.2)

Ein zweiter Lauf kann auch scheitern und kostet: `Pc Forschung` 26.08.2026: **660 000 Tokens fuer zwei Wiederholungen ohne ein Byte Ertrag.**

| erlaubt | verboten |
|---|---|
| **einmal** neu, mit **engerem AUFTRAG** | dieselbe Aufgabe mit kleinerer EINGABE |
| ein Auftrag statt zwei, 4–5 benannte Dateien | „nochmal, vielleicht klappt es" |

⛔ **Die Eingabe zu verkleinern hilft NICHT — gemessen, nicht vermutet:**

```
Lauf 1, Rettungsdatei 1049 KB   claude-md  186 674 Tok / 20 Aufrufe -> 0 Byte
                                memory     180 284 Tok / 26 Aufrufe -> 0 Byte
Lauf 2, Auszug         339 KB   rules      335 159 Tok / 20 Aufrufe -> 0 Byte
                                memory     325 160 Tok / 24 Aufrufe -> 0 Byte
```

**3,1x kleinere Eingabe, MEHR Tokens, vier von vier gleichfoermig tot.**

⭐ **Ein Agent am Turn-Limit (`maxTurns`, 50 seit v5.168.0, vorher 25) ist KEIN Wiederholungsfall** (v5.96.0): der `tool_result` endet
ohne Bericht, der Agent lebt. Fortsetzung ist `SendMessage {to: <agentId>, message: „Bericht
jetzt liefern“}` — kein neuer `Agent`-Aufruf (Rita 12.09.2026: beide lieferten danach). Im Desktop-Reiter „Code“ erst `ToolSearch select:SendMessage`.

Nach dem zweiten leeren Agenten: Bereich ungeprueft, grep-Rueckfall, beides im Bericht.

⚠ Eine gelungene Wiederholung wird **quittiert** (`mind_agent_ergebnis` erneut) —
`mind_agent_bilanz` wertet seit v5.21.2 den **letzten** Eintrag je Bereich und meldet den
Verlauf als `WIEDERHOLT`. Der gestorbene Agent verschwindet damit nicht spurlos.


**Ersparnis ist KEIN Skip-Grund** (M4-Fix): Wenn der Modus nicht uebereinstimmt, wird
dispatcht — egal was das kostet. Der Knowledge-Sync ist laut `mind-update` Teil der
Identitaet des Skills, nicht seine Kuer.

**Fehler-Verhalten:** Scheitert ein Skill, laufen die **restlichen weiter**. Der Fehler kommt
in den Schlussbericht (`FEHLGESCHLAGEN: <skill> — <grund>`); ein toter Skill darf die Kette nicht killen.

## Step 2.9: Kettenmarke abraeumen (PFLICHT, C1-Fix)

**Direkt nach dem letzten Skill, VOR dem Bericht:**

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-all/bloecke/step2.9-kettenmarke.sh"
```

**Kein Beiwerk:** Einzel-Skills erkennen die Kette an dieser Datei und ueberspringen ihren Snapshot. Bleibt sie liegen, editiert **jeder spaetere
Einzellauf** **ohne Netz** — dauerhaft. Der Schritt laeuft IMMER, auch nach gescheiterten Skills.

## Step 2.95: `listeverbesserungen.md` fortschreiben (PFLICHT, NEU v5.2.1)

**Jeder** `/mind-all`-Lauf haengt einen Abschnitt an `<projekt>/listeverbesserungen.md` an —
auch ein Handaufruf ohne Kompaktierung, auch ein Lauf ohne einen einzigen Fund.

⛔ **Bis v5.6.0 nur eine Vorlage** (Anhaengen von Hand mit `>>`, ohne Zeilenenden-Pruefung). Seit v5.7.0 Code; der Abschnitt geht **zusaetzlich zentral** hinaus.

**Zuerst mit `Write` zwei Dateien anlegen, DANN den Block:** den Abschnitt (Aufbau unten) nach
`$PROJ/.claude-mind/lauf-abschnitt.md` und je Befund eine JSON-Zeile nach
`$PROJ/.claude-mind/lauf-befunde.jsonl` (keine Befunde: Datei weglassen). Fehlt der Abschnitt,
bricht der Block ab und sagt es. ⚠ Bis v5.151.0 leerte der Block die Befund-Datei, bevor er sie
meldete — ein Befund kam so nie im Debug-Ordner an.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-all/bloecke/step2.95-liste.sh" "<Ausloeser: Kompaktierung manual|auto oder Handaufruf>"
```

**Die Ursachenklassen** — feste Liste, **kanonisch ist `KLASSEN` in `references/debug_auswertung.py`**:
`instrument-nachgebaut` · `instrument-misst-nichts` · `instrument-meldet-falsch` ·
`zahl-in-falscher-rolle` ·
`windows-pfad` · `zeilenenden` · `agent-fehlbericht` · `agent-gestorben` ·
`lauf-unvollstaendig` · `plugin-defekt` · `doku-veraltet` · `sichtbarkeit` ·
`ungeklaerter-widerspruch` · `sonstiges`

⚠ Die Zahl stand als Wort hier und war falsch („elf“ = 11 Namen, Code **12**: `lauf-unvollstaendig` fehlte seit v5.19.0). Statt einer Zahl der Zaehlbefehl:

```bash
python -c "import sys;sys.path.insert(0,'$CLAUDE_PLUGIN_ROOT/references');from debug_auswertung import KLASSEN;print(len(KLASSEN))"
```

## ⭐ Das Feld `ursache` — optional, seit v5.41.0

Ein Befund darf zusaetzlich zur `klasse` eine **Ursache** tragen. Feste Liste,
kanonisch ist `URSACHEN` in `references/debug_auswertung.py`:

```
erreicht-gegenstand-nicht   Muster, Bereich oder Quelle lagen daneben — es lief
nicht-treffer-als-befund    eine NULL als Aussage gelesen statt als kaputte Messung
werkzeug-falsch-aufgerufen  falsche Argumente oder Signatur — es lief gar nicht
falsche-bezugsgroesse       richtig gerechnet, falsch bezogen
sonstiges                   passt in keine der obigen
```

⚠ **Das Feld ist OPTIONAL, mit Absicht:** ein Pflichtfeld zwaenge zum RATEN. Fehlt es, heisst das `nicht-zugeordnet`, **kein Mangel**.

⛔ **Warum:** Punkt 9 (08.09.2026) zerlegte `instrument-misst-nichts` aus den Texten: 70 % blieben
UNBESTIMMT, weil **66 % der Eintraege kuerzer als 120 Zeichen** sind und je einen anderen Mechanismus frei beschreiben. Ein besseres Muster war die falsche Antwort.

⛔ **Nicht nachtraeglich zuordnen.** Eintraege vor v5.41.0 bekommen keine Ursache (Geschichtsfaelschung, wie im Docstring von `debug_aufraeumen.py` seit v5.9.2).

⛔ **Eine neue Klasse gehoert an BEIDE Stellen im selben Commit** — Code und diese Liste. Sonst sieht das Plugin erweitert aus und verhaelt sich wie vorher (Halbfix-Regel aus `CLAUDE.md`, zum dritten Mal).

Aufbau je Lauf — **angehaengt**, nie vorangestellt (Anhaengen kann eine bestehende Datei nicht
beschaedigen, Umschreiben schon):

```markdown
## <JJJJ-MM-TT HH:MM> — /mind-all  (Ausloeser: Kompaktierung <manual|auto> | Handaufruf)

### Probleme in diesem Lauf
- <was scheiterte: Agent ohne Ergebnis, Snapshot fehlgeschlagen, Datei unlesbar,
  Groessen-Guard gegriffen, Hook-Herzschlag veraltet, jq/cygpath fehlt, Skill abgebrochen …>

### Verbesserungsvorschlaege
- <konkret, mit Datei und Stelle — kein "koennte man mal">

### Nicht angewendet (und warum)
- <DESIGN-Befunde / >5 tote Pfade / Overwrite-Guard / fehlende Freigabe>
```

**Regeln, ohne die die Liste Dekoration waere:**
- `- (keine)` ist eine **zulaessige** Antwort. Ein **leerer** Abschnitt ist es nicht — ein Lauf
  ohne Eintrag gilt als nicht protokolliert.
- **Ein gescheiterter Agent ist ein PROBLEM, kein "unauffaellig".** Ein Null-Ergebnis heisst
  „ungeprueft", nicht „nichts gefunden" (`~/.claude/rules/shared-tools.md` (Block „Agents“)).
  „(keine)" bei gestorbenem Agent macht den Mechanismus wertlos.
- Auch **eigene** Fehlgriffe gehoeren hinein (falsche Annahme, verworfener Zwischenstand) —
  die Liste ist ein Arbeitsprotokoll, keine Erfolgsmeldung.

## Step 2.95: Zeilenenden-Waechter (PFLICHT, NEU v5.11.0)

**Nach der Kette, vor dem Bericht.** Kein einzelner Fix darf die Zeilenenden einer Datei
kippen.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-all/bloecke/step2.95-waechter.sh"
```

⛔ **Rueckgabe 2 ist ein BEFUND:** hoechstens eine Datei verglichen, **nichts** geprueft. Offener Punkt im Bericht, niemals „keine Abweichung".

⛔ **Bis v5.12.0** bildete ein 12-zeiliger Codeblock `$PROJ/$z` fuer jeden Snapshot-Pfad, der Snapshot hat aber vier Zweige (`project/`, `rules/`, `global/`,
`memory/`), keiner unter `$PROJ/<zweig>/`: **gemessen 1 von 68** (Zustellplan, 22.08.2026), „keine Abweichung" bei 67 nie angesehenen Dateien.

⚠ Ein Markdown-Codeblock ist von keinem Prueffall aufrufbar; die Logik liegt seit v5.13.0 in `lib.sh`
(`mind_zeilenenden_waechter`, `mind_schnappziel`) und wird von `tests/test_zeilenenden.sh`
mit einem Snapshot gefahren, in dem **genau eine** Datei gekippt ist.

⛔ **Gemessen wird der CRLF-ANTEIL, nicht die Zeilenzahl.** „Zeilenzahl unveraendert" ist bei diesem Fehler **gruen** und liess ihn schon einmal durch.

**Warum:** In `APP - Zustellplan` kippte eine Reparaturrunde **4 Quelldateien**
von LF nach CRLF (gegen `.editorconfig`), Diff **6417/6152 Zeilen statt
311/46**. Ein zweiter Fall: Ersetzungsanker gerissen (Zieldatei CRLF, Muster LF).

⚠ **Gekippte Zeilenenden werden GEMELDET, nicht stillschweigend zurueckgedreht.**
Zurueckdrehen waere ein unbeauftragter Eingriff, in einem CRLF-Projekt der falsche. Der Bericht nennt Datei und Anteil; der Snapshot aus
Step 0 macht die Ruecknahme moeglich.

## Step 2.96a: `sync-stand` setzen (PFLICHT, NEU v5.7.0)

**Direkt nach einem tatsaechlich gelaufenen Sync** — und zwar unabhaengig davon, ob eine
Schuld bestand:

### ⛔ v5.19.0: `SYNC_LIEF` wird ABGELEITET, nicht behauptet

Bis v5.18.0 stand hier `[ "$SYNC_LIEF" = "ja" ]`, **kein Code** wies die Variable zu (24.08.2026: 2 Lesezugriffe, **0 Zuweisungen**); das Modell setzte sie aus Absicht — Selbsteinschaetzung, die `cleaner_belege.py` seit v5.18.0 sonst ersetzt.

⛔ **Diesen Block mit `timeout: 600000` aufrufen (v5.164.0).** Er rechnet ~30–60 s und wartet ab Reparatur-Pass 3
bis zu 600 s. Mit der Vorgabe von 120 s schiebt ihn das Bash-Werkzeug in den Hintergrund. Im A/B-Lauf vom 30.10.2026
(`claude -p`) endete die Sitzung dann mit „warte auf Block-Ende“, und es wurde kein `sync-stand` geschrieben.
**Nie auf einen Hintergrund-Block warten und den Turn beenden.** Ist er doch dort gelandet, seine Ausgabedatei lesen, bis `ABSCHLUSS:` darin steht.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-all/bloecke/step2.96-abschluss.sh"
```

⚠ **`nein` und `teil` sind verschiedene Dinge.** `nein` heisst: kein einziger Skill lief
(Abbruch in Step 0/1) — dann entsteht kein Merker und die Schuld bleibt unberuehrt
bestehen. `teil` heisst: Kette lief, Fan-out nicht — der Merker **traegt seine eigene Unvollstaendigkeit**.

### ⛔ 2.96a-R: bei `teil` REPARIEREN, bis es voll ist (v5.113.0, Etappe 20 §2 + Nutzer 16.09.)

`mind_lauf_voll` sagt `teil` → der Lauf ist NICHT fertig, und er ENDET auch nicht. 16.09.2026 (Palvedo, Nora): Kopf-Block nach den Skills, fuenf `formal-*`, `0/5 echt`, Teilsync
geschrieben, OPEN mit drei Rettungen blieb; das Werkzeug meldete richtig und liess den Lauf DAMIT ENDEN. **Nutzer
16.09.2026, woertlich:** *„teilsync komplett raus aus dem plugin, ist verboten zu stoppen oder
ueberhaupt auf die idee zu kommen auch nur ein wort oder zeile vom plugin zu missachten, es
darf nix uebersprungen werden oder verschoben."*

```bash
# laeuft in step2.96-abschluss.sh mit (Step 2.96a) — KEIN eigener Aufruf
```

⛔ **Kein Pass-Limit, kein Abbruch, kein Verschieben — ab Pass 3 warten, nie abbrechen.**
Die Meldung nach dem zweiten Pass macht die Arbeit sichtbar, ersetzt sie nicht; bis zur Antwort des manager laeuft die Reparatur.

```bash
# laeuft in step2.96-abschluss.sh mit (Step 2.96a) — KEIN eigener Aufruf
```

⛔ **Seit v5.65.0 traegt `sync-stand` KEINE Tokenzahl mehr.** Er sagt nur noch,
**was** gelaufen ist (`umfang=`) und **was fehlt** (`ungepruef=`). Verbraucht wird er
von `pre-compact.sh` bei der naechsten Kompaktierung.

⛔ **Historie `tokens=`:** v5.11.0 bis v5.64.0 zaehlte der ZUWACHS seit dem Sync (`MIND_SYNC_DELTA`), weil `pre-compact.sh` unter `autoCompactEnabled: false` nur bei handgetipptem `/compact` feuerte; `/mind-all` schaltete die Kette so stumm (21.08.2026, `APP - Palvedo`, Merker seit 08:00 bei 950 000 Tokens). ⭐ Auto-Kompaktierung seit 23.08.2026 wieder scharf (~966 000, zwei Projekte) — die Zahl verlor ihren Anlass.

## Step 2.96b — ⛔ ENTFALLEN in v5.65.0

Hier bat `/mind-all` bei `COMPACT-FAELLIG` um ein `/compact`; der Merker war token-getriggert und ist weg.

⚠ **Preis:** das war das **einzige**, was je um eine Kompaktierung bat. Folgenlos bei scharfer Auto-Kompaktierung; ohne sie feuert `pre-compact.sh` nie — keine Chat-Rettung, kein `RESUME.md`, kein Arbeitsstand.

⛔ Eine Kompaktierung ist **nicht ausloesbar** — weder aus einem Hook (nur `decision:block`) noch vom Assistenten (kein Werkzeug fuer `/compact`); nur der Mensch tippt sie.
⛔ Und **nicht** umformulieren zu *„die Kompaktierung kommt von selbst"*: so stand es bis v5.7.4, das war der Fehler.

## Step 2.96: Schuld begleichen (PFLICHT, NEU v5.2.1)

Erst **nach** einem tatsaechlich gelaufenen Sync (nicht nach Abbruch von
mind-update) wird die offene Schuld entfernt — sonst blockt der Stop-Hook zu Recht weiter:

⛔ **Hier steht `= "ja"` und bleibt dabei.** Bis v5.112.0 stand in Step 2.96a `!= "nein"`: ein Teilsync setzte einen Merker, beglich aber
**keine Schuld** (v5.19.0). Seit v5.113.0 wird ein Teilsync nicht mehr geschrieben (2.96a-R
repariert, bis voll); beide Bloecke haengen an `ja`, `OPEN` verschwindet nur hier.

```bash
# laeuft in step2.96-abschluss.sh mit (Step 2.96a) — KEIN eigener Aufruf
```

**Die Rettungsdateien `*_chat.md` bleiben liegen** — sie sind das Archiv. Entfernt wird nur
die **Schuld**, nicht der Beleg.

⛔ **v5.4.1: Teilerfolg ist kein Erfolg.** `OPEN` wird nur entfernt, wenn **ALLE** offenen
Rettungen eingespeist wurden. Bricht der Lauf nach der ersten ab, bleiben die uebrigen
`path=`-Zeilen stehen und der Stop-Hook hakt zu Recht weiter nach. Zu frueh begleichen wiederholt den Fehler von v5.2.0, eine Ebene tiefer.

**Wenn der Sync NICHT lief** (Abbruch, mind-update gescheitert): `OPEN` bleibt, der Schlussbericht sagt **ausdruecklich**, dass die Schuld offen bleibt und der Stop-Hook
weiter nachhakt. Stilles Liegenlassen ist genau der Fehler, an dem v5.2.0 scheiterte.

### ⛔ Pflichtschritt `mind_check_tools_have_rules` — der Aufruf (NEU v5.146.0, Etappe 56 §3)

Bis v5.145.0 stand der Schritt im Pflichtkasten und der Startzeile, **nirgends als Aufruf** (Nora `FEHLT: mind-rules/cleaner_duplikate`, Palvedo 20.09.2026). Ausgabe in den Schlussbericht: ein Werkzeug ohne erreichbare Rule liegt tot im Ordner.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-all/bloecke/tools-rules.sh"
```

## Step 3: Konsolidierter Schlussbericht (PFLICHT)

```
=== /mind-all — Durchlauf abgeschlossen ===
Modus: autonom | --ask
Ausfuehrungstiefe: <$(mind_umfang_lesbar "$UMFANG")>   ⛔ PFLICHT, v5.19.0 — aus $UMFANG, nicht aus dem Kopf
                                     ⚠ v5.135.0: `10/5 bestand` heisst „10 Bestands-Quittungen ueber 5 Skills"
                                       (Udo 24.09.2026: korrekt gezaehlt, irrefuehrend beschriftet). Die
                                       MERKER-Zeichenkette bleibt unveraendert — `mind_sync_voll` liest sie.
NICHT GEFAHREN:    <was und warum>   ⛔ PFLICHT — "(nichts)" ist die Antwort bei 5/5 + 4/4
Hook-Gesundheit: OK (Herzschlag vor <N> min, Version <v>)  |  <Warnung woertlich>
Session-Quelle: gerettet <pfad> (<N> Beitraege)  |  live
Snapshot: <pfad>
  Restore (Ziele liegen NICHT alle im Projekt!):
    <pfad>/CLAUDE.md            -> <projekt>/CLAUDE.md
    <pfad>/dot-claude-CLAUDE.md -> <projekt>/.claude/CLAUDE.md
    <pfad>/rules/*.md           -> <projekt>/.claude/rules/
    <pfad>/memory/*.md          -> ~/.claude/projects/<slug>/memory/
    <pfad>/global/CLAUDE.md     -> ~/.claude/CLAUDE.md
    <pfad>/global/rules/*.md    -> ~/.claude/rules/
  Verifikation: cd <pfad> && sha256sum -c MANIFEST.sha256

| # | Skill          | Status | Angewendet | Offen/DESIGN | Fehler |
|---|----------------|--------|-----------|--------------|--------|
| 1 | mind-files     | OK     | 2         | 1 (Tool-Bundle) | — |
| 2 | mind-claudemd  | OK     | 5         | 0            | — |
| 3 | mind-memory    | OK     | 1         | 0            | — |
| 4 | mind-rules     | OK     | 0         | 0            | — |
| 5 | mind-update    | OK     | 7         | 2 (DESIGN)   | — |

Angewendet gesamt: <N> Aenderungen in <M> Dateien
  <datei:zeile>  <vorher> -> <nachher>
  ... (jede Aenderung einzeln; geloeschte Zeilen WOERTLICH als "Entfernt: <zeile>")

NICHT angewendet (bewusst):
  [DESIGN]  <datei:zeile> — Regel "<marker>" sagt: nicht anfassen
  [OFFEN]   <was> — <grund> (z.B. Overwrite-Guard, Tool-Bundle-Angebot, >5 DEAD-Pfade)

Scope-Dedup: <k> Agent-Dispatches gespart (bereits abgedeckte Scopes)
```

```
⏭ FORTSETZUNG — hier war die Arbeit unterbrochen:
   <Auftragstext aus RESUME.md — woertlich, nicht zusammengefasst>
   -> Jetzt wieder aufnehmen. Dieser Sync war ein EINSCHUB, kein Abschluss.
```
*(ohne Auftrags-Merker: `⏭ Fortsetzung: kein unterbrochener Auftrag protokolliert.`)*

Dazu gehoeren zwei Pflichtzeilen (v5.2.1):
```
Verbesserungsliste: <projekt>/listeverbesserungen.md — <N> Probleme, <M> Vorschlaege angehaengt
Sync-Schuld: beglichen (OPEN entfernt)  |  BLEIBT OFFEN — <grund>, Stop-Hook hakt weiter nach
```

Umbenannt wird nach erfolgreichem Lauf `<ts>_RESUME.md` → `<ts>_RESUME.done.md` (Step 2.96).
Die Rettungsdatei `*_chat.md` **bleibt** liegen.

**Der Bericht ist die einzige Stelle, an der du siehst was passiert ist** — deshalb luegt er
nicht: jede Aenderung einzeln, jede Auslassung mit Grund, Snapshot-Pfad immer dabei.

### ⛔ `Ausfuehrungstiefe` und `NICHT GEFAHREN` sind PFLICHT (NEU v5.19.0)

**Ein kurzer Bericht heisst „nichts zu tun" oder „abgekuerzt"**; bis v5.18.0 nicht unterscheidbar.
24.08.2026 *„mind all war ziemlich schnell"*: **0 von 4 Agents gelaufen**, im Bericht ohne Zeile dafuer.

```
Ausfuehrungstiefe: 5/5 skills 0/4 agents
NICHT GEFAHREN:    knowledge-sync (Kontext 914k) -> claude-md, memory, rules, custom-context
                   Diese Bereiche gelten als UNGEPRUEFT, nicht als unauffaellig.
```

- Beide Zeilen kommen aus `$UMFANG` und `$UNGEPRUEFT` (Step 2.96a) — **aus der Spur, nicht
  aus der Erinnerung.**
- `NICHT GEFAHREN: (nichts)` ist die zulaessige Antwort bei einem vollstaendigen Lauf.
  **Ein leerer Wert ist es nicht** — dieselbe Regel wie bei `listeverbesserungen.md`.
- Ein Lauf, der in 2.96a-R Reparatur-Paesse brauchte (seit v5.113.0 endet keiner mehr als
  Teilsync), gehoert zusaetzlich als Befund der Klasse **`lauf-unvollstaendig`** in die
  Befundzeilen von Step 2.95 — mit der Pass-Zahl und dem, was ungeprueft war. Nicht als `agent-gestorben` (dort lieferte ein **gestarteter** Agent nichts, hier lief keiner): 24.08.2026 wurde derselbe Vorfall in zwei Projekten **verschieden** einsortiert, zwei Namen verdecken das Muster.

## Hard Constraints

- **EIN `mind_snapshot` vor dem ersten Skill; Fehlschlag = kein Skill startet.**
- **Strikt sequenziell** — nie zwei Skills gleichzeitig (Anti-Burst).
- **Reihenfolge ist fest:** files → claudemd → memory → rules → update.
- **DESIGN-Befunde werden nie automatisch angewendet** (in keinem der 5).
- **ALLE geretteten Chats UND das Live-Transkript (v5.4.1, zuvor v5.2.2):** Liegen mehrere
  Rettungen vor, sind sie **alle** Session-Quelle — aelteste zuerst —, und der Bericht MUSS
  jede einzeln ausweisen. Nur die juengste zu nehmen ist ein **Befund**, kein gueltiger Lauf. Die Rettung deckt
  bis zur Kompaktierung, das Live-Transkript die Zeit danach (die Arbeit, wegen der der Stop-Hook den Lauf erzwingt). **`gerettet` allein ist ab v5.2.2 ein Befund.**
- **Overwrite-Guards und Tool-Bundle-Angebote aus mind-files bleiben aktiv** — Autonomie
  erzeugt keine Ausnahme fuer fremden Bestand.
- **>5 DEAD-Pfade** in mind-update bleiben gesperrt (Massenloesch-Sicherung).
- **Ein gescheiterter Skill stoppt die Kette nicht** — Fehler in den Schlussbericht. Ein
  `STOP`/`ABBRUCH`/`exit 1` **innerhalb** eines Einzel-Skills beendet NUR diesen Skill
  (z.B. mind-memory ohne MEMORY.md), nicht den Durchlauf.
- **Step 2.9 (Kettenmarke abraeumen) laeuft IMMER** — auch nach Fehlern/Abbruch.
- ⛔ **KONTEXT-FLUT-SPERRE (v5.2.1):** `*_chat.md` wird **nie** im Hauptkontext gelesen — kein
  `Read`, kein `cat`. Nur Pfad-Uebergabe an Subagenten und zaehlende Aufrufe (`grep -c`, `wc`).
  Ein `Read` darauf im Hauptfluss ist **Abbruchgrund** (voller Kontext loest sofort die naechste Kompaktierung und den naechsten Zwangslauf aus).
- **`listeverbesserungen.md` ist Pflicht (v5.2.1)** — jeder Lauf haengt an. „(keine)" ist
  erlaubt, ein leerer Abschnitt nicht. Ein gestorbener Agent ist ein **Problem**, kein
  „unauffaellig".
- **Die Schuld wird nur bei tatsaechlich gelaufenem Sync entfernt (v5.2.1).** Bleibt sie offen,
  MUSS der Bericht das sagen — stillschweigendes Liegenlassen ist genau der Fehler, an dem
  v5.2.0 gescheitert ist.
- ⛔ **DER SYNC GEHT IMMER VOR (NEU v5.4.1, Nutzer-Entscheidung 19.08.2026).**
  Liegt eine offene Schuld vor, laeuft `/mind-all` **zuerst** — vor jedem Auftrag, ohne
  Ausnahme. *„Ich mache erst den Auftrag fertig"* ist **kein zulaessiger Grund mehr**.
  Ersetzt die v5.2.0-Regel („laufender Auftrag hat Vorrang"), die keinen Zeitpunkt nannte; bis v5.4.0 zeigte der
  Merker dann woanders hin. Der Auftrag geht **nicht** verloren: er steht woertlich im
  `<ts>_RESUME.md` und kommt unten mit der `⏭ FORTSETZUNG`-Zeile zurueck.
- **`/mind-all` ist NIE ein Auftragsende (v5.2.0).** Nennt der Auftrags-Merker einen unterbrochenen
  Auftrag, MUSS der Schlussbericht mit der `⏭ FORTSETZUNG`-Zeile enden und die Arbeit danach
  wieder aufgenommen werden. Ein Context-Sync ist ein Einschub — er erledigt nichts, was der
  Nutzer beauftragt hat.
- **Kein `git commit`/`git push`** — `/mind-all` aendert Context-Dateien, nicht die Historie.
