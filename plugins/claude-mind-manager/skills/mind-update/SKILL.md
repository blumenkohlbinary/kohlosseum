---
name: mind-update
description: |
  [Mind Manager] Context-Sweep mit ZWEI Pflicht-Teilen: (1) deterministische
  Drift-Erkennung (Versionen, Pfade, Counts, Syntax, Commit-Coverage) inline,
  (2) Knowledge-Sync — dispatcht IMMER die 4 Per-Bereich-Agents (claude-md/memory/
  rules/custom-context), aber SEQUENZIELL bzw. max 2 gleichzeitig, NIE >=3 im selben
  Tool-Call (Anthropic Server-Rate-Limit). Alle 4 gleichen Session-Inhalte mit den
  Context-Files ab und klassifizieren in 5 Klassen (UPDATE/ENRICH/ADD/NEW_FILE/INFO).
  v5.0.0: Befunde werden AUTONOM angewendet (ausser DESIGN); '--ask' fragt wie
  frueher.

  Der Knowledge-Sync ist KEINE optionale Beschleunigungs-Stufe — er ist Teil der
  Identitaet dieses Skills. Nur `--quick` schaltet ihn explizit ab.

  Use when the user says "update context", "refresh context", "mind update",
  "quick check", "context status", "sync context",
  or "/mind-update [--quick]".
argument-hint: "[--quick]"
context: inherit
allowed-tools: Read Glob Grep Edit Bash Agent
---

# Context-Sweep + Knowledge-Sync

## ⛔ PFLICHTSCHRITTE — dieser Skill fuehrt aus, was hier steht (NEU v5.25.0)

```
PFLICHTSCHRITTE
bestandszahlen_kandidaten
claudemd_pipeline
cleaner_stichprobe
cleaner_tor
mind_agent_bilanz
mind_kontext_bilanz
mind_snapshot
session_sampler
verdichten
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
#    ⚠ Wird beim Release nachgezogen; das Zaehl-Gate prueft alle elf.
#    ⛔ v5.125.0: DIESELBE Bash wie mind_schritt_start — sonst rc 1, keine Startzeile (Etappe 37 §3).
MIND_SKILL_VERSION="5.161.0"
mind_schritt_start "$PROJ" mind-update bestandszahlen_kandidaten claudemd_pipeline cleaner_stichprobe cleaner_tor mind_agent_bilanz mind_kontext_bilanz mind_snapshot session_sampler verdichten
```

**Nach JEDEM Schritt** — auch nach einem, der entfaellt:

```bash
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
mind_schritt <name> gelaufen              "$(wc -c < "$AUSGABE")" "$PROJ"
mind_schritt <name> "gelaufen:5/11"       "$BYTES" "$PROJ"   # TEILABDECKUNG
mind_schritt <name> "uebersprungen:<grund>" 0      "$PROJ"
mind_schritt <name> "fehler:<grund>"      -1       "$PROJ"
# ⛔ v5.97.0 — VERDICHTEN und die fuenf Context-Skills NUR mit ARTEFAKT: ohne --datei
#    wird `gelaufen` zu `uebersprungen:kein-artefakt`, und die Bilanz zaehlt FORMAL.
#    Drei Laeufe (10.–12.09.2026) trugen dieselben getippten Bytes; Zahlen tippt die Hand.
mind_schritt verdichten gelaufen --datei "$PROJ/.claude-mind/verdichten-<skill>.txt" "$PROJ"  # die 3 Zeilen von mind_verdichtung_pruefen
  # ⛔ v5.135.0: die Datei wird GEPRUEFT, nicht nur genannt — Pfad und Byte-Zahl stehen in der
  #    Quittung, und ein schneller Block gilt damit nicht mehr als nachgetippt
  #    (`references/bestands-pass.md`: „Ein pruefbares Artefakt schlaegt die Zeitregel").
mind_schritt verdichten "uebersprungen:kein-kandidat" 0 "$PROJ"   # schweigen = FEHLT
```

⛔ **`uebersprungen` ist ein gueltiger Status und braucht einen GRUND.** Ein Schritt,
der legitim entfaellt (kein Git, kein Quellbaum), ist kein Fehler — aber
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

⭐ **`gelaufen:5/11` ist die TEILABDECKUNG.** Am 30.08.2026 deckte `cleaner_leitplanke.py` 5 von 11 Dateien ab und wurde als **Bereichspruefung** berichtet. `5/11` ist eine gueltige Antwort; als `11/11` berichtet ist sie es nicht.
⚠ **`X/Y` mit X=Y (`1/1`) zaehlt seit v5.113.0 als voll** — vollstaendig heisst trotzdem
`gelaufen`, nicht `1/1` (Noras Lauf 11, 16.09.2026). ⛔ **Nachquittieren geht nur im SELBEN
Block:** die Bilanz nimmt den letzten Eintrag je Block×Name; ein Nachtrag in einem spaeteren
Block heilt nichts — den Block erneut fahren (mind-all 2.96a-R).
⛔ **Eine geloeschte oder leere Schritt-Quittung wird nicht nachgetippt — der Block wird neu
gefahren** (v5.116.0, Doros Creator-Lauf 16.09.2026: 39 Schritte in 5 s nachgetippt, Bilanz 39/39).
Die Bilanz erkennt getippte Bloecke (Starts < `MIND_SCHRITT_MIN_S` = 60 s auseinander, >= 5 Schritte
in 10 s) als FORMAL, der Lauf ist teil.

⛔ **Die Bytezahl ist Pflicht, wo ein Schritt etwas ausgeben MUSS.** Am selben Tag lief `cleaner_belege.py`, seine Ausgabe wurde weggegreppt (naive Quittung: „gelaufen"). `0` meldet die Bilanz als **LEER**; `-1` heisst „nicht gemessen" und zaehlt nicht.

**Im Bericht, als erste Zeile des Self-Checks:**

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-update/bloecke/pflicht-bilanz.sh"
```

⛔ **Fehlt diese Zeile oder nennt sie `FEHLT`, ist der Bericht unvollstaendig** und
darf zurueckgewiesen werden. Rueckgabe **2 heisst: gar keine Quittung** — der Lauf
hat nie begonnen zu quittieren, und das ist NICHT „nichts zu melden".

⚠ **Was die Quittung nicht kann:** sie erzwingt keinen Schritt, sie macht sein Fehlen
sichtbar — wie `decision:block` und die Agent-Quittung. Und sie misst nicht die GUETE:
ein Werkzeug, das laeuft und Unsinn liefert, quittiert als `gelaufen`.

Deterministische Drift-Checks inline -> Knowledge-Sync via Per-Bereich-Agents
-> sichere Fixes auto-anwenden -> Report.

**Identitaet (directive):** Dieser Skill macht BEIDES — Drift-Checks UND Knowledge-Sync.
Der Knowledge-Sync (Step 3.5) wird IMMER ausgefuehrt (ausser `--quick`). Es gibt
KEINEN Inline-Ersatz dafuer: der semantische Abgleich Session<->Context laeuft NUR
ueber die dispatchten Agents. "Ich kenne den Stand schon" ist kein gueltiger Grund
ihn zu ueberspringen — siehe Step 3c Commit-Coverage, die Gaps objektiv belegt.

## Step 0: Modus + Snapshot (PFLICHT, NEU v5.0.0)

**Autonom ist der Standard.** Drift-Fixes UND Knowledge-Sync-Befunde werden selbstaendig
angewendet (frueher: alles ASK-Default).

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-update/bloecke/step0-snapshot.sh"
```

| Modus | Aufruf | Verhalten |
|---|---|---|
| **autonom (Default)** | `/mind-update` | AUTO/DEAD/UPDATE/ENRICH/ADD/NEW_FILE werden angewendet |
| **interaktiv** | `/mind-update --ask` | Report → Freigabe (Verhalten vor v5.0.0) |
| **nur Drift** | `/mind-update --quick` | ohne Knowledge-Sync (unveraendert) |

**Nie automatisch:** DESIGN-Befunde · **>5 DEAD-Pfade** (Massenloesch-Sicherung, Step 3b).
**Bei Snapshot-Fehlschlag wird NICHT editiert.**

## Step 1: Alle Context-Dateien lesen (project + global + topic-files)

Read all context files directly via Read/Bash (dies ist der Datei-Lese-Schritt;
der Knowledge-Sync via Agents folgt in Step 3.5). **6 Targets — alle PFLICHT,
keine Auslassung. Wenn ein Target fehlt: explizit "(none)" loggen, NICHT silent
skippen.**

1. **CLAUDE.md** (project): `./CLAUDE.md` or `./.claude/CLAUDE.md`
2. **CLAUDE.md** (global): `~/.claude/CLAUDE.md`
3. **MEMORY.md** (project): Compute hash, read `$MEMORY_DIR/MEMORY.md`
4. **MEMORY-Topic-Files** (NEU v3.2.1): Glob `$MEMORY_DIR/*.md` MINUS `MEMORY.md`
   selbst (z.B. `lessons.md`, `topic-bugfixes.md` — Topic-Files sind Markdown
   **MIT** YAML-Frontmatter (`name`, `description`, `metadata.type`); das ist das
   aktuelle Harness-Format. **v5.0.0-Korrektur:** frueher stand hier "ohne
   Frontmatter", woraus Step 3e eine Falschwarnung fuer JEDE korrekt formatierte
   Datei ableitete)
5. **Rules** (project): Glob `.claude/rules/*.md`
6. **Rules** (global): Glob `~/.claude/rules/*.md`
7. **Roster-Unterordner** (v5.106.0, nur im Rollen-Aufbau): `mind_unterordner_kontext "$PROJ"`
   — deren `CLAUDE.md` gehoeren zu Target 1, deren `.claude/rules/*.md` zu Target 5; im
   Bericht je Datei mit Ordner

⛔ **v5.106.0 — im ROLLEN-AUFBAU gehoeren die Unterordner zum Bestand.** Ist `$PROJ` eine
Rollen-Wurzel (`rollen.md`), zaehlen die `CLAUDE.md` und `.claude/rules/*.md` der Ordner aus
der Spalte `Ordner` des Rosters mit (fehlt die Spalte: jeder direkte Unterordner mit
`CLAUDE.md`) — das ist der Dauerkontext der Arbeiter-Sitzungen. Gemessen 14.09.2026 (Creator,
Doro): sieben Unterordner, fuenf CLAUDE.md und 17 Rules, in keinem Bericht genannt.
```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-update/bloecke/step1-dateien.sh"
```
Der Bericht nennt je Datei den Ordner (`<Ordner>/CLAUDE.md`, `<Ordner>/.claude/rules/<name>`).
`mind_snapshot` sichert sie seit v5.106.0 von selbst mit.

```bash
# laeuft in step1-dateien.sh mit — KEIN eigener Aufruf
```

Record line counts for each file immediately. Output-Pattern (siehe Step 6):
- "(none)" wenn ein Target leer ist
- Datei-Liste + Zeilen pro Topic-File / Rule-File explizit zeigen

## Step 1.5: Custom-Context-Discovery (NEU v3.2.2, 2-Phasen)

Vor Step 3: finde projekt-weite Custom-Context-Files (alles im Projekt-Ordner
das fachlichen/technischen Code-Context enthaelt, nicht nur Auto-Loading-Rules).

**User-Direktive:** Custom Context kann ueberall im Projekt liegen. Discovery-Logik:
1. **Referenz-basiert** (deterministisch): Files die in CLAUDE.md/Rules per
   Backtick erwaehnt werden zaehlen automatisch
2. **Heuristik-basiert** (Fallback): score >= 2 ueber Code-Pattern-Indikatoren

### SKIP_SET: Files die in Step 1 bereits behandelt sind

```bash
# laeuft in step1-dateien.sh mit — KEIN eigener Aufruf
```

### Phase 1: Referenz-Discovery (deterministisch)

```bash
# laeuft in step1-dateien.sh mit — KEIN eigener Aufruf
```

### Phase 2: Heuristik-Discovery (Fallback)

```bash
# laeuft in step1-dateien.sh mit — KEIN eigener Aufruf
```

**Edge-Cases-Handling:**
- **EC1 Performance:** bei >100 .md Files → score-Schwelle erhoeht auf 3, User-Hinweis fuer `.mindcontext`
- **EC2 False-Positives:** Whitelist nur `.md/.txt/.rst` als Custom Context (kein `.json/.yaml/.py`)
- **EC3 .mindcontext Override:** User kann projekt-spezifisch konfigurieren

## Step 2: Referenzen laden

Read these reference files for budget thresholds:
- [references/budget-thresholds.md](../../references/budget-thresholds.md) -- SFEIR compliance data, line limits
- [references/token-budget-formulas.md](../../references/token-budget-formulas.md) -- Token calculation formulas

## Step 2.5: Args parsen (NEU v3.3.0)

```bash
ARGS='$ARGUMENTS'   # v5.159.0: Claude Code ersetzt beim Laden nur das blanke Argument-Token, nie die Form mit Klammern
QUICK_MODE="no"
echo "$ARGS" | grep -qE '(^|[[:space:]])--quick([[:space:]]|$)' && QUICK_MODE="yes"

if [ "$QUICK_MODE" = "yes" ]; then
  echo "INFO: --quick Mode -> nur Drift-Checks (Step 3), kein Knowledge-Sync (Step 3.5)"
fi
```

## Step 3: Quick Checks

Run all checks inline (no agents):

### 3a: Version Match (ueber ALLE Custom Context — NEU v3.2.2)

**Source of Truth bestimmen** (Reihenfolge):
1. `dist/stable/_build_info.py` (wenn Build-System), sonst
2. `pyproject.toml` / `package.json` / `plugin.json` Version

**Grep alle Custom-Context-Files** (aus Step 1 + Step 1.5):
- CLAUDE.md (project + global)
- `.claude/rules/*.md` (project) + `~/.claude/rules/*.md` (global)
- MEMORY.md + Topic-Files
- Custom-Context-Files aus Step 1.5 Discovery

**Pattern (Regex, case-insensitive):**
```python
VERSION_PATTERNS = [
    r'v\d+\.\d+\.\d+(?:-\w+(?:\.\d+)?)?',  # v1.0.5, v1.0.6-dev.13
    r'Version:\s*v?\d+\.\d+',
    r'Aktuelle\s+Version:\s*v?\d+',
    r'Stable\s+v\d+\.\d+',
]
```

Pro Match: `file:line + extrahierte Version + Source-Truth → Mismatch?`
Mismatch → Finding mit Klasse AUTO/ASK/DESIGN (siehe Step 4 v3.2.1).

**Sonder-Behandlung "abgeschlossen markierte" Files (User-Direktive):**
- Wenn Custom-Context-File alle Bugs/Tasks als "geschlossen"/"erledigt" markiert
  UND mtime > 30 Tage alt → Klasse **INFO** mit Vorschlag "koennte archiviert
  werden". **NIEMALS Auto-Action.**

### 3a.1: Stale Test-Counts (NEU v3.2.2, conditional)

**Conditional (M2-Fix):** Test-Count-Check nur wenn Python+pytest+tests/ existieren.
Skill ist projekt-agnostisch — bei Nicht-Python-Projekten skippen.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-update/bloecke/step3a1-testcounts.sh"
```

### 3b: Dead Paths (kontextuell, KEINE False-Positives)

**Pfad-Pattern STRIKT** — nur backtick-wrapped Strings die mindestens einen
Slash oder Backslash enthalten. Bare-Filenames wie `model.py`, `ui.py` werden
NICHT als Pfade behandelt (sind referentielle Code-Erwaehnungen).

**Extraktion — ⛔ NICHT hier nachbauen, das Werkzeug fahren:**

```bash
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
python "$CLAUDE_PLUGIN_ROOT/references/claudemd_pipeline.py" <datei.md> --projekt "$PROJ"
```

⛔ **Meistnachgebaute Stelle des Plugins:** Klasse `instrument-nachgebaut`, **7 Vorkommen** im Debug-Ordner; Nachbauten **~250 · 11 · 9 · 7 Fehltreffer**, *kein einziger besser als das Original*. `claudemd_pipeline.py` traegt alle Sonderfaelle (Slash-Commands, Formeln, Escape-Sequenzen, Interpreter-Aufrufe, Zitate mit Zeilennummer) und hat einen Selbsttest (zwei Sekunden).

<details><summary>Das Muster — nur zum Nachlesen, nicht zum Abtippen</summary>

```python
import re
# Backtick-Spans mit mindestens einem / oder \ — und [^`\n], NICHT [^`]:
pattern = r'`([^`\n]*[/\\][^`\n]+)`'
```

⛔ **Das `\n` in beiden Zeichenklassen ist der Punkt.** Ohne es greift das Muster ueber
Zeilengrenzen und erfindet Pfade aus zwei benachbarten Saetzen. Gemessen 26.08.2026 in
`Pc Forschung`: **2 der 58** gemeldeten toten Pfade entstanden genau so.

⚠ Die Prosa-Fassung hier war falsch, `claudemd_pipeline.py:273,303` richtig — **ein Modell schreibt ab, was im Skill steht.** Dritter Fall an einem Tag: Vorschrift als Prosa im Skill statt als Code im Werkzeug.

</details>

✅ **Inkludieren** (echte Pfade mit Separator):
- `src/zustellplan/model.py`
- `dist/stable/`
- `.claude/rules/build-process.md`
- `C:/CD/KOHLEKTIV/...`

❌ **Ausschließen** (Bare-Filenames als Code-Referenz):
- `model.py`, `ui.py`, `weather.py` — nur Filename, kein Pfad
- `__init__.py` — Convention-Name ohne Pfad
- `pyproject.toml` — Top-Level-Datei ohne Pfad-Prefix (separate Version-Check
  in Step 3a behandelt das ohnehin)

**VOR-FILTER (PFLICHT, NEU v5.0.0) — vor jedem `test -e` anwenden.**

Ein `test -e` kann nur beantworten "existiert als Datei" — NICHT "ist ueberhaupt ein
Dateipfad". Web-Adressen ohne Protokoll, abgekuerzte Beispiele und Platzhalter fallen
sonst als DEAD durch und werden **autonom geloescht**. Real gemessen: 5 echte Treffer,
**5 Fehltreffer** (`asus.com/…/helpdesk_qvl_memory`, `testufo.com/frameskipping`,
`/releases/44/`, `/releases/test/`, ein relativ geschriebener existierender Pfad).

```bash
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
# ⛔ NICHT NACHBAUEN — die Funktion liegt seit v5.11.0 in lib.sh und heisst
# `mind_classify_path`. Sie wird hier AUFGERUFEN, nicht wiederholt.
#
# Grund: als Bash-Quelltext an dieser Stelle wurde sie vom ausfuehrenden Modell
# nachgebaut statt benutzt. Debug-Klasse `instrument-nachgebaut`, 7 Vorkommen;
# einmal meldete der Nachbau 11 Slash-Commands als tote Pfade. Wer Prosa liest,
# baut nach. Eine Definition, ein Aufrufer.
#
# lib.sh ist in Step 1 bereits gesourct.
klasse=$(mind_classify_path "$p")

# ⛔ Existenz NUR ueber `mind_pfad_lebt` pruefen, NIE mit blossem `test -e`.
# Bash expandiert `~` in Anfuehrungszeichen NICHT: `test -e "~/.claude/rules/x.md"`
# ist immer falsch, die Datei mag mit 68 Zeilen dort liegen. Ergebnis war DEAD,
# und bei <=5 DEAD wird AUTONOM GELOESCHT. Gemessen und reproduziert 21.08.2026
# (`tests/test_lib_v511.sh`, Befund aus `APP - Palvedo`).
[ "$klasse" = "CHECK" ] && { mind_pfad_lebt "$p" || echo "DEAD: $p"; }
```

**Verifikation pro Pfad:**
- Nur `CHECK`-Strings gehen in **`mind_pfad_lebt`** (lib.sh). Die loest `~` auf und
  faellt fuer relative Pfade auf `$CLAUDE_PROJECT_DIR` zurueck — beides war vorher
  einzeln kaputt: ein real existierender, relativ geschriebener Pfad fehlte nur vom
  falschen Verzeichnis aus, und `~/...` galt **immer** als tot.
  ⛔ **Nie wieder `test -e` von Hand hinschreiben.**
- `SKIP` → gar kein Finding (keine Dateipfade).
- `UNSURE` → Finding Klasse **INFO**, wird **nie** angewendet (nur gelistet).
- `CHECK` + nicht auffindbar → Finding Klasse DEAD.

**Massenloesch-Sicherung (gilt AUCH im Autonom-Modus):**
- **≤5 DEAD-Findings:** werden angewendet. **Jede geloeschte Zeile wandert WOERTLICH in den
  Report** (`Entfernt: <zeile>`) — zusammen mit dem Snapshot aus Step 0 ist jede Loeschung
  nachlesbar und rueckholbar.
- **>5 DEAD-Findings:** **NICHT** anwenden, auch nicht autonom. Als Block listen mit
  Begruendung *"ungewoehnlich viele tote Pfade — Verdacht auf Filter-Fehler, bitte pruefen"*.
  Grund: Autonomie multipliziert einen Algorithmus-Fehler; ein einzelner Fehlgriff ist
  reparabel, ein Massenschnitt durch alle Context-Dateien nicht zumutbar.

### 3c: Commit-Coverage-Gate (deterministisch — objektiver Knowledge-Gap)

⛔ **„0 Luecken" und „nicht anwendbar" sind zwei verschiedene Ergebnisse (NEU v5.7.1).** Palvedo-Lauf 21.08.2026: Das Gate sucht `feat:`/`fix:`/`refactor:`/`perf:`, Palvedo schreibt Commits bewusst als `Lauf N: …` — es fand **nie** etwas und meldete jedes Mal „0 Luecken".

**Der Unterschied zwischen *ungeprueft* und *sauber* ist der ganze Zweck dieses Schritts.**

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-update/bloecke/step3c-commits.sh"
```

**Zweck (v3.3.2):** DETERMINISTISCHER Kern der Knowledge-Gap-Erkennung. Er entwertet die "ich kenne den Stand schon"-Ausrede: steht Commit X nachweislich in keiner Context-Datei, IST das ein Gap. Die Findings speisen Step 3.5 mit konkreten Pruef-Punkten.

- Nur wenn `.git/` existiert.
- **KEIN Git (v5.0.0, Befund 7): NICHT stillschweigend ueberspringen.** Der Self-Check MUSS dann diese Zeile enthalten:
  `[Step 3c] KEIN GIT — kein objektives Gate verfuegbar; alle Befunde beruhen allein auf
  semantischem Abgleich`. Gleiches gilt fuer Step 3c.1 (Datei-Targeting faellt aus → es
  greift der Groessen-Guard). Ohne das Gate ist die Beweislage eine andere, und der Bericht darf das nicht verschweigen.
- `git log --oneline -30` (oder seit letztem doc-beruehrenden Commit).
- Pro `feat:`/`fix:`/`refactor:`/`perf:` Commit: Scope + Subject-Stichworte gegen
  **CLAUDE.md UND MEMORY.md** greppen.

```bash
# Commit-Coverage: welche Feature-Commits sind NICHT in den Context-Dateien?
# Stichwort-Wahl (N1-Fix): zuerst dev.NN, dann der conventional-commit-SCOPE
# (feat(SCOPE):), erst zuletzt ein Subject-Token — Stopwords ausgeschlossen.
# Grep-Ziele als ARRAY, nie als Zeichenkette: ein Pfad mit Leerzeichen zerfaellt sonst in
# Stuecke — derselbe Fehler, der in v5.2.1 die Rotation lahmlegte (xargs +
# "Plugin - Entwicklung"). Die Zusatzziele kommen aus der CLAUDE.md SELBST; es wird nicht
# geraten, welche Datei "kanonisch" ist. Gemessen: 2 -> 17 Ziele im Zustellplan-Projekt.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
# v5.153.0: MEMORY_MAIN kam aus Step 1 — einem anderen Prozess. Leer war das zweite Ziel "".
MEMORY_MAIN="${MEMORY_MAIN:-$(get_memory_dir 2>/dev/null)/MEMORY.md}"
ZIELE=("CLAUDE.md" "$MEMORY_MAIN")
while IFS= read -r z; do
  [ -n "$z" ] && [ -f "$z" ] && ZIELE+=("$z")
done < <(grep -oE '`[A-Za-z0-9_./-]+\.md`' CLAUDE.md 2>/dev/null | tr -d '`' | sort -u)

# ⛔ v5.147.0 (Etappe 56 §5, CK3): OHNE CONVENTIONAL COMMITS MISST DAS GATE NICHTS — und sagt es.
#    CK3: 0 von 30 (deutsche Commits), Palvedo ebenso; dann kam gar keine Zeile, und das las
#    sich wie „keine Luecken“. Jetzt steht NICHT ANWENDBAR da, keine Zahl.
_KC=$(git log --oneline -30 2>/dev/null | wc -l | tr -d ' ')
_KK=$(git log --oneline -30 2>/dev/null | grep -ciE '^[0-9a-f]+ (feat|fix|refactor|perf|docs)(\(|:)')
[ "${_KK:-0}" -eq 0 ] && echo "NICHT ANWENDBAR: 0 von ${_KC:-0} Commits im Conventional-Format (feat:/fix:/...) — Commit-Coverage misst hier NICHTS (keine Zahl, kein 'keine Luecken')"
git log --oneline -30 | grep -iE '^[0-9a-f]+ (feat|fix|refactor|perf|docs)(\(|:)' | while read -r line; do
  hash=$(echo "$line" | cut -d' ' -f1)
  subj=$(echo "$line" | cut -d' ' -f2-)
  # 1) VERSION (fuehrendes v abgestreift)  2) dev.NN  3) Scope, Punkt erlaubt: docs(claude.md)
  key=$(echo "$subj" | grep -oiE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -1 | sed 's/^[vV]//')
  [ -z "$key" ] && key=$(echo "$subj" | grep -oiE 'dev\.[0-9]+' | head -1)
  [ -z "$key" ] && key=$(echo "$subj" | sed -nE 's/^[a-z]+\(([a-z0-9_.-]{3,})\).*/\1/p' | head -1)
  # KEIN -F: grep -iF auf UTF-8 (deutsche Umlaute in MEMORY.md) wirft auf Git-Bash/MSYS
  # "Aborted (core dumped)" -> non-zero -> falsche GAPs (real 2026-07-15: 24 Fake-GAPs aus
  # dem Crash). grep -qi (ohne -F) ist verifiziert crash-frei; Keys sind regex-safe. v4.1.0-Fix.
  if [ -z "$key" ]; then
    # Sichtbar machen statt verschweigen: ohne belastbares Stichwort ist der Commit
    # UNGEPRUEFT, nicht unauffaellig. Genau diese Stille war der Defekt bis v5.5.1.
    echo "KEIN-STICHWORT: $hash '$subj' — ungeprueft, kein belastbares Stichwort"
  # ⚠ v5.147.0: Umlaut-Schreibweisen (CK3: Fehl-GAPs) — beide Formen gelten als Treffer.
  elif ! grep -qi "$key" "${ZIELE[@]}" 2>/dev/null \
       && ! grep -qi "$(printf '%s' "$key" | sed 's/ä/ae/g;s/ö/oe/g;s/ü/ue/g;s/ß/ss/g')" "${ZIELE[@]}" 2>/dev/null \
       && ! grep -qi "$(printf '%s' "$key" | sed 's/ae/ä/g;s/oe/ö/g;s/ue/ü/g')" "${ZIELE[@]}" 2>/dev/null; then
    echo "GAP: $hash '$subj' — Stichwort '$key' fehlt in ${#ZIELE[@]} Context-Dateien"
  fi
done
```

**N1-Hinweis (v5.5.2):** Der enge Weg bis v5.5.1 konnte einen Gap *uebersehen*, nie *erfinden* — um den Preis, in einem Doku-Workspace **gar nichts** zu sehen: `docs:` fiel durch den Filter, **0 von 17** Commits blieben ungeprueft, gemeldet wurde trotzdem „keine Lücken". Jetzt zaehlt ein Stichwort nur, wenn es **belastbar** ist (Version · `dev.NN` · Scope); sonst wird der Commit als `KEIN-STICHWORT` **ausgewiesen**. Der Rückfall auf ein beliebiges Subject-Token ist entfallen (deutsche Subjects lieferten Verben wie „vereinheitlichen", „protokollieren", garantierte Fehlalarme).

⛔ **`KEIN-STICHWORT` ist ein Ergebnis, kein Rauschen.** Es heißt „dieser Commit wurde nicht
geprüft" — nicht „dieser Commit ist in Ordnung". Wer die Zeilen wegblendet, stellt genau die
Stille wieder her, die der Defekt war.

**Belege (2026-08-20, echte Git-Historie):** altes Gate **0** betrachtete Commits und **0** GAPs, obwohl `v5.5.1` in *keiner* Context-Datei stand; das neue findet genau diesen Commit. **Negativkontrolle:** am Stand nach dem Nachtrag meldet es ihn nicht mehr — die Messung schlägt in beide Richtungen aus. Stichwort-Erkennung gegen **14 synthetische Subjects inkl. 3 Gegenproben** (`95 -> 79`, `12.30 Uhr`, `3.2x` dürfen NICHT als Version durchgehen). **Flut-Kontrolle:** Zustellplan 23 → 28 betrachtete Commits bei weiterhin **0** GAPs, Grep-Ziele 2 → 17.

⚠ **Weiterhin blind:** Repos ohne Conventional-Commit-Präfixe. In `APP - Palvedo` trifft der Filter **0 von 30** Commits, vorher wie nachher — keine Regression, aber keine Lösung; es steht hier, damit niemand das Gate für vollständig hält.

- Jeder `GAP:` = **objektives Knowledge-Gap-Finding** (Commit-Hash + Subject + fehlendes Stichwort).
- Jedes `KEIN-STICHWORT:` = **ungeprueft** (v5.5.2). Zaehlt NICHT als Gap, darf aber auch nicht
  als "sauber" gelten — beide Zahlen gehoeren getrennt in den Self-Check-Block.
- Diese Liste geht als konkreter Input an Step 3.5 ("verifiziere/ergaenze diese unreflektierten Commits").
- **WICHTIG:** Wenn die Commit-Coverage Gaps zeigt, MUSS Step 3.5 laufen — ein nicht-leeres Gap-Set widerlegt jede "alles synchron / ich kenne den Stand"-Annahme.

### 3c.1: Datei-Targeting — welche Rules hat die Session berührt? (v4.1.0 — Skalierung)

**Zweck:** Bei vielen/großen Rules (Zustellplan: ~118k Tokens in 11 Files, 2 davon >1200 Zeilen) läuft ein einzelner semantischer Agent über (0 Output). Der semantische Pass (Step 3.5) prüft deshalb nur **session-berührte** Rules, deterministisch bestimmt aus den Commit-Scopes (die auf Datei-Inhalte mappen).

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-update/bloecke/step3c1-targeting.sh"
```

- **Erring broad = sicher:** ein zu breiter Treffer prüft nur ein paar Files extra; ein *verpasster* wäre schlimm — die `{3,}`/`{4,}`-Guards halten Keys ≥3-4 Zeichen (kein 2-Zeichen-Scope-Explosion).
- **Targeting ≠ Skip:** Das DETERMINISTISCHE Rules-Sicherungsnetz ist **Step 3e (Syntax) + 3e.2 (Content-Drift)** — über ALLE Project+Global-Rules, PFLICHT, unabhängig vom Targeting (3c prüft CLAUDE.md+MEMORY, NICHT die Rules). Das Targeting fokussiert NUR den *semantischen* Re-Read.
- **Ehrlicher Rest:** „untouched" heißt „nicht per Commit berührt", NICHT „da ist garantiert nichts zu ergänzen". Eine ADD-würdige Erkenntnis in einer *unberührten* großen Rule wird über 3e.2 (Versions-/Muster-Drift) ODER die Report-Offenlegung (`TARGET_MODE`/deterministisch-only + `/mind-rules`-Pointer) sichtbar, nicht geschluckt.

### 3d: MEMORY.md Budget
- Count lines in MEMORY.md
- >200 lines = CRITICAL (truncation imminent)
- >150 lines = WARNING (approaching limit)
- OK otherwise

### 3e: Rules Syntax Check (project + global, beide PFLICHT)

- Grep BEIDE rule sets fuer `^paths:` (known bug — silently ignored by Claude Code):
  - **Project rules** (`.claude/rules/*.md`)
  - **Global rules** (`~/.claude/rules/*.md`) — NEU v3.2.1: explizit pruefen
- User-level rules (global) mit `paths:` = ERROR (never works in `~/.claude/rules/`)
- Project rules mit `paths:` = WARNING (auto-fixable via mind-rules migrate)
- **MEMORY-Topic-Files NICHT auf `paths:`/`globs:` pruefen** — sind Markdown ohne
  YAML-Frontmatter, sollen das auch nicht haben. Wenn doch eines welche hat:
  **Frontmatter ist der SOLLZUSTAND (v5.0.0-Korrektur).** Pruefen statt warnen:
  `name` + `description` + `metadata.type` vorhanden UND
  `type` aus {user, feedback, project, reference}. **WARNING nur bei Verstoss**
  (fehlendes Feld / unbekannter type) — NICHT dafuer, dass Frontmatter da ist.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-update/bloecke/step3e-syntax.sh"
```

### 3e.2: Rules-Inhalts-Drift (NEU v3.3.1, zusaetzlich zu 3e Syntax) — PFLICHT

**WICHTIG (Real-World-Bug aus Session 2026-05-31):** Step 3e prueft nur `paths:` Syntax,
aber NICHT den INHALT der Rule-Files. Drift (veraltete Versionen, Test-Counts) bleibt
unbemerkt. **Skip nur bei `QUICK_MODE=yes`.**

**Restriktive Patterns** (vermeiden Plauder-False-Positives wie "we discussed dev.13"):

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-update/bloecke/step3e2-drift.sh"
```

**False-Positive-Mitigation:**
- Versions-Pattern valid nur wenn Zeile mit Kontext-Keyword (`Stable`/`Unstable`/`Tag`/`Commit`/`Last sync`) ODER mit `-`/`*`/`|`/backtick beginnt (Tabelle/Bullet/Code)
- Test-Counts valid nur wenn `gruen`/`passed`/`collected`/`pytest`/`coverage` in derselben Zeile
- Bei >10 Hits in EINEM Rule-File: Warnung "vermutlich noch False-Positives" + User-Frage statt Auto-Action

**Jeder Hit → Finding mit Klasse aus Step 4:**
- AUTO bei eindeutiger Drift (z.B. `434 Tests gruen` und Source-of-Truth ist 464)
- ASK bei Build/Release-relevanten Files (z.B. `build-process.md` `Last sync` updaten?)
- INFO bei Genesis-Refs ("Pool-Reform seit v1.0.6-dev.6" — Doku der Historie, keine Drift)

**Beispiel-Hits (Real-World Zustellplan):**
- `build-process.md:17` `Last sync: v1.0.3 / 2026-05-07` (Stable jetzt v1.0.5) → ASK
- `git-conventional-commits.md:94` `283 Tests gruen` (jetzt 464) → AUTO
- `tab1-berechnung.md:44` `Pool-Reform seit v1.0.6-dev.6` → INFO (Genesis)

### 3f: Total Context Budget
- Sum all context file lines: CLAUDE.md (all scopes) + MEMORY.md + all rules
- >500 lines = WARNING: "High context overhead"
- >300 lines = INFO: "Moderate context load"
- <300 lines = OK

## Step 3.5: Per-Bereich Knowledge-Sync (4 Agents, sequenziell/gestaffelt)

**Directive:** Dieser Schritt laeuft IMMER (ausser `QUICK_MODE=yes`). Es gibt keinen
Inline-Ersatz — der semantische Abgleich Session<->Context laeuft NUR ueber die
Agents. Wenn Step 3c Commit-Coverage-Gaps gefunden hat, ist "alles synchron / ich
kenne den Stand" objektiv widerlegt → dispatchen ist Pflicht, nicht Ermessen.

**WICHTIG — Methode ≠ Mandat (Anti-Burst, v4.0.1):** Alle 4 Bereiche sind PFLICHT und werden IMMER abgedeckt, aber **SEQUENZIELL** bzw. **maximal 2 gleichzeitig** — **NIE 3-4 im selben Tool-Call**. Ein Burst aus ≥3 gleichzeitigen Agents trippt reproduzierbar Anthropics **server-seitiges Rate-Limit** ("Server is temporarily limiting requests — not your usage limit", 429/529) → ALLE Agents scheitern, 0 Ergebnisse (3× gemessen: 2026-06-15/29 + 2026-07-04, schon 3 gleichzeitig reichten), **auch unter Ultracode**. **`sequenziell` heißt NICHT `optional`.** Diese Staffelung NIE "aus Performance-Gründen" zu einem Parallel-Burst zurückdrehen.

Dispatch die 4 `context-analyzer` Agents **nacheinander** (oder in 2 Wellen à 2 —
Welle 1: claude-md + memory, Welle 2: rules + custom-context; jede Welle ihr eigener
Tool-Call). Ergebnisse aller 4 einsammeln, dann konsolidieren.

### ⭐ EIN AUFTRAG JE AGENT — der Zuschnitt traegt, nicht die Datenmenge (NEU v5.21.2)

**Am 26.08.2026 in zwei Projekten gemessen. Keines konnte es allein belegen:**

| | Aufgabe **gross** | Aufgabe **klein** |
|---|---|---|
| Eingabe **gross** | stirbt — 186k/180k Tok, 0 Byte | **laeuft — 4 Aufrufe, 50 s** |
| Eingabe **klein** | stirbt — 335k/325k Tok, 0 Byte | laeuft — 8 s |

⛔ **Nicht die Eingabe verkleinern.** Die untere Zeile ist der Beleg: 3,1x kleinere
Datei, **mehr** Tokens, gleicher Tod. Ein Groessen-Guard wuerde die falsche Ursache
festschreiben.

**Also, verbindlich je Agent:**

- **EIN Auftrag.** Nicht zwei. Der `custom-context`-Agent trug bis v5.21.1 den
  Session-Abgleich **und** den Context-gegen-Context-Vergleich — und starb daran
  (117 000 Tokens, 32 Werkzeugaufrufe, 0 Byte). Der zweite Auftrag geht besser an
  `cleaner_duplikate.py --widersprueche`, das ihn **mechanisch** beantwortet.
- **Hoechstens 4–5 BENANNTE Zieldateien.** Kein offenes Verzeichnis, kein
  „alles unter `knowledge/`“.
- **Der Rettungspfad kommt mit Stichwortliste**, nie als „lies, was du brauchst“.
- **Keine Nachmessungen im Agenten.** Kanonische Zahlen werden ihm gegeben und
  woertlich zurueckverlangt — er soll vergleichen, nicht zaehlen.

Jeder bekommt:
- Scope: `claude-md` / `memory` / `rules` / `custom-context`
- ⛔ **`memory` (v5.81.0): die Tabelle `RETTUNGS_MEMORY` aus Step 1 woertlich** — je Rettung
  der Ordner, in dem die Sitzung lief, und DESSEN Memory-Verzeichnis. Erkenntnisse aus
  einer Rettung gehen in Spalte 3 dieser Zeile, nie pauschal in `$MEMORY_DIR`. Was fuer
  ALLE Unterordner gilt, gehoert in die Wurzel-`CLAUDE.md`/-Rules (die laden ueberall),
  nicht in neun Memories.
- Mode: `knowledge-sync`
- ⛔ **DRITTER AGENT-AUFTRAG: Context gegen Context (NEU v5.7.1).** Die bisherigen Agents fragen „Session gegen Datei". Der teuerste Fehler des Palvedo-Laufs vom 21.08.2026 war aber ein Widerspruch **zwischen zwei Context-Dateien** (`ARBEITSLISTE.md` gegen `ENTSCHEIDUNGEN.md`), den beide Agents ignorierten, weil er in der Session nicht vorkam.

**Auftrag des dritten Agenten, woertlich:** *„Widersprechen sich zwei Context-Dateien dieses
Projekts? Vergleiche CLAUDE.md, die Rules und die Memory-Topics PAARWEISE gegeneinander —
nicht gegen die Session. Melde jede Stelle, an der zwei Dateien dasselbe verschieden sagen."*

⚠ Er laeuft in derselben Welle wie die anderen (Anti-Burst: nie mehr als 2 gleichzeitig) und
zaehlt gegen die Obergrenze.

**Scope-Dedup (NEU v5.0.0, Befund 5):** Vor jedem Dispatch `.claude-mind/analyzed-scopes`
  pruefen. Steht der Scope dort (von `/mind-all` durch einen vorherigen Skill eingetragen),
  **NICHT erneut dispatchen** — im Self-Check ausweisen als
  `scope=<x> → bereits durch <skill> abgedeckt (analyzed-scopes)`.
  ```bash
  bash "$CLAUDE_PLUGIN_ROOT/skills/mind-update/bloecke/step3.5-zuschnitt.sh"
  ```
  **NUR bei gleichem Modus ueberspringen (M3-Fix):** Der Eintrag traegt den Modus (`claude-md=mind-claudemd:default`). `mode: default` ist eine **andere Analyse** als `mode: knowledge-sync`; ein `:default`-Eintrag darf einen `knowledge-sync`-Dispatch **nicht** unterdruecken, sonst faellt der semantische Session-Abgleich still aus. **Ersparnis ist kein Skip-Grund.** **Gilt NUR fuer die Kette** — bei einem einzelnen `/mind-update` ist die Datei leer/alt und alle
  4 Scopes laufen. `custom-context` wird nie uebersprungen (kein anderer Skill deckt ihn ab).
- Bereich-Files (Read-only) — **rules-scope: die `SEM_RULES` aus Step 3c.1** (je nach `TARGET_MODE`:
  `all` = alle Project-Rules wenn Satz klein; `targeted` = nur session-berührte wenn groß; `unscopable`/
  `none` = leer). **Plus die Global-Rules `~/.claude/rules/*.md`** — die werden IMMER mit übergeben
  (wenige, meist klein, immer-aktive Verhaltensregeln), aber **jede EINZELN dem Größen-Guard unterworfen**
  (große global-Rule → auch grep-gezielt, nicht blind). Ist `SEM_RULES` leer bei `TARGET_MODE=unscopable`:
  rules-Agent mit "Project-Rules nicht scopebar → deterministisch-only, /mind-rules einzeln" vermerken —
  **NICHT stillschweigend 0**, und NICHT ersatzweise blind alle großen Rules lesen.
- **Größen-Guard (v4.1.0):** Für JEDE übergebene Datei Zeilenzahl (`wc -l`) UND Bytes (`wc -c`) aus
  Step-1-Inventory mitgeben. **>~600 Zeilen ODER >~60 KB → dem Agenten sagen: NICHT ganz lesen,
  sondern per Stichwort grep-gezielt (±40 Zeilen um Treffer).** (Bytes-Schwelle fängt dichte kurze
  Files: z.B. data-model.md = 428 Z. aber 67 KB / ~17k Tokens.) Sonst Overflow → 0 Output (real
  gesehen). Der Agent hat den Guard auch selbst (context-analyzer), das hier ist der Skill-Hinweis.
- **Die Commit-Coverage-Gaps aus Step 3c** als konkrete Pruef-Punkte ("verifiziere/ergaenze diese unreflektierten Commits in deinem Bereich")
- Session-Auszug — **Quelle je `SESSION_SOURCE`:**
  - ⭐ **v5.160.0 — ZUERST das Verlaufsbuch:** nennt Step 3.5 zu einer Rettung `-> Verlaufsbuch (zuerst lesen)`, bekommt der Agent DIESEN Pfad als erste Quelle, mit dem Abschnitt `rettung=<stamm>` (Arbeitsstand + Claudes Kompaktierungs-Zusammenfassung, 20–30 KB statt 300–950 KB). Die Rettungsdatei darunter nur als Rueckfall — fehlt der Abschnitt oder ist er leer, gilt der Absatz hier unveraendert. Gemessen: der Abschnitt deckt 18–36 % der Marken des Chats bei 3–8 % der Groesse (gemessen 29.10.2026 an drei Rettungen).
  - `gerettet`: **die Rettungsdatei** `.claude-mind/rescued/<ts>_chat.md` (vollstaendiger Chat
    vor der Kompaktierung, ungekuerzt). Bei >600 Zeilen/60 KB gilt der Groessen-Guard des
    Agenten — er greppt gezielt statt blind zu lesen.
    > ⛔ **KONTEXT-FLUT-SPERRE (NEU v5.2.1):** Dem Agenten wird der **PFAD** uebergeben, nie der
    > Inhalt. Im **Hauptkontext** wird `*_chat.md` **nie** gelesen — kein `Read`, `cat`, `sed`/`head`;
    > erlaubt nur zaehlende Aufrufe (`grep -c`, `wc`). **Invariante:** der Lauf wird per Stop-Hook direkt nach einer
    > Kompaktierung erzwungen; die Datei hat mehrere hundert KB (gemessen 417 KB / 555 Beitraege) und loest im frisch
    > geleerten Kontext sofort die naechste Kompaktierung aus, die eine neue Rettung erzeugt, die den naechsten
    > Zwangslauf ausloest. Ein `Read` darauf im Hauptfluss ist **Abbruchgrund**.
  - `live`: der Sampler-Auszug wie bisher (USER + ASSISTANT_TEXT, 3-stufiges Sampling).
  - **`gerettet+live` (NEU v5.2.2, der Normalfall nach einer Kompaktierung): BEIDE.** Dem
    Agenten werden **zwei** Quellen genannt — der Rettungspfad (vollstaendig, aber nur bis zur
    Kompaktierung) **und** der Live-Sampler-Auszug (deckt die Zeit danach ab).
    > **Keine Doppelung:** Die Rettung endet am Kompaktierungs-Zeitpunkt, der erzwungene Lauf soll aber die Arbeit
    > seitdem einspeisen. Mit nur einer Quelle fehlt entweder die Tiefe (live ist gesampelt) oder die Aktualitaet (Rettung ist alt).
- ⛔ **Der Agent MUSS die uebergebenen kanonischen Zahlen ZURUECKGEBEN (NEU v5.7.0).**
  Zwei Fehlberichte belegt: „14 Topic-Dateien" bei uebergebenen **10**, und
  „`stop.sh` und `session-start.sh` sourcen `lib.sh` nicht (0 von 2)" — gemessen sourct
  `session-start.sh` sie sehr wohl. Beide klangen plausibel.
  Deshalb endet jeder Agent-Prompt mit: *„Gib in der ersten Zeile die dir uebergebenen Zahlen
  woertlich zurueck."* Weicht die Rueckgabe ab, ist der ganze Agentenbericht **ungeprueft** —
  nicht teilweise gueltig. Eine Zeile Kosten, der Unterschied zwischen Hinweis und Beleg.
- **Im Self-Check MUSS die Quelle stehen** (`Session-Quelle: gerettet+live <pfad>` bzw.
  `gerettet <pfad>` bzw. `live`) — sonst ist nicht erkennbar, ob der Sync auf dem vollen Chat,
  auf Resten oder auf beidem lief. **`gerettet` allein nach einer Kompaktierung ist ab v5.2.2
  ein Befund, kein Normalzustand.**

### Session-Auszug-Sampling (Plan-EC2: 3-stufiger Algorithmus)

Bei langen Sessions (>500 Events) verliert naives "letzte 200" Architektur-Entscheidungen
aus der Mitte. 3-Stufen-Algorithmus:

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-update/bloecke/step3.5-sampling.sh"
```

### 4 Agent-Dispatches — sequenziell bzw. in 2 Wellen à 2 (NIE ≥3 gleichzeitig)

**NICHT alle 4 in EINER Tool-Call-Message** (das wäre der ≥3-Burst, der das Server-Rate-Limit
trippt — v4.0.1). Stattdessen: **einzeln nacheinander**, ODER in 2 Wellen à 2 (Welle 1 =
Agent 1+2 in einem Tool-Call, Welle 2 = Agent 3+4 im nächsten). Alle 4 laufen — nur nie 3-4 auf einmal.

⛔ **`run_in_background: false` in JEDEM Agent-Aufruf (v5.94.0, Nutzer-/Anton-Entscheidung 11.09.2026).** Vorgabe des Agent-Werkzeugs ist HINTERGRUND: der `tool_result` ist dann nur das Ack „Async agent launched“ (1 151 B, nach 1–2 s), das Ergebnis kommt — wenn überhaupt — später als `<task-notification>`. Gemessen 10.09.2026 (`docs/plugin/rueckkanal-messung.md`): getrennte Tool-Calls serialisieren im Hintergrund NICHTS (vier Agenten gleichzeitig), **5 von 8** Ergebnissen kamen nie an. Mit `false` blockt der Aufruf bis zur Rückgabe, `RUECKGABE` IST der `tool_result`, ein Nachliefern mitten im Fan-out ist mechanisch unmöglich. ⚠ Preis: die Sitzung wartet je Agent 60–130 s und ist solange nicht ansprechbar.

⭐ **Trifft der Agent sein Turn-Limit (`maxTurns`, 25 seit v5.147.0) VOR dem Bericht** (der `tool_result` endet ohne Ergebnis, der Agent lebt), ist die Fortsetzung `SendMessage {to: <agentId>, message: „Bericht jetzt liefern“}` — ⛔ **KEIN neuer `Agent`-Aufruf**, das wäre ein zweiter Agent gegen dieselbe Grenze (v5.96.0). Gemessen 12.09.2026 (Rita): zwei Agenten am Limit, beide lieferten nach der Nachricht vollständig. ⚠ Im Desktop-Reiter „Code“ ist `SendMessage` verzögert: erst `ToolSearch select:SendMessage`, dann ist es da.
⭐ **Erst damit misst die Grenze oben wieder etwas:** zwei Aufrufe in EINER Nachricht = zwei
gleichzeitig, getrennte Nachrichten = nacheinander.

```
Agent(subagent_type: "claude-mind-manager:context-analyzer", run_in_background: false,
      description: "Knowledge-sync <scope>", prompt: <Auftrag aus der Tabelle>
      + "Nenne zu JEDEM Zitat die Datei und die Zeilennummer, aus der du es gelesen hast. Was du ohne Fundstelle schreibst, kennzeichne als UNGEPRUEFT.")
```

| Agent | scope | mode | Input |
|---|---|---|---|
| 1 | `claude-md` | `knowledge-sync` | CLAUDE.md project + global **+ die `CLAUDE.md` der Roster-Unterordner (`UNTER_KONTEXT`, v5.106.0)** + Session-Auszug aus `$SESSION_SAMPLE_BASH` |
| 2 | `memory` | `knowledge-sync` | MEMORY.md + Topic-Files aus Step 1 + Session-Auszug — **v5.109.0: im Rollen-Aufbau ALLE Verzeichnisse aus `mind_memory_dirs "$PROJ"`, je Verzeichnis benannt, und die Tabelle `RETTUNGS_MEMORY`; ⛔ der Agent schreibt in das Verzeichnis der Rettung, nie ueber Slugs hinweg** |
| 3 | `rules` | `knowledge-sync` | **`SEM_RULES` (Step 3c.1, je `TARGET_MODE`)** + Global-Rules (immer, je einzeln größen-geguardet) **+ die Rules der Roster-Unterordner (v5.106.0, je Datei mit Ordner)** + Session-Auszug — bei großem Satz NICHT alle Project-Rules; jede Datei >600 Z. **ODER >60 KB** mit Größen-Guard (grep-gezielt, nicht ganz lesen) |
| 4 | `custom-context` | `knowledge-sync` | `CUSTOM_CONTEXT_FILES` aus Step 1.5 + Session-Auszug |

⛔ **In JEDEN der vier Aufträge gehört dieser Satz wörtlich (v5.138.0, beide Sätze):**
> „Nenne zu JEDEM Zitat die Datei und die Zeilennummer, aus der du es gelesen hast. Was du ohne Fundstelle schreibst, kennzeichne als UNGEPRUEFT.“

⭐ **Warum er wirkt — gemessen (Vera, Zustellplan 26.09.2026):** drei von vier Wissens-Sync-Agenten meldeten je einen Befund, der bei der Gegenprobe fiel (ein erfundenes Zitat mit 0 Grep-Treffern, zwei Pfade ab falscher Wurzel geglobt, ein „kommt nirgends vor" nach halbem Bestand) — **keiner mit Vorbehalt.** Der Agent, der den Satz bekam, stellte als einziger seine unsicheren Stellen selbst unter
NICHT GEPRÜFT.
⛔ **Er ist eine BITTE, kein Gate.** Nichts prüft die Fundstelle nachträglich (Stand v5.138.0); die halbe Forderung („nenne file:line") stand in `agents/context-analyzer.md` seit v4.1.0. Vera fing die drei Befunde durch das **Nachlesen jeder Zeilenangabe**.
**Eine Regel stellt das Wissen bereit, sie verhindert den Fehler
nicht** (Anton, 29.09.2026). Wirksam war erst die Aufforderung, das Ungedeckte selbst
zu KENNZEICHNEN.
⚠ **Deckel: 0 B** — Skill- und Agent-Texte laden nicht im Startkontext, sondern mit dem Aufruf; ausgewiesen, weil „kostet nichts" sonst niemand nachprüft.

**Skip-Logik pro Agent:**
- Agent 4 (`custom-context`) skippen wenn `${#CUSTOM_CONTEXT_FILES[@]} == 0` (Plan EC4) — das ist die EINZIGE erlaubte Auslassung; die anderen 3 sind unbedingt Pflicht.
  ⛔ **v5.104.0: das Ueberspringen wird QUITTIERT, sonst ist der Lauf ein Teilsync:**
  `mind_agent_uebersprungen custom-context "${#CUSTOM_CONTEXT_FILES[@]}" "$PROJ"` — schreibt
  nur bei 0 Dateien, die Bilanz weist `UEBERSPRUNGEN: custom-context` aus und zieht es von
  ERWARTET ab. ⛔ **Ein `mind_agent_dispatch custom-context` bei 0 Dateien ist ab jetzt selbst
  ein Befund** (UNGEPRUEFT „dispatcht ohne Dateien") — gemessen 13.09.2026 in Palvedo: der
  vierte Agent wurde vorgetäuscht (Zahl in derselben Sekunde, dann eine 167-B-Handdatei),
  weil der Skill keinen anderen Weg zu „voll" liess.

### ⛔ Die Agentenzahl kommt aus dem Kontextstand, nicht aus dem Ermessen (NEU v5.19.0)

**Anlass, dreimal an zwei Tagen gemessen:** bei 888k–914k Kontext würden vier
Agents die Kompaktierung **mitten im Lauf** auslösen. Jedes Mal wurde deshalb gekürzt — als
**stille Ermessensentscheidung**, die nirgends auftauchte. Der Creator-Lauf benannte den Ausweg selbst:

> *„`mind-all` koennte den Kontextstand VOR dem Agent-Dispatch pruefen und die Zahl der
> Agents daran anpassen, statt sie fest auf vier zu setzen — dann bleibt die Entscheidung
> nicht dem Ermessen des Laufs ueberlassen und landet automatisch im Bericht."*

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-update/bloecke/step3.5-agentzahl.sh"
```

⛔ **Hier stand bis v5.54.0 die Begründung für einen halben Lauf** — *„das senkt
den Anspruch nicht, es macht ihn ehrlich“* — samt Vorschrift für `AGENT_MAX=0`. **Beides ist gegenstandslos:** es gibt keinen halben Lauf mehr; der Text bleibt als Historie stehen, weil er erklärt, warum die Schwelle existierte, keine geltende Anweisung.

⛔ **Was heute gilt (v5.64.0):** der Lauf faehrt **immer** und versucht **immer alle 4**
Agents. Es gibt **keine Schwelle mehr**, an der er vorher aussteigt. Der grep-Rueckfall
bleibt Pflicht fuer den **einzelnen** Agenten, der LEER zurueckkommt (mind-all Step 2) —
das ist ein anderer Fall als „er wurde nie gestartet“.

⛔ **Das Teilsync-Verbot ist damit nicht weg, es wird nur HINTERHER gemessen.**

| | war (v5.55.0–v5.63.0) | ist (v5.64.0) |
|---|---|---|
| Messpunkt | **vorher**, Tokenstand als Vorhersage | **hinterher**, `umfang=` und `ungepruef=` |
| Quelle | `mind_transkript_pfad` — ein Merker je **Projekt** | die Agent-Quittung dieses Laufs |
| Folge | der Lauf faellt aus | der Lauf laeuft; ein unvollstaendiger begleicht **keine** Schuld |

⭐ **Das ist strenger, nicht laxer.** Eine Vorhersage konnte in beide Richtungen
danebenliegen; die Quittung zaehlt, was wirklich zurueckkam. Ein Agent mit `bytes:0` war
schon immer ein Teilsync, und `mind_sync_voll` sieht ihn.

⛔ **Warum die Vorhersage weg musste — gemessen.** Der Tokenstand kam
aus `mind_transkript_pfad`: **eine** Merkerdatei je Projekt für **mehrere** Sitzungen, der Letzte gewinnt. In `APP - Palvedo` lagen am 10.09.2026 fünf aktive
Transkripte nebeneinander (169 971 · 472 250 · 650 698 · **721 405** · 867 259); der
Merker zeigte auf das vierte, die abgewiesene Sitzung stand bei **~130 000**.
⚠ `lib.sh` nannte diesen Rest seit v5.38.0 selbst; tragbar, solange er eine Mahnung kostete, nicht mehr, als er den ganzen Lauf kostete.
Nutzer-Entscheidung 10.09.2026: *„die sollen garnicht mehr tokens messen das soll
komplett raus“*.

### ⛔ Agent-Quittung — PFLICHT, vor UND nach jedem Agent (NEU v5.14.0)

```bash
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
# v5.19.0: NUR anlegen, wenn keine existiert. In der Kette hat mind-all sie
# schon in Step 0 angelegt — ein blindes `start` wuerde sie hier LOESCHEN und
# genau die Spur vernichten, die den Teilsync belegt. Bei einem Einzelaufruf
# von /mind-update gibt es keine, und dann legt dieser Zweig sie an.
# ⛔ v5.21.3: die 4 ist PFLICHT — siehe mind-all Step 0. Ohne sie meldet die
#    Bilanz `DISPATCH=0` und behauptet damit, der Fan-out habe nicht
#    stattgefunden. Bei nur 3 Bereichen (custom-context entfaellt mangels
#    Dateien) hier 3 uebergeben, nicht 4.
# ⛔ v5.104.0: 3 bei 0 Custom-Context-Dateien — Step 1.5 hat gezaehlt — und das
#    Ueberspringen wird QUITTIERT; sonst heisst es "nur 3 von 4" und der Lauf ist Teilsync.
[ "${#CUSTOM_CONTEXT_FILES[@]}" -gt 0 ] || mapfile -t CUSTOM_CONTEXT_FILES < "$(mind_sampler_pfad "$PROJ" mind-update-ccf.txt)" 2>/dev/null   # v5.153.0
if [ "${#CUSTOM_CONTEXT_FILES[@]}" -eq 0 ]; then
  [ -f "$PROJ/.claude-mind/agent-quittung.jsonl" ] || mind_agent_quittung_start "$PROJ" 3
  mind_agent_uebersprungen custom-context 0 "$PROJ"
else
  [ -f "$PROJ/.claude-mind/agent-quittung.jsonl" ] || mind_agent_quittung_start "$PROJ" 4
fi
mind_agent_dispatch "<bereich>" "$PROJ"    # VOR dem Start — ⛔ Reihenfolge: <bereich> <projekt>. v5.125.0: vertauscht
                                            #   oder unbekannt = rc 2, nichts geschrieben (18.09.: vier Streuner-Ordner im cwd)
# ... Agent laeuft (run_in_background: false — der tool_result IST die Rueckgabe) ...
# ⛔ v5.94.0: die Bytes kommen aus einer DATEI, nie aus dem Kopf. Den tool_result
#    mit `Write` nach $PROJ/.claude-mind/agent-<bereich>.md legen, dann:
mind_agent_ergebnis "<bereich>" --datei "$PROJ/.claude-mind/agent-<bereich>.md" "$PROJ"
#    ⛔ v5.126.0: OHNE den dispatch oben (derselbe Lauf, seit der letzten Start-Zeile) ist das
#       rc 2 und schreibt nichts — „dispatch fehlt“. Vergessen heisst: Agent erneut MIT Quittung
#       fahren, nicht nachtragen (03.09., 13.09., 18.09.: DISPATCH=0 bei gelaufenen Agents).
# Kein tool_result (Agent gestorben, Aufruf abgebrochen)? Dann OHNE Datei quittieren —
# `--datei` auf eine fehlende Datei schreibt bytes:0, und 0 heisst `ungepruef=`.
# ⛔ v5.97.0 — DREI DINGE, die die Bilanz seither SELBST prueft (Ritas Lauf 22:05, 11.09.):
#    · die Zahlform `mind_agent_ergebnis <bereich> <n>` schreibt bytes:0 — nur --datei misst
#    · traegt die Datei das Hintergrund-Ack („Async agent launched"), ist das bytes:0
#    · ⛔ v5.145.0: ein ROHDUMP (Datei beginnt mit `{"`/`[` oder hat JSONL-Zeilen) ist bytes:0 —
#      abgelegt wird der tool_result, nie das Transkript des Agenten (Veras Befund M-J)
#    · ⚠ eine `.output`-Datei der Harness gibt es NUR bei Hintergrund-Agenten. Wer sie bei einem
#      blockierenden Agenten quittiert, quittiert eine fehlende Datei: bytes:0 → `ungepruef=`
#    · liegen dispatch und ergebnis unter 30 s auseinander, gilt der Bereich als
#      UNGEPRUEFT: ein blockierender Agent braucht 60–130 s, dieselbe Sekunde heisst
#      „beide Zeilen nachgetragen". Deshalb: mind_agent_dispatch VOR dem Aufruf, in
#      einer EIGENEN Bash — nicht am Ende alles auf einmal.
```

⛔ **Ein geschaetzter Bytewert ist die Fehlzahl, an der Lauf 14:50 (10.09.2026) als
vollstaendig durchging:** `claude-md` hatte kein gelesenes Ergebnis, die Quittung trug
`bytes:800`, die Bilanz sagte 4/4. Deshalb `--datei`: die Zahl ist die Groesse einer vorhandenen
Datei, oder 0. Die Zahlform `mind_agent_ergebnis <bereich> <n>` bleibt fuer Prueffaelle erlaubt
und traegt `quelle:zahl` — im Lauf nicht.

⛔ **Der Anleger sass bis v5.18.0 AUSSCHLIESSLICH hier — im Schritt, den ein Lauf bei hohem Kontext auslaesst.**
Fiel Step 3.5 aus, entstand keine Quittung, und ihr **Fehlen war von ihrem Schweigen nicht zu
unterscheiden**. Dreimal gemessen (23.08. + 24.08. Claude Mind Manager, 24.08. Creator mit 2 von 4 Agents). Seit v5.19.0
legt `mind-all` Step 0 sie an, bevor die Kette startet.

**Der `dispatch`-Eintrag steht VOR dem Start.** Das ist der ganze Punkt: ein Agent, der
stirbt, hinterlaesst dann einen Merker, den nur er selbst aufloesen kann. Wer erst nach der
Rueckkehr protokolliert, protokolliert **nur die Ueberlebenden**.

⛔ **Ein Agent, der stirbt, und ein Agent, der nichts findet, sehen im Bericht identisch
aus** (Debug-Klassen `agent-gestorben` 4× und `agent-fehlbericht` 6×, zusammen 10 Vorkommen). Der Umgang stand als **Prosa**
(„den Bereich als UNGEPRUEFT in den Bericht schreiben"), und Prosa hat es nicht verhindert: am 23.08.2026
wurden die Agents **gar nicht erst losgeschickt**, der Lauf lief durch.

⚠ **`0 Byte` ist ein `ergebnis`-Eintrag, kein fehlender.** „Leer zurueckgekommen" und „nie
zurueckgekommen" sind verschiedene Befunde und werden getrennt gezaehlt.

**Prompt-Format pro Agent** (Skill-Review M5 — Serialisierung explizit):

Skill konstruiert pro Agent einen Markdown-Prompt mit Sections:
```markdown
mode: knowledge-sync
scope: <claude-md|memory|rules|custom-context>

## Memory Dir
<MEMORY_DIR-Pfad aus get_memory_dir()>

## Custom Context Files       (NUR scope: custom-context)
./plan.md
./research.md
./docs/architecture.md

## Session Auszug (letzte N Events)
[Inhalt aus $SESSION_SAMPLE_BASH JSON, formatiert als USER/ASSISTANT-Blocks]
```

Die `CUSTOM_CONTEXT_FILES`-Array wird **als 1 Pfad pro Zeile** in die `## Custom Context Files`-Section serialisiert:
```bash
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
cat "$(mind_sampler_pfad "$PROJ" mind-update-ccf.txt)"   # v5.153.0: das Array aus Step 1.5 ist hier leer — die Liste steht in der Datei
```

Findings aller (3-4) Agents aggregieren → an Step 4.

## Step 4: Findings-Klassifikation + Fixes (Skill-Review M6 — Header ergaenzt)

**Pre-Edit Read (MUST, praezisiert v3.2.2):** Step 1 hat zwar alle Context-Dateien
gelesen, aber das zaehlt NICHT fuer Step 4 — Read muss im SELBEN Tool-Call-Kontext
wie Edit erfolgen.

**1× Read der Ziel-Datei** reicht fuer N sequentielle Auto-Fixes (Edit-Tool
garantiert "file state is current — no need to Read it back"). Re-Read nur wenn
anderes Tool die Datei zwischendurch modifiziert.

### 4a: Klassifikation pro Finding

Jedes Finding bekommt eine Klasse aus 9 Optionen (4 Drift + 5 Knowledge-Sync):

**Drift-Klassen (aus Step 3, bestehend):**

| Klasse | Bedeutung | Aktion |
|---|---|---|
| **AUTO** | Mismatch, sicher fix-bar (Versions-Drift CLAUDE.md ↔ package.json, paths→globs) | Read + Edit OHNE Frage |
| **ASK** | Echter Mismatch ABER mit Build/Release-Konsequenzen (z.B. `pyproject.toml` Version, Hatchling/PyPI-Metadata, semver-relevant) | User fragen — NIE silent auto-fixen |
| **DESIGN** | "By design" markiert in Rule/CLAUDE.md (explizite Regel sagt "NICHT anfassen") | NICHT als "Issue" zaehlen, aber als Hinweis am Ende erwaehnen — ggf. Regel praezisieren |
| **DEAD** | Pfad existiert nicht UND Pfad enthaelt `/` oder `\` (siehe Step 3b) | AUTO falls eindeutig (max 5 Findings), sonst ASK |

**Knowledge-Sync-Klassen (aus Step 3.5, NEU v3.3.0):**

| Klasse | Bedeutung | Aktion |
|---|---|---|
| **UPDATE** | Custom-Context-Wert veraltet (Session-Stand widerspricht) | ASK Default — User entscheidet weil "veraltet" subjektiv |
| **ENRICH** | Wert vorhanden aber vage — Session hat Details | ASK Default — User entscheidet ob Details rein sollen |
| **ADD** | Wissen aus Session fehlt komplett in Custom-Context | ASK Default — User waehlt Ziel-Datei + Section |
| **NEW_FILE** | Komplett neues Thema, kein passender Container | ASK Default — User bestaetigt Filename + Inhalt |
| **INFO** (uebergreifend, Drift+Sync) | Hinweis ohne Action (Archive-Vorschlag, Limit-Warnung) | Listen only, kein Action |

**v5.0.0 — Modus entscheidet, nicht die Klasse:**
- `AUTO_MODE=yes` (Default): UPDATE/ENRICH/ADD/NEW_FILE werden **angewendet**, nicht gefragt.
  Die "ASK Default"-Angaben in den Klassen-Tabellen oben gelten NUR fuer `--ask`.
- `AUTO_MODE=no` (`--ask`): Klassen-Tabelle wie beschrieben (ASK Default).
- **DESIGN bleibt in JEDEM Modus ausgenommen.**

**KRITISCHE REGEL (weiterhin):** Sagt der User "behebe alle"/"fix all"/"ja mach", ist das
explizite Erlaubnis — auch fuer ASK-Findings im `--ask`-Modus.

### 4b: DESIGN-Detection-Heuristik (deterministisch, keine silent dropouts)

**Vor** der Klassifikation eines Mismatch-Findings als DESIGN: explizite
Marker-Suche durchfuehren. Nur wenn ein Marker matched, ist DESIGN gerechtfertigt.

**Marker-Patterns (Regex, alle case-insensitive):**

**WICHTIG:** `target_basename` MUSS via `re.escape(basename)` substituiert werden,
sonst matcht `pyproject.toml` auch `pyproject_toml` (Punkt = Regex-Metacharakter).

```python
import re
escaped = re.escape(target_basename)  # z.B. "pyproject\\.toml"

DESIGN_MARKERS = [
    # "NIEMALS [target]" oder "NEVER edit/change/modify [target]"
    rf'NIEMALS\s+`?{escaped}',
    rf'NEVER\s+(edit|change|modify|touch)\s+`?{escaped}',

    # Explizite Marker (target-unabhaengig, in Naehe des targets greppen)
    r'by\s+design',
    r'intentional(ly)?',
    r'absichtlich',
    r'manuell\s+synchronisieren',
    r'manually\s+sync',

    # Sync-Hinweise — broad pattern statt eng
    r'(einmal\s+pro|once\s+per)\s+(Stable-?Release|release)',
    r'(last|letzter?)[-_\s]+sync',
]
```

**Detection-Workflow:**

1. Mismatch gefunden (z.B. `pyproject.toml` 1.0.0 vs Stable 1.0.2)
2. Extract `target_basename` aus Finding (z.B. `pyproject.toml`)
3. Grep ALLE rule files (project + global) + CLAUDE.md (project + global) fuer
   DESIGN_MARKERS mit substituiertem `target_basename`
4. **Wenn Match in einer Rule:**
   - Klassifizieren als DESIGN
   - Show file:line des Matches
   - Hinweis: "Regel '$rule_path:$line' sagt '$matched_text' → Fix nicht auto"
   - **ABER:** Trotzdem als Finding mit Klasse DESIGN listen — NICHT silent dropout
5. **Wenn KEIN Match:** → Klasse AUTO oder ASK je nach Severity (siehe 4c)

**Beispiel** (echt aus Session 2026-05-05):
- Mismatch: `pyproject.toml` Version `1.0.0` vs Stable `1.0.2`
- Grep: `build-process.md:14` sagt `NIEMALS \`pyproject.toml\` Version anfassen`
- Match auf Pattern `NIEMALS\s+\`?pyproject\.toml` → DESIGN
- **Aber:** Step 6 Report listet trotzdem als `[DESIGN]`, NICHT "0 issues"

### 4c: Fix-Tabelle mit Coupled-Files

| Klasse | Tool | Aktion | Coupled-Files (auch pruefen/updaten) |
|---|---|---|---|
| AUTO Version-Drift | Edit | Read → update version string in CLAUDE.md | (none — single source) |
| AUTO paths→globs | Edit | Read → replace `paths:` with `globs:` | (none — per Datei isoliert) |
| ASK `pyproject.toml` Version | Edit (after user OK) | Read → update version + Sync-Datum-Kommentar | **Generisch ableiten** via Coupled-Files-Detection (siehe unten) — NICHT hardcoden. Beispiel Zustellplan: `__init__.py` Fallback + `dist/stable/_build_info.py` Verifikation |
| ASK CLAUDE.md major | Edit (after user OK) | Read → update + show diff | (project-spezifisch, je nach Inhalt) |
| DESIGN Marker | (no edit) | List finding mit Verweis auf Marker-Rule, ggf. Vorschlag Regel-Praezisierung | Marker-Datei + Ziel-Datei |
| DEAD path | Edit | Read → entfernen oder Pfad korrigieren | (none) |

**Coupled-Files-Detection (generisch, NICHT hardcoded):**

- Skill grept das Mismatch-Target (z.B. `pyproject.toml`) in `.claude/rules/*.md` +
  globale Rules + CLAUDE.md (project + global)
- **Pattern fuer gekoppelte Files** (Regex, in Marker-Match-Zeile + Folgezeilen):
  ```python
  COUPLE_PATTERNS = [
      r'auch\s+`?([^\s`]+\.\w+)`?',          # "auch `__init__.py`"
      r'Coupled\s+with\s+`?([^\s`]+)`?',     # "Coupled with `dist/stable/_build_info.py`"
      r'Sync(?:hron(?:isieren)?)?\s+mit\s+`?([^\s`]+)`?',  # "Synchron mit ..."
      r'(?:Fallback|fallback)[\s:]+`?([^\s`]+\.\w+)`?',  # "Fallback: `__init__.py`"
  ]
  ```
- Extrahiere alle gekoppelten Filenames → Read sie alle vor dem Fix
- Bei Auto-Edit: alle gekoppelten Files in EINER konsistenten Operation
- Bei User-Frage: gekoppelte Files explizit erwaehnen
  - z.B. *"Fix `pyproject.toml` 1.0.0 → 1.0.2? Coupled-Files aus Rule `build-process.md:14`:
    `__init__.py` Fallback (mit-updaten), `dist/stable/_build_info.py` (verifizieren)."*

**Wenn KEINE Coupled-Files gefunden:** Nur das Target-File anpacken, kein Hint im
User-Prompt.

### 4d: Apply-Reihenfolge

1. AUTO-Findings: Read jede Ziel-Datei → Edit → log
2. DEAD-Findings: bei <=5 → AUTO, sonst ASK
3. DESIGN-Findings: NICHT auto, listen als Hinweis
4. ASK-Findings: User fragen, dann (ggf.) Read + Edit + Coupled-Files

For each fix, log what was changed (file, line, before/after).

## Step 5: ⭐ VERDICHTEN — nach der Vorschrift, nicht nach Gefühl (v5.90.0, ersetzt „Lossless Compression“)

⛔ **Hier stand bis v5.89.0 „Lossless Compression“:** Zeilen von Hand kürzen, „only where meaning is
100% preserved“ — ohne Gate, Zählung, Leser. Drei echte Läufe massen das als unsicher (`docs/plugin/verdichten-kalibrierung.md`: drei Verfälschungen bei 100 %
Stufe 1). Der Schritt bleibt, sein Verfahren ist ersetzt. Vierter Träger nach `mind-rules`,
`mind-claudemd`, `mind-memory`; `mind-update` fährt nach jeder Kompaktierung und ist der häufigste.

**Die vollständige Vorschrift — Agent, Kasten, Gate, Stufe 3, Bericht — steht in
[references/bestands-pass.md](../../references/bestands-pass.md), Abschnitt „VERDICHTEN“.
Lies sie.** Hier nur, was für diesen Skill gilt:

| | |
|---|---|
| **Kandidat** | die **GRÖSSTE** Datei in Bytes unter `$PROJ/CLAUDE.md` und `$PROJ/.claude/rules/*.md` — **eine je Lauf**, und **nicht die, die in den letzten N Läufen schon Kandidatin war** (v5.138.0, `mind_verdicht_kandidat`; N = `Dateizahl − 1`, Regler `MIND_VERDICHTEN_HISTORIE`). ⛔ Nie `rollen.md`, nie Memory (das macht `mind-memory` Step 6e) |
| ⛔ **welche Zeilen liest ein Programm** | ist der Kandidat `CLAUDE.md`: die Unantastbaren aus `mind-claudemd` Step 5e (Codeblöcke byteweise, Versionszeilen, Adress-Zeiger) **und** `claudemd_pipeline.py` vor/nach dem Lauf — kein Check neu rot. Ist es eine Rule: jede gegatete Tabelle (`**<n>** \|`, das Format von `zaehl_gate.py`) byteweise, jedes Quittungs- oder Merker-Format, das ein Hook parst |
| **Überholt-Kandidaten** | aus den Step-3-Drift-Befunden dieses Laufs (stale Versionen, tote Pfade, alte Counts) — **benannt** an den Agenten. ⭐ Der Ertrag hängt am Aufrufer |
| **verwerfen, wenn** | Stufe 1 < 100 % · Marker unbenannt verloren · nicht kleiner · Zeilenenden geändert · Pipeline-Check neu rot · Dauerkontext nach dem Anwenden nicht kleiner |
| ⛔ **Stufe 3** | der Wort-Diff wird GANZ gelesen, bevor angewendet wird. **Ohne Leser: nicht anwenden** — Ergebnis, Bericht, Diff ablegen, Pfad melden |
| ⚠ **in der Kette** | läuft `mind-update` in `/mind-all`, haben `mind-claudemd` (Step 5e) und `mind-rules` (Step 9b) ihre Datei schon verdichtet — dann hier **die nächstgrößere**, nie dieselbe zweimal im Lauf (`analyzed-scopes` trägt `verdichtet=<datei>`) |

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-update/bloecke/step5-verdichten.sh"
```

⛔ **Der Bericht dieses Schritts sind die drei Zeilen aus `mind_verdichtung_pruefen`** — oder
die Zeile `verworfen: <grund>`. **Kein Bericht = der Schritt lief nicht.**

## Step 5d: ⛔ Das Kontext-Tor — PFLICHT vor jedem `ADD` (NEU v5.26.0)

**Nutzer-Auftrag 30.08.2026:** *„überall es wird immer mehr, es darf nicht sein
— führe was ein wo der Context durch läuft: ist es irgendwo schon, ist es
selbsterklärend, ist es im Code schon erklärt. … in den Context-Dateien soll
kein unwichtiger Müll stehen, er ist begrenzt, wertvoll und kostet Geld."*

Bis v5.25.0 arbeitete dieser Command nur **rückwärts** — er prüfte, was schon da
ist. **Es gab kein Tor beim Hineinschreiben.** Deshalb wächst alles.

**Die vollständige Vorschrift steht in
[references/kontext-tor.md](../../references/kontext-tor.md)** — die Pruefliste
A1–D10, beide Richtungen, die Quittung, die Grenzen. **Lies sie**, bevor du
diesen Schritt ausführst. Hier steht nur, was für **diesen** Command gilt:

| | |
|---|---|
| **Bereich** | "$PROJ/CLAUDE.md" |
| **vorwärts** | vor JEDEM `ADD`/`NEW_FILE` dieses Laufs |
| **rückwärts** | über die Zieldatei, einmal je Lauf |

```bash
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { CLAUDE_PLUGIN_ROOT=$(jq -r '.plugins["claude-mind-manager@kohlosseum"][0].installPath // empty' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null); [ -n "$CLAUDE_PLUGIN_ROOT" ] && { CLAUDE_PLUGIN_ROOT=$(cygpath -u "$CLAUDE_PLUGIN_ROOT" 2>/dev/null || printf '%s' "$CLAUDE_PLUGIN_ROOT"); echo "WARN: CLAUDE_PLUGIN_ROOT war leer — Rueckfall auf installed_plugins.json: $CLAUDE_PLUGIN_ROOT (v5.107.0)" >&2; }; }   # v5.107.0 Rueckfall
[ -n "$CLAUDE_PLUGIN_ROOT" ] || { echo "ERROR: CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 1; }
TOR="$CLAUDE_PLUGIN_ROOT/references/cleaner_tor.py"

# 1) VORWAERTS — vor jeder einzelnen Ergaenzung
python "$TOR" --text "<die geplante Zeile>"

# 2) RUECKWAERTS — ueber die Zieldatei dieses Laufs
python "$TOR" --datei "$PROJ/CLAUDE.md"

# 3) D1 "WOHIN?" — NEU v5.39.0, eingehaengt v5.40.0.
#    Das Tor oben sagt OB etwas hinein darf. D1 sagt WOHIN es gehoert.
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_einordnung.py" --wohin "$PROJ/CLAUDE.md"
```

## ⛔ D1 — die neunte Frage: WOHIN gehoert diese Aussage?

**Die Pruefliste oben prueft, OB etwas hinein darf; B4 fragt nur, wie OFT es gebraucht wird. WOHIN genau, sagt D1.**
B3 prueft nur den **schon gewaehlten** Ort (zustimmen oder ablehnen, nicht umleiten) — ein Tuersteher, kein Wegweiser. Wer durchkommt, landet fast immer in einer immer-ladenden Datei.

| Klasse | wann man es braucht | Ort |
|---|---|---|
| **BREMSE** | bevor man merkt, dass man nachschlagen sollte | muss **immer** laden |
| **ANLEITUNG** | waehrend der Arbeit | **Command + Dateipfad** (Doppelzeiger) |
| **BELEG** | nur wenn jemand die Regel anzweifelt | Archiv oder `docs/`, laedt nie |
| **UNBESTIMMT** | kein Formmerkmal greift | ⛔ **Ort bleibt, wo er war** |

⛔ **D1 MELDET, es entscheidet nicht.** Die Merkmale sind Formmerkmale und liefern
**Kandidaten** — dieselbe Doktrin wie `cleaner_leitplanke.py` und wie `art()` in
`debug_auswertung.py`. Ist BREMSE gegen ANLEITUNG nicht eindeutig, kommt
**UNBESTIMMT** heraus und der Ort **bleibt unveraendert**. Die wahrscheinlichere
Zelle zu raten ist verboten: eine geratene Zuordnung wird spaeter zitiert.

⭐ **Der haeufigste echte Fall ist TEILBAR** — ein Absatz mit einer Bremse UND
ihrem Beleg. Dann geht der Beleg ins Archiv und die Bremse bleibt.

⚠ **Bekannte Schwaeche, nicht verschwiegen:** „wann brauche ich es" ist eine Aussage ueber den **Leser**. Gemessen 07.09.2026 brauchte der Manager `hooks.md` 8x und `architecture.md` 7x — Dateien des Arbeiters laut Rollentabelle. Mechanisch entscheidbar? **UNGEMESSEN**.

⛔ **Die Quittung wird um `D1` erweitert** — sonst ist nicht unterscheidbar, ob D1
lief und nichts fand oder gar nicht lief:

```
tor=<datei>:A1/A2/A3:B4/B5/B6:C7/C8/C9:D10:D1=<bremse>/<anleitung>/<beleg>/<unbestimmt>
```


⛔ **Die Quittung MUSS in den Self-Check-Block des Berichts**, eine Zeile je
`ADD`. Fehlt sie, ist der Lauf ein **Teilsync** — dieselbe Kopplung wie
Bestands-Pass (v5.22.0) und Schritt-Quittung (v5.25.0).

```
tor=<datei>:A1/A2/A3:B4/B5/B6:C7/C8/C9:D10
```

⛔ **A1 (Code, andere Datei), B4, C8 und D10 beantwortet `cleaner_tor` NICHT — es nennt sie.** Dafür gibt es
`cleaner_duplikate`, `cleaner_aussagen --code` und `cleaner_grenzen`. Die Klasse
`instrument-nachgebaut` steht mit 7 Vorkommen im Debug-Ordner, und **kein
einziger Nachbau war besser als das Original** (`werkzeuge-zuerst.md`).

⚠ **A1, A2, A3, B6, C7b und C9 bleiben Urteile.** Das Tor erzwingt eine **Antwort**, nicht die
richtige — wie die Agent-Quittung (v5.19.0), die keinen Agenten zur Arbeit
zwingt, sondern sein Fehlen sichtbar macht.


## Step 5d: ⛔ Der Bestands-Pass — PFLICHT, auch bei leerem Befund (NEU v5.22.0)

**Nutzer-Auftrag 27.08.2026:** *„die anderen skills sollen von vorne rein sauber arbeiten,
ähnlich wie der mind cleaner — nicht immer mehr und mehr. Auch gucken: braucht man das,
kann das weg, steht das schon woanders."*

Gemessen: der **immer geladene** Kontext wuchs an EINEM Tag um **+21 %** auf 2 601 Zeilen
und 138 Anweisungen — bei einer Schwelle von ~400 Zeilen und ~100–150 Anweisungen.
`/mind-all` trägt nach, **niemand sieht zurück**; dieser Schritt schon.

⛔ **Er MELDET. Er schneidet nicht, verschiebt nicht, löscht nicht.** Handeln bleibt
`/mind-cleaner` (seit v5.159.0 autonom, Nutzer 29.10.2026 — mit Snapshot, Gates und Stopp am ersten Bruch).

**Die vollständige Vorschrift steht in
[references/bestands-pass.md](../../references/bestands-pass.md)** — Bilanz, Stichprobe, die
drei Fragen, Urteilsbuch, Quittung, Fehlerszenarien, Risiko. **Lies sie**, bevor du diesen
Schritt ausführst. Hier steht nur, was für **diesen** Skill gilt:

| | |
|---|---|
| **Bereich** | Custom-Context-Dateien und die bereichsübergreifenden Stellen |
| **`--skill`** | `mind-update` |
| **schon verdrahtet** | `cleaner_duplikate --widersprueche` |
| **neu in diesem Schritt** | `cleaner_belege` · `cleaner_aussagen --code` |

```bash
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { CLAUDE_PLUGIN_ROOT=$(jq -r '.plugins["claude-mind-manager@kohlosseum"][0].installPath // empty' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null); [ -n "$CLAUDE_PLUGIN_ROOT" ] && { CLAUDE_PLUGIN_ROOT=$(cygpath -u "$CLAUDE_PLUGIN_ROOT" 2>/dev/null || printf '%s' "$CLAUDE_PLUGIN_ROOT"); echo "WARN: CLAUDE_PLUGIN_ROOT war leer — Rueckfall auf installed_plugins.json: $CLAUDE_PLUGIN_ROOT (v5.107.0)" >&2; }; }   # v5.107.0 Rueckfall
[ -n "$CLAUDE_PLUGIN_ROOT" ] || { echo "ERROR: $CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 1; }
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer

# 1) PFLICHTZEILE — sie MUSS woertlich in den Self-Check-Block des Berichts.
#    ⛔ Nicht nur erwaehnen: die Zeile selbst, mit beiden Zahlenpaaren.
mind_kontext_bilanz "$PROJ" --vergleichen

# 1b) Art 6 (v5.90.0): ungegatete BESTANDSZAHLEN als Kandidaten — mind-update ist der
#     haeufigste Lauf, deshalb hier ueber Projekt UND ~/.claude. ⛔ Er urteilt nie, rc 0.
python "$CLAUDE_PLUGIN_ROOT/references/bestandszahlen_kandidaten.py" "$PROJ" --global

# 2) Stichprobe: 3 Einträge, die am längsten ungeprüft sind (max. 15 je Kettenlauf)
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_stichprobe.py" "$PROJ" \
       --skill mind-update --verzeichnis "$PROJ/.claude/rules"

# 3) je Eintrag die drei Fragen — siehe Referenz, EINE Berichtszeile je Eintrag

# 4) Quittung — ohne sie gilt der Lauf als Teilsync
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_stichprobe.py" "$PROJ" \
       --quittung --skill mind-update --geprueft <n> --stichprobe <n>
```

⚠ **Dieser Skill läuft als LETZTER der Kette.** Sein Laufbudget ist deshalb oft schon
von den vier davor aufgebraucht — dann ist `(nichts)` das **richtige** Ergebnis und
kein Ausfall. Die Meldung nennt den Grund (`Laufbudget erschöpft`), damit der
Unterschied im Bericht steht.

⛔ **Ein FEHLENDER Block macht den Lauf zum Teilsync.** `(nichts)` ist eine gültige
Antwort — leerer Bestand, neues Projekt, Laufbudget erschöpft. **Schweigen ist es nicht.**
Ein Skill, der schweigt weil sein Bestand sauber ist, und einer, der schweigt weil der Pass
ausfiel, sehen von außen identisch aus. Dieselbe Lehre wie v5.3.1 und die Agent-Quittung.

⚠ **Fail-open:** fehlt ein Werkzeug oder stürzt es ab, wird `UNGEPRUEFT: <werkzeug>`
gemeldet und der Skill **läuft weiter**. Ein Bestands-Pass darf nie einen Sync töten.

### ⛔ Pflichtschritt `mind_agent_bilanz` — der Aufruf (NEU v5.146.0, Etappe 56 §3)

Bis v5.145.0 stand dieser Schritt im Pflichtkasten und in der Startzeile, aber **nirgends als Aufruf** — erwartet, nie gelaufen (Noras `FEHLT: mind-rules/cleaner_duplikate`, Palvedo, 20.09.2026; Schritte wurden von Hand nachgeholt). Ihre Ausgabe ist die Zeile `Agent-Quittung:` im Self-Check-Block unten.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-update/bloecke/agent-bilanz.sh"
```

## Step 6: Report — PFLICHT-Self-Check-Block am Anfang (NEU v3.3.1)

**WICHTIG:** Der Report MUSS mit dem Self-Check-Block BEGINNEN. Jeder Marker MUSS
konkrete Beleg-Daten enthalten (Tool-Call-Refs, file:line, Agent-Findings).

**Wenn ein Marker fehlt oder `(SKIPPED)` ohne `--quick` enthaelt:** Der Skill-Run
ist BUGGY — User darf zurueckweisen mit "Self-Check-Block fehlt — bitte Steps
1.5 + 3.5 + 3e.2 ausfuehren".

### Bei QUICK_MODE=yes: Banner + SKIPPED-Markers

```
##############################################################
##  QUICK MODE ACTIVE — Knowledge-Sync wurde SKIPPED         ##
##  Du siehst nur Drift-Checks (Version, Pfade, Test-Counts) ##
##  Fuer vollen Sweep: /mind-update OHNE --quick aufrufen    ##
##############################################################

=== Context Update v3.3.2 — Self-Check ===
[Step 1.5 Custom-Context-Discovery] SKIPPED — --quick mode (User-Wahl)
[Step 3.5 Per-Bereich Knowledge-Sync] SKIPPED — --quick mode (User-Wahl)
[Step 3e.2 Rules-Inhalts-Check] SKIPPED — --quick mode (User-Wahl)
```

### Bei NORMAL MODE: PFLICHT-Format mit Belegen (anti-faking EC1)

```
=== Context Update v3.3.2 — Self-Check ===
[Step 1.5 Custom-Context-Discovery] <N> Files discovered:
  - <pfad1> (mtime: YYYY-MM-DD HH:MM, size: <X>KB)
  - <pfad2> (mtime: YYYY-MM-DD HH:MM, size: <X>KB)
  ... (oder "0 Files — Bash-find Output in Tool-Call #<N>")

[Step 3c Commit-Coverage] <B> betrachtete Commits · <K> Gaps · <U> ohne Stichwort · <Z> Grep-Ziele
  - <hash> "<subject>" — Stichwort "<key>" fehlt in <Z> Context-Dateien
  - KEIN-STICHWORT: <hash> "<subject>" — ungeprueft
  ... (oder "0 Gaps bei <B> betrachteten Commits")
  ⛔ <B> == 0 ist KEIN gutes Ergebnis, sondern eine Blindstelle — dann ausdruecklich sagen,
     dass das Gate nichts pruefen konnte (Repo ohne Conventional Commits?).
  Beleg: git-log + grep Output in Tool-Call #<N>

[Step 3.5 Per-Bereich Knowledge-Sync] 4 Agents dispatched (sequenziell/≤2 pro Welle, NIE ≥3):
  Agent-Quittung: <Ausgabe von `mind_agent_bilanz "$PROJ"`>   ⛔ PFLICHT, v5.14.0

[Step 5d Bestands-Pass v5.22.0] PFLICHT, auch bei leerem Befund
  Dauerkontext: <A> -> <B> Zeilen (<+/-D>) · Anweisungen <A> -> <B> (<+/-D>)
  Bestand: <g>/<s> geprueft · <d> Duplikat · <c> Code-Kandidat · <b> ohne Beleg · <u> UNGEPRUEFT
  ⛔ `(nichts)` ist erlaubt, FEHLEN nicht — ein fehlender Block macht den Lauf zum Teilsync
  Beleg: Bash-Tool-Call #<N>
      z.B. DISPATCH=4 ERGEBNIS=3 LEER=1 STUMM=1
             UNGEPRUEFT: rules (dispatcht, nie zurueck)
      ⛔ Rueckgabe 2 (= gar nicht dispatcht) macht diesen Step UNGEPRUEFT, nicht "sauber".
         Die Bilanz wird WOERTLICH uebernommen, nicht zusammengefasst — eine Zahl, die
         durch eine Zusammenfassung geht, ist keine Quittung mehr.
  Session-Quelle: <gerettet <pfad> (N Beitraege) | live>
  - scope=claude-md      → <A> Findings (U:<x> E:<y> A:<z> NF:<w> I:<v>)
      Beispiel-Belege: [UPDATE] CLAUDE.md:15 "v3.2.2" -> Session v3.3.0
  - scope=memory         → <B> Findings (oder "0 — MEMORY aktuell")
  - scope=rules          → TARGET_MODE=<all|targeted|unscopable|none> (aus Step 3c.1). DREI Buckets:
                           (a) voll-semantisch geprüft (klein, ganz gelesen): <liste> → <C> Findings
                           (b) gezielt-semantisch (touched + oversized >600 Z./>60 KB, grep-gezielt N Abschnitte): <liste>
                           (c) deterministisch-only (untouched ODER unscopable, nur 3e+3e.2): <liste mit Zeilenzahl>
                           → Tiefen-Audit einer großen (b/c)-Datei: /mind-rules bzw. /mind-claudemd einzeln darauf
  - scope=custom-context → <D> Findings (oder "SKIPPED: 0 Custom-Context-Files aus Step 1.5")
  Beleg: Agent-Tool-Calls #X, #Y, #Z, #W (nacheinander bzw. 2 Wellen — kein 4er-Burst),
         alle mit run_in_background: false; Quittung je Bereich per --datei (Bytes = Dateigroesse)

**Regel (v3.3.2):** Wenn Step 3c K>0 Gaps zeigt, DARF [Step 3.5] nicht "0 dispatched /
gegenstandslos" sein — die Gaps sind objektiver Gegenbeweis. "Ich kenne den Stand"
ist kein zulaessiger Eintrag hier.

[Step 3e.2 Rules-Inhalts-Check] <R> Drift-Hits in <F> Rule-Files:
  - build-process.md:17 "Last sync: v1.0.3" (Stable jetzt v1.0.5)
  - git-conventional-commits.md:94 "283 Tests gruen" (jetzt 464)
  ... (oder "0 Hits — Rules sind inhaltlich aktuell")
  Beleg: Bash-grep Output in Tool-Call #<N>
```

**Pflicht-Format jeder Marker-Zeile:** `<scope/check>` → `<count> <kind>` → `(Beleg-Quelle: <Tool-Call-Ref oder file:line>)`. Ohne Beleg ist Marker UNGUELTIG.

---

## Step 6.1: Drift-Report + Knowledge-Sync-Report (nach Self-Check-Block)

```
=== Context Update ===
Checked: N files | Drift: A auto-fixed, B need input, C by design, D dead
Knowledge-Sync: E findings (U:N E:N A:N NF:N I:N) — skipped if --quick

CLAUDE.md (project):     145 -> 138 lines (-7)
  [AUTO] Version 2.5.0 -> 2.6.0
  [AUTO] Removed dead path: src/old-module/
  [ASK]  Unreflected commit "feat: dark mode" — add to CLAUDE.md?

CLAUDE.md (global):       55 lines (OK)

MEMORY.md (project):      89 lines (OK, within 200 budget)
MEMORY topic files:       2 (lessons.md: 12, tab7-bugfixes.md: 18)

Rules (project):          3 files, all valid syntax
Rules (global):           4 files, all valid syntax

Total context: 287 lines (~2870 tokens) -- Compliance: ~92%

=== Knowledge-Sync (NEU v3.3.0, Session ↔ Custom Context) ===
Scope claude-md       (Agent 1): 2 UPDATE, 1 ENRICH
Scope memory          (Agent 2): 0 Findings
Scope rules           (Agent 3): 1 ADD ("Plan-Mode-Regel" fehlt in ~/.claude/rules/)
Scope custom-context  (Agent 4): 1 NEW_FILE-Vorschlag (backup-strategie.md)

[UPDATE]   CLAUDE.md:15 "Version 3.2.2" -> Session diskutiert v3.3.0
[ENRICH]   knowledge/best-practices.md:120 Heredoc-Section knapp -> Session hat 4 Code-Beispiele
[ADD]      Session erklaert "Self-Exclusion Pattern" — keine Custom-Context-Datei
           Vorschlag: knowledge/best-practices.md "Self-Reference Patterns" anhaengen
[NEW_FILE] backup-strategie.md (~40 Zeilen, deckt 8 Zustellplan-Patterns ab)
[INFO]     MEMORY.md 180 Zeilen — nahe 200-Limit

Want me to apply [1]? [Yes / Select / Skip]
```

**WICHTIG:** Wenn pending Findings (ASK/UPDATE/ENRICH/ADD/NEW_FILE), IMMER explizit listen
— kein "0 issues". Step 4 Klassifikation entscheidet Klasse, Step 6 zaehlt korrekt.

**Knowledge-Sync-Findings sind alle ASK-Default** (User entscheidet pro Finding):
"Want me to apply [N]? [Yes / Select / Skip]"

If `QUICK_MODE=yes`: Knowledge-Sync-Sektion komplett ueberspringen, Report endet bei
Total-Context-Zeile.

**Nach dem Bericht (v5.126.0):** den Live-Auszug dieser Sitzung wegraeumen — nur die eigene
Kennung, fremde Sitzungen bleiben unberuehrt:

```bash
# v5.146.0: eigener Bash-Aufruf — lib.sh und PROJ kommen aus frueheren Bloecken NICHT mit
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
mind_sampler_aufraeumen "$PROJ"    # loescht .claude-mind/sampler/*.<sid>.*
```

## Hard Constraints

### Identitaet: dieser Skill dispatcht IMMER (directive, v3.3.2)

**Step 1.5 (Custom-Context-Discovery) + Step 3.5 (4 Agents, sequenziell/≤2 pro Welle) + Step 3e.2 (Rules-Inhalts-Check) gehoeren zur Identitaet des Skills** (ausser `QUICK_MODE=yes`).

- Der semantische Abgleich (Step 3.5) hat **keinen Inline-Ersatz** — er laeuft NUR ueber die Agents. Inline-Reasoning ist kein Substitut.
- **"Ich kenne den Stand schon / habe es selbst geschrieben" ist KEIN gueltiger Skip-Grund.** Step 3c Commit-Coverage belegt Gaps OBJEKTIV (Commit X steht nachweislich nicht in den Context-Files). Subjektives Wissen schlaegt diese Evidenz nicht.
- Wenn Step 3c ein nicht-leeres Gap-Set liefert, MUSS Step 3.5 laufen — der Schritt ist dann nicht "gegenstandslos".
- Step 1.5 entdeckt projekt-weite Custom-Context-Files (plan.md, research.md, docs/*) via Bash-Discovery — die Files sind ohne find/grep gar nicht bekannt.
- Step 6 Self-Check-Block weist jeden Step mit Belegen aus; fehlt er, darf der User den Report zurueckweisen.

### Bei QUICK_MODE=yes (--quick Arg)

- Step 1.5 + Step 3.5 + Step 3e.2 explizit skippen
- Prominenter Banner im Report-Header (siehe Step 6)
- Self-Check-Block markiert jeden Step als `SKIPPED — --quick (User-Wahl)`

### Agent-Parallelitaets-Limit (verschaerft v4.0.1 — Anti-Burst)

- **NIE ≥3 context-analyzer gleichzeitig** (Begründung und Messungen: Step 3.5, Anti-Burst). Die 4 Step-3.5-Agents laufen SEQUENZIELL bzw.
  in 2 Wellen à 2 (max 2 pro Tool-Call); **gilt auch unter Ultracode** (stehende User-Regel,
  siehe globale Rule `workflow-agent-rate-limit.md`). **Alle 4 Bereiche bleiben Pflicht**, nur
  gestaffelt. (Früher stand hier fälschlich "MAX 4 parallel" — genau
  der brechende Burst.)
- Skills duerfen NICHT andere Skills dispatchen die ihrerseits Agents starten.
- **Parallel-Bash-Limit (NEU v3.2.2):** Skill startet MAX 2 Bash-Tools parallel,
  niemals 3+. Bei 3+ Calls: zu seriellem Aufruf wechseln ODER kombinieren via `&&`.
  Claude Code's Tool-System cancelled uebermaessige Parallelitaet (siehe Session
  2026-05-29 Log 4 Tool 5+7 `Cancelled: parallel tool call ... errored`).
- **Autonom-Modus (v5.0.0, Default):** angewendet werden AUTO · DEAD (≤5) · UPDATE · ENRICH · ADD · NEW_FILE. **NIE automatisch:** DESIGN · **>5 DEAD-Pfade** (Massenloesch-Sicherung Step 3b). Bei `--ask` gilt die alte Aufteilung (nur sichere Fixes auto, Rest fragen).
- **NEVER apply without a successful `mind_snapshot` (Step 0)** — Fehlschlag = Abbruch, keine Edits.
- **ALWAYS report every applied change** mit `file:line` + before→after; **geloeschte Pfad-Zeilen woertlich** (`Entfernt: <zeile>`) + Snapshot-Pfad + Restore-Einzeiler.
- ALWAYS show what was auto-fixed in the report
- ALWAYS show before/after line counts
- ALWAYS backup files before editing (cp to .claude-mind/backups/)
- NEVER remove content without showing what will be lost
- If no issues found: report "All clean" and stop (no unnecessary changes)

⛔ **Eine Sync-Schuld (`OPEN`) tilgt NUR `/mind-all`** — dieser Lauf nicht — auch der volle Knowledge-Sync nicht, auch nicht mit
vollständiger Quittung (`OPEN` = „in ALLE fünf Bereiche eingearbeitet", nicht „gelesen").
Am Ende des Berichts deshalb `mind_schuld_hinweis "$PROJ" || true` — Wortlaut, Messung und
Begründung: [references/bestands-pass.md](../../references/bestands-pass.md).

