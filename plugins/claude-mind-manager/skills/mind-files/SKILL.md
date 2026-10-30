---
name: mind-files
description: |
  [Mind Manager] Projekt-Setup Vollverwaltung — erkennt Projekttyp, erstellt/prueft/verbessert alle Dateien.
  Scannt Repo fuer Tech-Stack, vergleicht Ist- mit Soll-Zustand basierend auf Projekttyp
  (Python, Node.js, C#, Docs-Only, Plugin, MCP Workspace), zeigt fehlende/verbesserbare Dateien,
  erstellt AUTONOM (v5.0.0; Snapshot vorher, '--ask' fragt wie frueher). Bestehende Dateien
  werden nie ueberschrieben.

  Use when the user says "setup project", "check project files", "mind files",
  "scaffold", "init project", "bootstrap project", "check setup",
  or "/mind-files".
argument-hint: ""
context: inherit
allowed-tools: Read Glob Grep Write Bash Agent
---

# Projekt-Setup Vollverwaltung

> ⛔ **Warum ein Block so gebaut ist** (Vorfaelle, Messungen, fruehere Fassungen): lies `references/historie/mind-files.md`, BEVOR du einen Block aenderst oder wenn ein Schritt rot ist.

## ⛔ PFLICHTSCHRITTE — dieser Skill fuehrt aus, was hier steht (NEU v5.25.0)

```
PFLICHTSCHRITTE
bestandszahlen_kandidaten
cleaner_stichprobe
cleaner_tor
mind_check_tools_have_rules
mind_hook_health
mind_kontext_bilanz
mind_snapshot
verdichten
```

**Vor dem ersten Schritt, ohne Ausnahme:**

```bash
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { CLAUDE_PLUGIN_ROOT=$(jq -r '.plugins["claude-mind-manager@kohlosseum"][0].installPath // empty' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null); [ -n "$CLAUDE_PLUGIN_ROOT" ] && { CLAUDE_PLUGIN_ROOT=$(cygpath -u "$CLAUDE_PLUGIN_ROOT" 2>/dev/null || printf '%s' "$CLAUDE_PLUGIN_ROOT"); echo "WARN: CLAUDE_PLUGIN_ROOT war leer — Rueckfall auf installed_plugins.json: $CLAUDE_PLUGIN_ROOT (v5.107.0)" >&2; }; }   # v5.107.0 Rueckfall
[ -n "$CLAUDE_PLUGIN_ROOT" ] || { echo "ERROR: \$CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 1; }
export CLAUDE_PLUGIN_ROOT   # v5.163.0: sonst sehen die Bloecke sie leer (Ritas Lauf 30.10.)
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ=$(mind_projekt_wurzel)    # v5.80.0: der Ordner mit rollen.md, sonst cwd
# ⛔ v5.77.0: DIE VERSION DIESES SKILL-TEXTS. lib.sh vergleicht sie mit
#    basename "$CLAUDE_PLUGIN_ROOT" und meldet VERSIONSBRUCH, wenn ein alter
#    Text gegen neuen Code laeuft (Rita bekam am 10.09.2026 den Text aus 5.2.0).
#    ⚠ Wird beim Release nachgezogen; das Zaehl-Gate prueft alle elf.
#    ⛔ v5.125.0: DIESELBE Bash wie mind_schritt_start — sonst rc 1, keine Startzeile (Etappe 37 §3).
MIND_SKILL_VERSION="5.168.0"
mind_schritt_start "$PROJ" mind-files bestandszahlen_kandidaten cleaner_stichprobe cleaner_tor mind_check_tools_have_rules mind_hook_health mind_kontext_bilanz mind_snapshot verdichten
```

**Nach JEDEM Schritt** — auch nach einem, der entfaellt:

```bash
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ="${PROJ:-$(mind_projekt_wurzel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}")}"
mind_schritt <name> gelaufen              "$(wc -c < "$AUSGABE")" "$PROJ"
mind_schritt <name> "gelaufen:5/11"       "$BYTES" "$PROJ"   # TEILABDECKUNG
mind_schritt <name> "uebersprungen:<grund>" 0      "$PROJ"
mind_schritt <name> "fehler:<grund>"      -1       "$PROJ"
mind_schritt verdichten gelaufen --datei "$PROJ/.claude-mind/verdichten-<skill>.txt" "$PROJ"  # die 3 Zeilen von mind_verdichtung_pruefen
mind_schritt verdichten "uebersprungen:kein-kandidat" 0 "$PROJ"   # schweigen = FEHLT
```

⛔ **Selbst quittiert, NICHT nachtippen (v5.163.0):** `mind_snapshot` (Step 0) und der Bestands-Pass `mind_kontext_bilanz` · `bestandszahlen_kandidaten` · `cleaner_stichprobe` (`bloecke/pass-bestand.sh`) quittiert ihr Block mit Artefakt. Gemessen 30.10.2026: 9–10 Pflichtquittungen je Einzel-Skill von Hand.

⛔ **`uebersprungen` ist ein gueltiger Status und braucht einen GRUND.** Ein legitim entfallender Schritt (kein Git, kein Quellbaum) ist kein Fehler, gehoert aber in den Bericht.

⛔ **v5.67.0: EINEN PFLICHTSCHRITT AUSZULASSEN, WEIL ER TEUER AUSSIEHT, IST VERBOTEN.**
Nutzer-Auftrag 10.09.2026: *„die sollen alles fahren"*. ⭐ Die Trennlinie:

| | |
|---|---|
| ⛔ **verboten** | gar nicht **starten**, aus Ruecksicht auf Kontext, Zeit oder Kosten |
| ✅ **erlaubt** | starten und **scheitern lassen** — `bytes:0` faengt die Bilanz |

Ein gestarteter, gestorbener Agent ist ein **Befund**; ein nie gestarteter eine **Luecke, die wie ein Ergebnis aussieht**. ⚠ „Ressourcengrund" ist **kein** zulaessiger `uebersprungen:`-Grund. Seit v5.67.0 macht eine Teilabdeckung den Lauf zum **Teilsync**: die Schuld bleibt liegen, bis alles gefahren ist.

⭐ **`gelaufen:5/11` ist die TEILABDECKUNG.** Am 30.08.2026 lief `cleaner_leitplanke.py` ueber 5 von 11 Dateien und wurde als **Bereichspruefung** berichtet. `5/11` ist eine gueltige Antwort; sie als `11/11` zu berichten nicht.
⚠ **`X/Y` mit X=Y (`1/1`) zaehlt seit v5.113.0 als voll** — vollstaendig heisst trotzdem
`gelaufen`, nicht `1/1` (Noras Lauf 11, 16.09.2026). ⛔ **Nachquittieren geht nur im SELBEN
Block:** die Bilanz nimmt den letzten Eintrag je Block×Name; ein Nachtrag in einem spaeteren
Block heilt nichts — den Block erneut fahren (mind-all 2.96a-R).
⛔ **Eine geloeschte oder leere Schritt-Quittung wird nicht nachgetippt — der Block wird neu
gefahren** (v5.116.0, Doros Creator-Lauf 16.09.2026: 39 Schritte in 5 s nachgetippt, Bilanz 39/39).
Die Bilanz erkennt getippte Bloecke (Starts < `MIND_SCHRITT_MIN_S` = 60 s auseinander, >= 5 Schritte
in 10 s) als FORMAL, der Lauf ist teil.

⛔ **Die Bytezahl ist Pflicht, wo ein Schritt etwas ausgeben MUSS.** Am 30.08.2026
wurde die Ausgabe von `cleaner_belege.py` weggegreppt — fuer eine naive Quittung „gelaufen". `0` meldet die Bilanz als **LEER**; `-1` heisst „nicht gemessen" und zaehlt nicht.

**Im Bericht, als erste Zeile des Self-Checks:**

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/01-pflichtschritte-dieser.sh"
```

⛔ **Fehlt diese Zeile oder nennt sie `FEHLT`, ist der Bericht unvollstaendig** und
darf zurueckgewiesen werden. Rueckgabe **2 heisst: gar keine Quittung** — der Lauf
hat nie quittiert, das ist NICHT „nichts zu melden".

⚠ **Was die Quittung nicht kann:** sie erzwingt keinen Schritt (macht nur sein Fehlen sichtbar, wie `decision:block` und die Agent-Quittung) und misst nicht die GUETE: ein Werkzeug, das Unsinn liefert, quittiert als `gelaufen`.

Projekttyp erkennen -> Soll-Zustand definieren -> Ist pruefen -> User-OK -> Erstellen/Verbessern.

## Step 0: Modus + Snapshot (PFLICHT, NEU v5.0.0)

**Autonom ist der Standard.** Fehlende Dateien werden erstellt, verbesserbare verbessert.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/02-step0-modus-snapshot.sh"
```

`--ask` = Report + Freigabe (Verhalten vor v5.0.0).

**DESIGN-Befunde werden NIE automatisch angewendet** — vor einem Edit pruefen, ob eine Rule
die Stelle als "niemals anfassen"/"NIEMALS <datei>"/"by design" markiert; dann nur listen.

**Zwei Dinge bleiben AUCH autonom rueckfragepflichtig** (kein Widerspruch zur Autonomie —
beide betreffen Fremd-/Bestandsdaten, nicht Befunde):
- **Ueberschreiben existierender Dateien** (Overwrite-Guards in Step 5/5b/5c): weiter SKIP + melden.
- **Tool-Bundles** (Backup/Release-Hygiene/Versioning-Pack): installieren veraendert die
  Projekt-Struktur dauerhaft → bleibt ein Angebot, wird im Bericht als offener Punkt gelistet.

## Step 1: Projekttyp erkennen + Setup-Bereiche scannen (project-scanner)

Dispatch **project-scanner** agent (ein Dispatch — er hat Read/Glob/Grep/Bash und
deckt alle Setup-Bereiche in einem Durchgang ab; **`run_in_background: false`**, v5.94.0 —
sonst ist der `tool_result` nur ein Ack, Messung `docs/plugin/rueckkanal-messung.md`.
⭐ Turn-Limit vor dem Bericht: `SendMessage {to: <agentId>}` statt eines neuen `Agent`-Aufrufs,
im Desktop-Reiter erst `ToolSearch select:SendMessage` — v5.96.0, gemessen 12.09.2026):

```
"Scan this project for tech stack, project type, build/test/lint commands, key
directories, frameworks, and package manager. Report structured findings.

Nenne zu JEDEM Zitat die Datei und die Zeilennummer, aus der du es gelesen hast. Was du ohne Fundstelle schreibst, kennzeichne als UNGEPRUEFT.
(v5.138.0 — gilt fuer jeden Befehl, jede Version, jeden Pfad. Eine Bitte, kein Gate.)

Zusaetzlich (PFLICHT, via `test -e`/Glob konkret pruefen — Exist/Missing pro Punkt):
- BUILD:   Build-System vorhanden (package.json/pyproject.toml/*.csproj/CMakeLists...)?
           Build-Commands dokumentiert? Linter/Formatter konfiguriert (.editorconfig,
           eslint, prettier, ruff...)?
- BACKUP:  Projekt-Backup-System schon da (`tools/backup_tools.py` o.ae.)?
           `.claude-mind/backups/` Dir? `.backuprc`?
- TESTS:   Test-Infra (pytest/jest/xunit/...) + `tests/`-Dir? CI-Config (.github/workflows)?
- SECRETS: `.env`/credential-Files? `.gitignore`-Coverage ok? `.claudeignore`?
           `.claude/settings.json` mit `permissions.deny` fuer `.env*`/secrets?
- RELEASE: Git-Repo (`.git` vorhanden)? Versionierungs-Signal (`build.py` / `*.spec` /
           `pyproject.toml` mit `[project] version` / `VERSION`-Datei / `package.json` version)?
           **Python vorhanden** (`python`/`python3` im PATH ODER `.venv/`)? — noetig fuers
           Gating des Versioning-Packs (Step 5c: NUR Python-Release-App).
- DOCS:    `docs/`-Verzeichnis vorhanden? **Anzahl `.md`-Dateien** ausserhalb von
           vendor-/Beispiel-Ordnern (`node_modules`, `vendor`, `Beispiele`, `.venv`) —
           als ZAHL zurueckgeben, nicht als "viele". Python vorhanden (s. RELEASE)?
           — noetig fuers Gating des Doku-Gates (Step 5d).

Gib die 6 Bereiche als eigene Exist-vs-Missing-Sektion zurueck."
```

> **v3.3.3 (Weg B):** Die 4 frueheren `context-analyzer`-Agents (build/backup/tests/secrets) prueften nur Datei-Existenz (`test -e`) und wurden **entfernt**; der project-scanner (hat Bash) deckt die 4 Bereiche im Auftrag oben ab, ohne Abdeckungsverlust.

## Step 2: Referenzen laden

Read these reference files for templates and best practices:
- [references/templates.md](../../references/templates.md) -- 13 project type templates
- [references/claudemd-best-practices.md](../../references/claudemd-best-practices.md) -- Required sections, anti-patterns
- [references/context-file-guide.md](../../references/context-file-guide.md) -- Complete file catalog
- [references/backup-system-templates/README.md](../../references/backup-system-templates/README.md) -- Backup-System Templates (NEU v3.3.0)

## Step 3: Soll-Zustand dynamisch ableiten

Basierend auf dem Profil vom project-scanner, den Soll-Zustand ABLEITEN statt nachschlagen:

#### Claude-Dateien (fuer ALLE Projekttypen):
| Datei | Wann noetig | Inhalt |
|---|---|---|
| CLAUDE.md | IMMER | Projektuebersicht, Commands (wenn vorhanden), Konventionen |
| .claude/settings.json | Wenn sensible Dateien existieren (.env, credentials) | permissions.deny fuer Secrets |
| .claude/rules/*.md | Wenn Projekt gross genug (>10 Dateien in einer Sprache) | Sprach-/Domain-spezifische Rules |

#### Projekt-Dateien (abhaengig vom Profil):

Wenn Primary=code_app oder library:
-> Pruefe ob Build-System existiert (package.json, pyproject.toml, CMakeLists.txt, etc.)
-> Pruefe ob Tests existieren
-> Pruefe ob .gitignore existiert und vollstaendig ist
-> Pruefe ob Linter/Formatter konfiguriert ist

Wenn Primary=workspace oder +docs:
-> CLAUDE.md soll Ordner-Struktur beschreiben (was liegt wo, was ist der Zweck jedes Ordners)
-> Keine Build-Commands noetig
-> Stattdessen: Navigations-Hilfe (welcher Ordner fuer was)

Wenn Primary=scripts:
-> CLAUDE.md mit Script-Uebersicht (was macht welches Script)
-> Keine package.json/pyproject.toml noetig
-> Pruefe ob Scripts ausfuehrbar sind (chmod +x) und Shebangs haben

Wenn Primary=data:
-> CLAUDE.md mit Datenformat-Beschreibung (welche Felder, welche Formate)
-> Pruefe ob .gitignore grosse Datenfiles ausschliesst

Wenn Primary=config:
-> CLAUDE.md mit Konfigurations-Uebersicht
-> Pruefe ob Secrets in Dateien sind

Wenn Primary=plugin:
-> Pruefe plugin.json Vollstaendigkeit
-> Pruefe ob agents/, skills/, hooks/ existieren
-> CLAUDE.md soll Plugin-Architektur beschreiben

Wenn Primary=mcp:
-> Pruefe .mcp.json Validitaet
-> CLAUDE.md mit MCP-Server-Uebersicht

Wenn +hybrid:
-> Fuer jedes erkannte Sub-Profil die obigen Regeln anwenden
-> CLAUDE.md soll die verschiedenen Teile klar trennen

### Claude-Specific Files (check for all types):

| File | Purpose | Check |
|---|---|---|
| `CLAUDE.md` | Project instructions | Exists? Has build commands? Has architecture? |
| `.claude/settings.json` | Permissions | Exists? Has `permissions.deny` for sensitive patterns? |
| `.claude/rules/*.md` | Conditional rules | Any rules exist? Are they well-structured? |
| `.claudeignore` | Token savings | Exists? Covers node_modules, dist, build, etc.? |
| `.mcp.json` | MCP server config | Only for MCP-enabled projects |

### Security Best-Practice Checks:

| Check | What | Where |
|---|---|---|
| Deny .env access | `permissions.deny` includes `.env*` patterns | .claude/settings.json |
| Deny credentials | `permissions.deny` includes credential file patterns | .claude/settings.json |
| Ignore large dirs | node_modules, dist, .git, __pycache__ etc. | .claudeignore |

## Step 4: Ist-Zustand pruefen (Gap-Analyse)

For each file in the Soll-Zustand:

**If MISSING:** Add to "Create" list with:
- What would be created (preview content)
- Why it's needed
- Priority (CRITICAL / RECOMMENDED / NICE-TO-HAVE)

**If EXISTS:** Run quick best-practice check:
- CLAUDE.md: Has build commands? Architecture section? Under 200 lines?
- settings.json: Has `permissions.deny`? Denies `.env*`?
- .gitignore: Covers build artifacts for this project type?
- .claudeignore: Covers large directories?

Present findings:

```
=== Project Setup Report ===

Profile: code_app +docs +tests
Tech Stack: TypeScript, React, Vitest
Language: TypeScript (34 .ts files)

### Missing Files (3)
[1] CRITICAL    .claude/settings.json — No permission restrictions configured
    -> Will create with deny patterns for .env, credentials, secrets
[2] RECOMMENDED .claudeignore — No token savings configured
    -> Will create ignoring node_modules/, dist/, coverage/, .next/
[3] NICE-TO-HAVE .claude/rules/testing.md — No testing conventions documented
    -> Will create with paths: **/*.test.ts, **/*.spec.ts   (v5.118.0: paths: filtert, globs: laedt immer)

### Existing Files (3)
[4] OK          CLAUDE.md — 85 lines, has build commands, architecture section
[5] IMPROVE     .gitignore — Missing: coverage/, .env.local
[6] OK          package.json — Valid, has scripts

### Not Needed for this Project Type
- (none — code_app benefits from all file types)

### Summary
Create: 3 files | Improve: 1 file | OK: 2 files

Proceed? [Yes / Select / Skip]
```

Example for non-code project:

```
=== Project Setup Report ===

Profile: workspace +docs
Content: 23 .md files, 5 .txt files, 3 folders (Wissen/, Beispiele/, recherche/)
Language: Markdown (primary), keine Code-Sprache

### Missing Files (1)
[1] RECOMMENDED  CLAUDE.md — Projekt hat keine Uebersicht
    -> Will create with:
       - Ordner-Beschreibung (Wissen/ = Recherche-Dateien, Beispiele/ = Referenz-Plugins)
       - Zweck des Projekts
       - Navigation: Welcher Ordner fuer was

### Existing Files (0)

### Not Needed for this Project Type
- .gitignore (kein Build-Output)
- .claude/settings.json (keine sensiblen Dateien)
- Test-Infrastruktur (kein Code zum Testen)

### Summary
Create: 1 file | Improve: 0 files | OK: 0 files

Proceed? [Yes / Select / Skip]
```

**Nur bei `AUTO_MODE=no` (`--ask`): STOP HERE, warte auf User-Bestaetigung.**
**Bei `AUTO_MODE=yes` (Default): NICHT stoppen** — fehlende Dateien erstellen, verbesserbare
verbessern, danach Step 6 mit Angewendet-Block. **Ausgenommen bleiben** (Step 0): Ueberschreiben
existierender Dateien + Tool-Bundle-Installation → als offene Punkte listen.

## Step 5: Dateien erstellen/verbessern (nach User-OK)

For each confirmed action:

### Creating new files:

**CLAUDE.md** (if missing):
- Use template from references/templates.md matching the detected project type
- Fill with scan data (tech stack, build commands, directory structure)
- Target: 40-80 lines, max 100
- MUST pass generation checklist:
  - [ ] Has build/test commands section?
  - [ ] Has architecture/structure section?
  - [ ] Has conventions section?
  - [ ] No generic advice?
  - [ ] Under 100 lines?

**.claude/settings.json** (if missing):
```json
{
  "permissions": {
    "deny": [
      "Edit .env*",
      "Edit *credentials*",
      "Edit *secret*",
      "Edit *.pem",
      "Edit *.key"
    ]
  }
}
```

**.claudeignore** (if missing):
- Auto-detect which directories exist using `test -d`:
  node_modules/, dist/, build/, .next/, __pycache__/, target/,
  coverage/, .claude-mind/backups/, .claude-mind/sessions/
- Only include directories that actually exist

**Rule files** (if missing):
- Create with appropriate `paths:` pattern (v5.118.0 — `paths:` filtert, gemessen Zustellplan 16.09.2026; `globs:` ist das Cursor-Feld und laedt immer)
- Use MUST/NEVER/ALWAYS format
- Keep under 30 lines

### Improving existing files:

**Pre-Edit Read (MUST, v3.2.2):** **1× Read der Ziel-Datei VOR dem ersten Edit** reicht fuer N sequentielle Edits. **Re-Read nur**, wenn ein anderes Tool die Datei modifiziert. Step-4-Checks zaehlen nicht — Read im SELBEN Tool-Call-Kontext wie Edit.

Fuer NEUE Files mit Write ist KEIN Read noetig.

| Improvement | Tool | Aktion |
|---|---|---|
| Add missing .gitignore entries | Edit | Append missing patterns |
| Add permissions.deny entries | Edit | Add to existing settings.json |
| Add missing CLAUDE.md section | Edit | Insert section at appropriate position |

### Backup-System installieren (NEU v3.3.0)

Wenn der project-scanner BACKUP als `MISSING` meldet (kein `tools/backup_tools.py`)
UND User Backup-Vorschlag bestaetigt: Backup-System ins Projekt installieren.

**Vorgehen:**

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/03-backup-system.sh"   # v5.167.0: ohne --anlegen nur ANGEBOT; --anlegen erst nach Bestaetigung (--ask)
```

**Test-Cmd-Detection fuer `.backuprc`** (project-scanner-Output nutzen):

| project-scanner-Detection | `BACKUP_TEST_CMD` in `.backuprc` |
|---|---|
| `pyproject.toml` + `tests/` + pytest in deps | `pytest -q` |
| `package.json` mit `"test": "jest"` im scripts | `npm test` |
| `package.json` mit `"test": "vitest"` im scripts | `npx vitest run` |
| `package.json` mit anderem `"test"` script | `npm test` |
| `Cargo.toml` | `cargo test` |
| `go.mod` | `go test ./...` |
| `*.csproj` / `*.sln` (C# / .NET) | `dotnet test` |
| `pom.xml` (Maven) | `mvn test` |
| `build.gradle` / `build.gradle.kts` | `gradle test` |
| Sonst (kein erkanntes Build-System) | `""` (leer = skip Test-Gate, sicher) |

`.backuprc` Template:
```bash

# Test-Cmd das vor riskanten Operationen laeuft (leer = skip)
export BACKUP_TEST_CMD="<aus Detection oben>"

# Backup-Target (default OK, hier expliziert)
export BACKUP_TARGET=".claude-mind/backups"

# Test-Timeout in Sekunden (default 300 = 5 min)
export BACKUP_TEST_TIMEOUT=300
```

**5. Companion-Rule schreiben (PFLICHT — "No Dead Tools"):**

Ohne diese Rule liegen die `tools/*.py` tot im Ordner — Claude weiss nicht WANN er sie aufrufen soll (`BACKUP_USAGE.md` ist Menschen-Doku, wird nicht auto-geladen). Die Rule mit `paths:`-Frontmatter laedt, sobald Claude eine passende Datei anfasst (gemessen v5.118.0). Die Vorlage `backup-usage.md` traegt seit v5.119.0 **KEIN Feld** und laedt bei jedem Start (eine Kommentarzeile im Frontmatter sagt: Absicht); bis v5.118.0 stand dort `globs: ["**/*"]`, das Cursor-Feld, wirkungslos (Etappe 27 §1). Gleiches gilt fuer `release-hygiene.md`, `wissenstransfer-pruefen.md`, `zaehlwerte-pruefen.md`; `release-build.md` und `werkzeuge-zuerst.md` tragen `paths:`. Die Rule macht das Backup-Tool **erreichbar**.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/04-backup-system.sh"   # v5.167.0: ohne --anlegen nur ANGEBOT; --anlegen erst nach Bestaetigung (--ask)
```

Dann **1 Pointer-Zeile** in `CLAUDE.md` (via Edit, unter einem `## Tooling`/`## Backup`-Abschnitt
oder anlegen): `- Backup-System: \`tools/backup_tools.py\` + \`rollback.py\` — Nutzung siehe \`.claude/rules/backup-usage.md\``

**Edge-Cases:**
- **Existierende `tools/`-Files:** Skill checkt `test -f tools/backup_tools.py` — bei Treffer ASK "Existierende Files ueberschreiben? [Yes/Select/Skip]". Default Skip.
- **Projekt ohne Python:** Installation laeuft, aber WARN: *"Python nicht gefunden. Backup-System installiert aber NICHT lauffaehig bis Python installiert ist."*
- **Bestehende `backup_tools.py` mit anderem `__version__`:** ASK "Auf v.X updaten?". Default Skip.

**User-Output nach Installation:**
```
[OK] Backup-System installiert in $PROJ/tools/
  3 Python-Files + 1 Doku + .backupignore + .backuprc
  + .claude/rules/backup-usage.md  (Companion-Rule — macht die Tools erreichbar)
  + CLAUDE.md Pointer-Zeile

Naechste Schritte:
  source .backuprc                                       # Env-Vars laden
  python tools/backup_tools.py --help                    # CLI-Hilfe
  python tools/rollback.py list                          # Snapshots listen
  python tools/backup_tools.py gfs .claude-mind/backups  # GFS-Retention-Plan (dry-run)

Doku: docs/BACKUP_USAGE.md
```

### Step 5b: Release-Hygiene-Bundle installieren (NEU v4.0 — jedes Git-Projekt)

**Wann:** Projekt ist ein Git-Repo (`test -d .git`) **UND** hat ein Versions-Signal
(`VERSION` / `pyproject.toml` / `package.json` / `*.csproj` / Git-Tags) **UND** User bestaetigt.

⛔ **Das Versions-Signal ist seit v5.7.0 Pflicht** (vorher genuegte `test -d .git`). `update_changelog.py` erzeugt den Changelog aus **Git-Tags**; ein Repo ohne Tags bekaeme ein Dead Tool (KERN-Invariante). Gemessen 21.08.2026 im Claude-Mind-Manager-Workspace: Git-Repo, kein Remote, kein Versions-Signal — das Angebot waere gekommen.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/05-step5b-release-hygiene.sh"
```
Rule-only-Baseline fuer Commit-/Changelog-Disziplin — kein Sprach-Gate, funktioniert fuer
Node/C#/Python/etc. (Bump laeuft ueber die native Toolchain bzw. das Versioning-Pack unten).

**No-Dead-Tools:** `update_changelog.py` ist ein *Tool* -> es wird NUR mit seiner Companion-Rule
installiert, nie allein.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/06-step5b-release-hygiene.sh"   # v5.167.0: ohne --anlegen nur ANGEBOT; --anlegen erst nach Bestaetigung (--ask)
```

Dann **1 Pointer-Zeile** in `CLAUDE.md`: `- Release-Hygiene: Conventional Commits + \`python tools/update_changelog.py\` — siehe \`.claude/rules/release-hygiene.md\``

### Step 5c: Versioning-Pack installieren (NEU v4.0 — NUR Python-Release-App)

**Gating (alle drei Bedingungen aus dem project-scanner-Report, sonst NICHT anbieten):**
1. **Python vorhanden** (project-scanner meldet `python`/`python3`/`.venv`), UND
2. **Release-produzierende App** — Primary `code_app` (NICHT `library`/`workspace`/
   `scripts`/`data`/`config`/`plugin`/`mcp`). Eine PyInstaller-GUI-App faellt unter
   `code_app` (Build-System + ausfuehrbarer Code) — die project-scanner-Taxonomie kennt
   kein separates `desktop_app`. UND
3. **Build/Version-Signal** — `build.py` ODER `*.spec` ODER `pyproject.toml` (mit oder
   ohne `[project] version`) ODER eine `VERSION`-Datei. (version.py bedient VERSION,
   pyproject, package.json und *.csproj — daher hier breit.)

**Immer detect-and-OFFER, nie erzwungen.** Fehlt Python -> Pack GAR NICHT anbieten (sonst
totes Tool — genau der Bug den v4.0 killt). User bestaetigt ("notwendig").

**Companion-Rule schreiben ist PFLICHT** (No-Dead-Tools, wie Step 5) — version.py wird NIE
ohne `release-build.md` installiert:

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/07-step5c-versioning-pack.sh" "<Primary aus dem project-scanner, z. B. code_app>"   # v5.166.0: ohne Argument legt er NICHTS an   # v5.167.0: ohne --anlegen nur ANGEBOT; --anlegen erst nach Bestaetigung (--ask)
```

Dann **1 Pointer-Zeile** in `CLAUDE.md`: `- Versionierung: \`python tools/version.py show|bump|release\` — siehe \`.claude/rules/release-build.md\``

**Changelog-Kopplung:** `version.py release --changelog` ruft `tools/update_changelog.py` auf (Release-Hygiene-Bundle, Step 5b; braucht ein **Git-Repo**, Changelog aus Git-Tags). Daher **NICHT** in 5c mit-installieren (ohne Git waere es ein totes Tool). Zwei Faelle:
- **Git-Repo:** Step 5b lief bereits (gleiche Setup-Runde) -> `--changelog` funktioniert.
- **Kein Git-Repo:** `version.py release` ohne `--changelog` nutzen. Wird `--changelog` doch
  gesetzt und das Tool fehlt, **degradiert version.py sauber**: WARN "update_changelog.py nicht
  gefunden - Changelog uebersprungen", der Bump/Tag laeuft normal durch (kein Abbruch).

### Step 5d: Doku-Gate installieren (NEU v5.3.0 — Projekte mit nennenswerter Doku)

**Wozu:** `coverage_gate.py` beantwortet „ist beim Uebertragen alles angekommen?" **messend statt schaetzend** (Quellen + Zieldokument rein, belegte Pruefpunkte raus), sobald Wissen aus mehreren Dateien in ein Dokument wandert.

**Gating (alle Bedingungen aus dem project-scanner-Report, sonst NICHT anbieten):**
1. **Python vorhanden** (`python`/`python3`/`.venv` — Bereich RELEASE/DOCS), UND
2. **nennenswerte Doku-Flaeche**: `docs/`-Verzeichnis existiert **ODER** ≥ 10 `.md`-Dateien
   ausserhalb vendor-/Beispiel-Ordnern (Bereich DOCS).

Fehlt Python -> **gar nicht anbieten** (totes Tool, genau der Fall den v4.0 abgeschafft hat).
Unter 10 Markdown-Dateien und ohne `docs/` gibt es schlicht nichts zu messen — dann **INFO**
statt Angebot: *"zu wenig Doku-Flaeche, das Gate haette hier keinen Gegenstand"*.

**Immer detect-and-OFFER, nie erzwungen.** User bestaetigt.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/08-step5d-doku-gate.sh"   # v5.167.0: ohne --anlegen nur ANGEBOT; --anlegen erst nach Bestaetigung (--ask)
```

Dann **1 Pointer-Zeile** in `CLAUDE.md`: `- Wissenstransfer messen: \`python tools/coverage_gate.py <ziel.md> <quelle...>\` — siehe \`.claude/rules/wissenstransfer-pruefen.md\``

⚠ **Was im Angebot dazugesagt werden MUSS** (sonst wird das Gate ueberschaetzt): es misst
**Erwaehnung, nicht inhaltliche Treue**, und die **absolute Prozentzahl ist wertlos** — nur der
Zuwachs zwischen Vorher- und Nachher-Stand traegt eine Aussage. Beides steht in der Rule; wer
das Bundle anbietet, nennt es auch im Report.

### Step 5e: Zaehl-Gate installieren (NEU v5.11.0 — Projekte mit Zahlen in der Doku)

**Wozu:** Eine behauptete **Anzahl** (`7 Hooks`, `12 Referenzen`, `84 Prueffaelle`) veraltet lautlos und wird geglaubt, **gerade weil** sie praezise aussieht. `zaehl_gate.py` liest eine Tabelle mit Zaehlbefehl je Zahl, fuehrt die Befehle aus und vergleicht.

⛔ **Beleg ist das Plugin selbst:** seine Tabelle fuehrte **seit v5.2.2** Zaehlbefehle mit und war trotzdem **sechsmal** falsch (`lib.sh` 7 -> 12 -> 13 -> 16 -> 17 -> 22; `.py` 2, dann 5, tatsaechlich 8; Skills 8 statt 9). Die Datei notierte selbst: *"Eine Lehre aufzuschreiben verhindert ihren Wiedereintritt nicht — nur ein Check tut das. Hier waere er billig."* Gebaut hatte ihn niemand. **Zwischen "wir wissen es" und "es kann nicht mehr passieren" liegt ein ausfuehrbares Skript, sonst nichts.**

**Gating (alle Bedingungen, sonst NICHT anbieten):**
1. **Python vorhanden** (`python`/`python3`/`.venv` — Bereich RELEASE/DOCS), UND
2. **es gibt ueberhaupt Zahlen zu pruefen**: mindestens **3** Vorkommen der Form
   `\b\d+\b` in `CLAUDE.md` oder unter `.claude/rules/`, die eine Anzahl bezeichnen.

Fehlt Python -> **gar nicht anbieten** (totes Tool, genau der Fall den v4.0 abgeschafft
hat). Unter 3 Zahlen: **INFO** statt Angebot — *"zu wenige Zahlen, das Gate haette hier
keinen Gegenstand"*.

**Immer detect-and-OFFER, nie erzwungen.** User bestaetigt.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/09-step5e-zaehl-gate.sh"   # v5.167.0: ohne --anlegen nur ANGEBOT; --anlegen erst nach Bestaetigung (--ask)
```

**Danach im Bericht nennen**, samt erstem Lauf (sonst weiss niemand, ob die Zahlen stimmen):

```bash
python tools/zaehl_gate.py .claude/rules/<datei-mit-der-tabelle>.md
```

⚠ **Findet das Gate keine Zeilen, meldet es Rueckgabewert 2 — kein erfundenes Ergebnis.** Normalfall, wenn die Tabelle noch fehlt; dann gehoert in den Bericht, **welche** Zahlen dafuer in Frage kaemen.

## Step 5d: ⛔ Das Kontext-Tor — PFLICHT vor jedem `ADD` (NEU v5.26.0)

**Nutzer-Auftrag 30.08.2026:** *„überall es wird immer mehr, es darf nicht sein
— führe was ein wo der Context durch läuft: ist es irgendwo schon, ist es
selbsterklärend, ist es im Code schon erklärt. … in den Context-Dateien soll
kein unwichtiger Müll stehen, er ist begrenzt, wertvoll und kostet Geld."*

Bis v5.25.0 arbeitete dieser Command nur **rückwärts**; **es gab kein Tor beim Hineinschreiben.** Deshalb wuchs alles.

**Die vollständige Vorschrift (Pruefliste A1–D10, beide Richtungen, Quittung, Grenzen) steht in
[references/kontext-tor.md](../../references/kontext-tor.md)** — **lies sie** vor diesem Schritt. Hier nur, was für **diesen** Command gilt:

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

python "$CLAUDE_PLUGIN_ROOT/references/cleaner_einordnung.py" --wohin "$PROJ/CLAUDE.md"
```

## ⛔ D1 — die neunte Frage: WOHIN gehoert diese Aussage?

**Die Pruefliste oben prueft, OB etwas hinein darf; B4 nur, wie OFT es gebraucht wird. WOHIN genau, sagt D1.**
B3 prueft nur am **schon gewaehlten** Ort — ein Tuersteher, kein Wegweiser; wer durchkommt, landet meist in einer immer-ladenden Datei.

| Klasse | wann man es braucht | Ort |
|---|---|---|
| **BREMSE** | bevor man merkt, dass man nachschlagen sollte | muss **immer** laden |
| **ANLEITUNG** | waehrend der Arbeit | **Command + Dateipfad** (Doppelzeiger) |
| **BELEG** | nur wenn jemand die Regel anzweifelt | Archiv oder `docs/`, laedt nie |
| **UNBESTIMMT** | kein Formmerkmal greift | ⛔ **Ort bleibt, wo er war** |

⛔ **D1 MELDET, es entscheidet nicht.** Formmerkmale liefern **Kandidaten** (Doktrin wie `cleaner_leitplanke.py`, `art()` in `debug_auswertung.py`). Ist BREMSE gegen ANLEITUNG nicht eindeutig, kommt **UNBESTIMMT** und der Ort **bleibt unveraendert**. Die wahrscheinlichere Zelle zu raten ist verboten: eine geratene Zuordnung wird spaeter zitiert.

⭐ **Der haeufigste echte Fall ist TEILBAR** — ein Absatz mit einer Bremse UND
ihrem Beleg. Dann geht der Beleg ins Archiv und die Bremse bleibt.

⚠ **Bekannte Schwaeche:** „wann brauche ich es" ist eine Aussage ueber den **Leser**; gemessen 07.09.2026 brauchte der Manager `hooks.md` 8x und `architecture.md` 7x, obwohl sie nach der Rollentabelle dem Arbeiter gehoeren. Mechanisch entscheidbar? **UNGEMESSEN**.

⛔ **Die Quittung wird um `D1` erweitert** (sonst nicht unterscheidbar, ob D1 nichts fand oder nicht lief):

```
tor=<datei>:A1/A2/A3:B4/B5/B6:C7/C8/C9:D10:D1=<bremse>/<anleitung>/<beleg>/<unbestimmt>
```


⛔ **Die Quittung MUSS in den Self-Check-Block des Berichts**, eine Zeile je
`ADD`. Fehlt sie, ist der Lauf ein **Teilsync** (wie Bestands-Pass v5.22.0, Schritt-Quittung v5.25.0).

```
tor=<datei>:A1/A2/A3:B4/B5/B6:C7/C8/C9:D10
```

⛔ **A1 (Code, andere Datei), B4, C8 und D10 beantwortet `cleaner_tor` NICHT — es nennt sie.** Dafür gibt es
`cleaner_duplikate`, `cleaner_aussagen --code` und `cleaner_grenzen`. `instrument-nachgebaut`: 7 Vorkommen im Debug-Ordner, **kein Nachbau war besser als das Original** (`werkzeuge-zuerst.md`).

⚠ **A1, A2, A3, B6, C7b und C9 bleiben Urteile.** Das Tor erzwingt eine **Antwort**, nicht die
richtige — wie die Agent-Quittung (v5.19.0), die nur das Fehlen sichtbar macht.


## Step 5e: Der Roster — anbieten und pruefen (NEU v5.46.0)

Ein Projekt, in dem **mehrere Sitzungen** arbeiten, braucht `.claude/rules/rollen.md`.
Ohne ihn wirkt `~/.claude/rules/manager-chats.md` nicht (*„Ohne Roster gilt nichts davon."*).

### ⛔ Das Gate — gemessen am 09.09.2026, nicht geraten

| Kandidat | trennt er? |
|---|---|
| Sitzungen mit **ueberlappenden Laufzeitfenstern** | 9 von 22 Projekten |
| schlicht **>= 2 Sitzungen** je Projekt | **9 von 22 Projekten** |

⭐ **Beide liefern DIESELBE Menge.** **Also gilt das einfache Merkmal** — ein aufwendiges Instrument, das dasselbe misst wie ein triviales, ist eine Last.

⚠ **Die Kandidaten aus dem Auftrag taugen alle nicht:** `.claude-mind/sessions/`, verschiedene `session_id` im Hook-Zaehler und mehrere `OPEN.seen-<sid>` zaehlen Sitzungen **ueber die Zeit**; ein Projekt mit seit Maerz woechentlich neuer Sitzung saehe aus wie ein Manager-Aufbau.

⛔ **Die Messung hatte einen Fehler, der sie fast unbrauchbar gemacht haette:** die erste Fassung las nur den **ersten** Datensatz je Transkript (ohne Zeitstempel); von 15 Transkripten wurde eines gewertet, und **dieses** Projekt meldete *„1 Sitzung, 0 gleichzeitig"* bei drei laufenden Sitzungen. Gefunden nur am bekannt wahren Fall.

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/10-das-gate.sh"
```

**Angeboten wird, wenn `_N >= 2` UND `.claude/rules/rollen.md` fehlt.**
⛔ **Nie erzwungen** — Muster wie Step 5c: erkennen, anbieten, der Nutzer entscheidet.

### Das Geruest wird NICHT entworfen — es steht schon

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/11-das-geruest.sh"
```

⛔ **Verbindlich ist Joplin `🧭 Manager-Chats` §10a** (ID
`6e27ab4e46f94884b88f56a1e7c46f27`): Abschnittsfolge, Ueberschriften, **vier Saetze, die
woertlich stehen muessen**. Der Skill baut **genau** dieses Geruest. Sonst gaebe es zwei
Wahrheiten (Kopiervorlage vs. `/mind-files`).

⛔ **LEERE NAMEN BLEIBEN LEER.** Namen vergibt der Nutzer. Ein erfundener Name ist
schlimmer als eine Luecke: die Adressierung trifft ins Leere, erst beim Senden bemerkt.

⛔ **Die Eigentuemer-Tabelle kommt aus dem TATSAECHLICHEN Bestand**, nie aus einer festen
Liste — und `~/.claude/projects/<slug>/memory/` steht immer drin (liegt **ausserhalb** des Projektordners, sonst Streitfall).

⭐ **Unterordner-Aufbau (v5.92.0, §10a Stand 11.09.2026):** liegt in der Wurzel ein
Unterordner mit eigenem `.claude/`, `.claude-mind/` oder `CLAUDE.md`, traegt die
Rollentabelle eine **fuenfte Spalte `Ordner`** (relativ zur Wurzel, `Creator Stimme/`) —
dort Pflicht, sonst weiss weder Sync noch Manager, wo eine Sitzung lebt. Ohne solche
Unterordner bleibt es bei vier Spalten. `--pruefe` nimmt beide Formen: fuenf Spalten ohne
Aufbau sind ein Hinweis, ein Aufbau ohne Spalte `Ordner` ist rot, ein eingetragener Ordner,
den es nicht gibt, ebenfalls (Ausfuellfehler 1).
⛔ **Spalte 3 ist die BLANKE UUID** (`$CLAUDE_CODE_SESSION_ID`), nie `local_…` — das Geruest
schreibt seit v5.92.0 `<uuid>` vor, und `--pruefe` meldet die `local_…`-Form: das Rollen-Gate
vergleicht mit der blanken Kennung und faende diese Sitzung nie (gemessen 10.09.2026).

### Pruefung 8: Abschnittsfolge (`--pruefe`)

| | |
|---|---|
| Abschnitt **weggelassen** | Hinweis — was es nicht gibt, faellt weg |
| Abschnitt **ergaenzt**, Geruest sonst vollstaendig | Hinweis — *„was NUR hier gilt"* gehoert hinein |
| Abschnitt **umbenannt** oder **umgestellt** | **BEFUND**, rc 1 |
| ein **Pflichtsatz** fehlt | **BEFUND**, rc 1 |

⭐ **Umbenannt und ergaenzt sehen von aussen gleich aus.** Unterschieden wird mechanisch
nur daran, ob dafuer ein Pflichtabschnitt **fehlt**: fehlt einer, ist der fremde
verdaechtig; fehlt keiner, ist er eine Zugabe.

⚠ **Umlaute sind tolerant, alles andere nicht.** `gehoert` und `gehört` gelten als
dieselbe Ueberschrift; die erste Fassung meldete die ASCII-geschriebene `rollen.md` dieses Projekts als *„umbenannt"* (Fehlalarm in jedem ASCII-Projekt).

### ⛔ Was NICHT mechanisch geht — und deshalb im Bericht dazugesagt wird

Ob der **Zuschnitt** der Rollen sinnvoll ist · ob die **Namen** zu den laufenden
Sitzungen passen · ob sich jemand an den Roster **haelt**. Der Bericht nennt diese drei,
sonst liest sich ein gruener Lauf wie eine Zusicherung, die er nicht ist.

## Step 5f: ⛔ Der Bestands-Pass — PFLICHT, auch bei leerem Befund (NEU v5.22.0)

**Nutzer-Auftrag 27.08.2026:** *„die anderen skills sollen von vorne rein sauber arbeiten,
ähnlich wie der mind cleaner — nicht immer mehr und mehr. Auch gucken: braucht man das,
kann das weg, steht das schon woanders."*

Gemessen: der **immer geladene** Kontext wuchs an EINEM Tag um **+21 %** auf 2 601 Zeilen
und 138 Anweisungen — bei einer Schwelle von ~400 Zeilen und ~100–150 Anweisungen.
`/mind-all` trägt nach, **niemand sieht zurück**. Dieser Schritt sieht zurück.

⛔ **Er MELDET. Er schneidet nicht, verschiebt nicht, löscht nicht.** Handeln bleibt
`/mind-cleaner` (seit v5.159.0 autonom, Nutzer 29.10.2026 — mit Snapshot, Gates und Stopp am ersten Bruch).

**Die vollständige Vorschrift (Bilanz, Stichprobe, drei Fragen, Urteilsbuch, Quittung, Fehlerszenarien, Risiko) steht in
[references/bestands-pass.md](../../references/bestands-pass.md)** — **lies sie** vor diesem Schritt. Hier nur, was für **diesen** Skill gilt:

| | |
|---|---|
| **Bereich** | die von diesem Skill **installierten Werkzeuge** unter `tools/` samt ihrer Companion-Rules |
| **`--skill`** | `mind-files` |
| **schon verdrahtet** | ⛔ **nichts** — dieser Skill hatte bisher keinen einzigen Cleaner-Aufruf |
| **neu in diesem Schritt** | **alles**, mit Schwerpunkt auf **toten Werkzeugen** |

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/pass-bestand.sh"
# Teil 1+2: mind_kontext_bilanz --vergleichen (PFLICHTZEILE woertlich in den Self-Check-Block), bestandszahlen_kandidaten,
#           cleaner_stichprobe — der Block quittiert alle drei SELBST mit Artefakt (v5.163.0). NICHT nachtippen.
# ⛔ Teil 3+4 bleiben PFLICHT (v5.164.0): die drei Fragen je PRUEFEN-Eintrag, dann `cleaner_stichprobe.py --quittung`
#   (unten) — die letzte Zeile des Blocks nennt den Aufruf mit der Stichprobenzahl. Ohne sie fehlt bestand=, der Lauf bleibt teil.
```

```bash
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { CLAUDE_PLUGIN_ROOT=$(jq -r '.plugins["claude-mind-manager@kohlosseum"][0].installPath // empty' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null); [ -n "$CLAUDE_PLUGIN_ROOT" ] && { CLAUDE_PLUGIN_ROOT=$(cygpath -u "$CLAUDE_PLUGIN_ROOT" 2>/dev/null || printf '%s' "$CLAUDE_PLUGIN_ROOT"); echo "WARN: CLAUDE_PLUGIN_ROOT war leer — Rueckfall auf installed_plugins.json: $CLAUDE_PLUGIN_ROOT (v5.107.0)" >&2; }; }   # v5.107.0 Rueckfall
[ -n "$CLAUDE_PLUGIN_ROOT" ] || { echo "ERROR: $CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 1; }
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
# 3) je Eintrag die drei Fragen — siehe Referenz, EINE Berichtszeile je Eintrag

# 4) Quittung — ohne sie gilt der Lauf als Teilsync
python "$CLAUDE_PLUGIN_ROOT/references/cleaner_stichprobe.py" "$PROJ" \
       --quittung --skill mind-files --geprueft <n> --stichprobe <n>
```

⭐ **Der Bestand dieses Skills ist ein anderer als bei den übrigen vier:** er hat die
Werkzeuge *installiert*, also fragt er als einziger sinnvoll: **wird das überhaupt
noch benutzt?** `cleaner_belege` misst genau das — Belege statt Selbsteinschätzung.

⛔ **Die Kern-Invariante bleibt unberührt:** kein Werkzeug ohne glob-getriggerte
Companion-Rule. Der Pass darf eine Rule **melden**, nie entfernen — sonst entstünde
ein totes Werkzeug.

⛔ **Ein FEHLENDER Block macht den Lauf zum Teilsync.** `(nichts)` ist eine gültige
Antwort — leerer Bestand, neues Projekt, Laufbudget erschöpft. **Schweigen ist es nicht**:
sauberer Bestand und ausgefallener Pass sehen von außen identisch aus (Lehre wie v5.3.1, Agent-Quittung).

⚠ **Fail-open:** fehlt ein Werkzeug oder stürzt es ab, wird `UNGEPRUEFT: <werkzeug>`
gemeldet und der Skill **läuft weiter**. Ein Bestands-Pass darf nie einen Sync töten.

## Step 5g: ⭐ VERDICHTEN — die größte Companion-Rule (NEU v5.91.0)

Fünfter und letzter Träger — damit tragen alle fünf Context-Skills Verdichten und Lister
(ZIEL 4). `mind-files` kürzt nur, was es selbst anlegt: die **Companion-Rules** seiner Werkzeuge
(`backup-usage.md`, `wissenstransfer-pruefen.md`, `zaehlwerte-pruefen.md`, `release-hygiene.md`,
`release-build.md`). Alles andere unter `rules/` gehört `mind-rules` Step 9b.

**Die vollständige Vorschrift — Agent, Kasten, Gate, Stufe 3, Bericht — steht in
[references/bestands-pass.md](../../references/bestands-pass.md), Abschnitt „VERDICHTEN“.
Lies sie.** Hier nur, was für diesen Skill gilt:

| | |
|---|---|
| **Kandidat** | die **GRÖSSTE** der installierten Companion-Rules in Bytes, **die in den letzten N Läufen nicht Kandidatin war** — **eine je Lauf** (v5.138.0, `mind_verdicht_kandidat`; N = `Dateizahl − 1`, Regler `MIND_VERDICHTEN_HISTORIE`) |
| ⛔ **welche Zeilen liest ein Programm** | `mind_check_tools_have_rules` verlangt je Werkzeug die **Aufrufform** `tools/<name>` in einer glob-getriggerten Rule (Kern-Invariante v4.0) — jede Zeile mit `tools/<name>.py` und das `globs:`-Frontmatter bleiben byteweise. **Nach dem Lauf `mind_check_tools_have_rules "$PROJ"` — rc 0 oder VERWERFEN**, sonst liegt ein Werkzeug tot |
| **Überholt-Kandidaten** | aus dem Vergleich mit der Vorlage in `references/backup-system-templates/` (was die Vorlage nicht mehr sagt) und aus dem Deckel-Ausweis der Datei — **benannt** |
| **verwerfen, wenn** | Stufe 1 < 100 % · Marker unbenannt verloren · nicht kleiner · Zeilenenden geändert · `mind_check_tools_have_rules` neu rot · Dauerkontext nach dem Anwenden nicht kleiner |
| ⛔ **Stufe 3** | der Wort-Diff wird GANZ gelesen, bevor angewendet wird. **Ohne Leser: nicht anwenden** — Ergebnis, Bericht, Diff ablegen, Pfad melden |

```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/12-step5g-verdichten-die.sh"
```

⛔ **Der Bericht dieses Schritts sind die drei Zeilen aus `mind_verdichtung_pruefen`** plus
`Tool->Rule-Nachweis nachher: PASS` — oder `verworfen: <grund>`. **Kein Bericht = der Schritt lief nicht.**

## Step 6: Report — PFLICHT-Self-Check-Block am Anfang (v4.0)

**WICHTIG:** Report MUSS mit Self-Check-Block BEGINNEN. Jeder Marker mit konkreten Belegen.

**Wenn der Marker fehlt oder `(SKIPPED)` enthaelt ohne explizite Begruendung:**
User darf zurueckweisen mit "Self-Check-Block fehlt — bitte Step 1 ausfuehren".

```
=== Project Setup Report v4.0 — Self-Check ===
[Step 1 project-scanner] Profile: <z.B. code_app +docs +tests>
  Tech-Stack: <z.B. Python 3.11, pyproject.toml, pytest>
  Setup-Bereiche (vom project-scanner via test -e/Glob gescannt):
  - BUILD   → <Exist/Missing + Kurzbefund>
  - BACKUP  → <Exist/Missing>
  - TESTS   → <Exist/Missing>
  - SECRETS → <Exist/Missing>
  - RELEASE → <Git? Versions-Signal? Python? — entscheidet Pack-Angebot>
  - DOCS    → <`docs/`? Anzahl .md ausserhalb vendor? Python? — entscheidet Doku-Gate (5d)>
  No-Dead-Tools-Nachweis — GEMESSEN, nicht behauptet (v5.2.1):
  <woertliche Ausgabe von mind_check_tools_have_rules, eine Zeile je Tool>
  Beleg: project-scanner Agent Tool-Call #<N>
[Step 5f Bestands-Pass v5.22.0] PFLICHT, auch bei leerem Befund
  Dauerkontext: <A> -> <B> Zeilen (<+/-D>) · Anweisungen <A> -> <B> (<+/-D>)
  Bestand: <g>/<s> geprueft · <d> Duplikat · <c> Code-Kandidat · <b> ohne Beleg · <u> UNGEPRUEFT
  ⛔ `(nichts)` ist erlaubt, FEHLEN nicht — ein fehlender Block macht den Lauf zum Teilsync
  Beleg: Bash-Tool-Call #<N>
```

**Der Nachweis wird AUSGEFUEHRT, nicht aufgeschrieben (NEU v5.2.1):**
```bash
ARGUMENTS='$ARGUMENTS' bash "$CLAUDE_PLUGIN_ROOT/skills/mind-files/bloecke/13-step6-report-pflicht.sh"
```
⛔ **Die Zeile `Angelegt:` im Bericht nennt GENAU die Liste, die dieser Block ausgibt (v5.166.0).** Die Bloecke 03–09 pruefen ihre Bedingung selbst und legen nur ueber `mind_vorlage_anlegen` an. Im A/B-Lauf vom 30.10.2026 wurden 6 Dateien angelegt und „Keine Dateien angelegt“ berichtet.
⚠ **`mind_ordner_hinweise` ist ein Hinweis, kein Befund** (Etappe 38 §7, gemessen 19.09.2026:
2 783 ungenannte Skripte in vier Projekten, 0 tote Werkzeuge — `docs/plugin/tools-have-rules-messung-20260919.md`).
Die Invariante bleibt bei der Nennungs-Regel; der Hinweis nennt nur Ordner, die kein Satz in
`CLAUDE.md`/Rules erwaehnt (`MIND_ORDNER_HINWEIS_AB`, Vorgabe 5). Er erzeugt keine Debug-Zeile und kein FAIL.
Die **woertliche Ausgabe** kommt in den Block — nicht paraphrasiert, nicht gekuerzt. Bei
`TOOLCHECK_RC=1` MUSS der Report das als **verletzte Invariante** ausweisen und die fehlende
Rule nachtragen.

**Warum das den alten Prosa-Block ersetzt:** Bis v5.2.0 fuellte der Skill die Tabelle selbst aus — eine Behauptung ueber die eigene Arbeit (gemeldet 2026-08-16: „Self-Check-Block nicht durchsetzbar"). `mind_check_tools_have_rules`
prueft stattdessen am Dateisystem: Nennt eine `.claude/rules/*.md` das Tool **namentlich**, und
traegt sie `paths:` (bei Beruehrung) oder `globs:`/kein Feld (laedt immer)? Die Pruefung kann scheitern —
ein Tool ohne Rule ergibt nachweislich `FAIL`.

> ⚠ **Was sie NICHT belegt:** dass die Rule je gelesen oder befolgt wird. Gemessen wird die
> **Erreichbarkeit**, nicht die Wirkung. Dieser Rest bleibt Prosa und wird nicht als mehr
> ausgegeben, als er ist.

**Pflicht-Format:** Profile + alle 6 Setup-Bereiche mit Exist/Missing + die **ausgefuehrte**
Nachweis-Ausgabe + `(Beleg: project-scanner Tool-Call #<N>)`.

---

## Step 6.1: Summary (nach Self-Check-Block)

```
=== Project Setup Complete ===
Created: 3 files (settings.json, .claudeignore, testing.md)
Improved: 1 file (.gitignore: +2 patterns)
Already OK: 2 files
Project readiness: Good (all critical files present)
```

## Hard Constraints

- **NEVER overwrite existing files without user confirmation** — gilt WEITER auch im Autonom-Modus (v5.0.0). Autonomie heißt: fehlende Dateien anlegen + eigene Befunde anwenden — NICHT fremden Bestand überschreiben. Overwrite-Guards (Step 5/5b/5c) bleiben aktiv: SKIP + melden.
- **NEVER apply without a successful `mind_snapshot` (Step 0)** — Snapshot fehlgeschlagen = keine Edits, Abbruch.
- **ALWAYS report every created/changed file** + Snapshot-Pfad + Restore-Einzeiler; Tool-Bundles bleiben Angebot (Step 0).
- NEVER create files without showing preview content first
- ALWAYS show what would be created/changed before doing it
- ALWAYS use Write for new files, Edit for modifications
- ALWAYS check if directories exist before creating files in them (mkdir -p if needed)
- For CLAUDE.md generation: ALWAYS use project-scanner results, NEVER guess
- For settings.json: ALWAYS include .env* in deny patterns (security baseline)
- NEVER include secrets, API keys, or credentials in any generated file
- **Ein Agent-Dispatch (v3.3.3):** NUR project-scanner (Step 1) deckt Typ-Erkennung + alle 4 Setup-Bereiche (build/backup/tests/secrets) in EINEM Durchgang ab. Die 4 frueheren context-analyzer-Agents (Step 1.5) waren Redundanz und sind entfernt.
- **Backup-System Direktive H (v5.0.0 typ-gated, Befund 8):** Vorschlag nur bei Primary
  `code_app`/`library`/`plugin`/`mcp`/`scripts`. Bei **`workspace`/`docs`/`data`/`config`**
  NICHT anbieten, sondern **INFO**: "reiner Doku-/Datenordner — PreCompact-Hook + globale
  Backups decken das ab; Python-Tools waeren hier totes Gewicht". Zusaetzlich: enthaelt die
  Projekt-CLAUDE.md eine Abhaengigkeits-/Tool-Sperre (z.B. "zero dependencies", "keine
  Fremd-Tools"), **melden statt vorschlagen**. Grund: ein nie genutztes Tool im Ordner ist der Dead-Tool-Fall, den v4.0 abgeschafft hat.
- **Templates plugin-unabhaengig:** Nach Installation kein Plugin-Bezug — Tools laufen autonom im Projekt. Keine Hardcodes von Plugin-Pfaden in den installierten Files (Direktive C)
- **Python-Detection vor Backup-Installation:** Wenn `python --version` UND `python3 --version` fehlschlagen: Installation laeuft trotzdem (User-OK gegeben) ABER mit WARN "nicht lauffaehig bis Python da ist"
- **"No Dead Tools"-Invariante (NEU v4.0, KERN):** JEDES Tool das dieser Skill ins Projekt installiert (`tools/backup_tools.py`, `tools/rollback.py`, `tools/mutation_guard.py`, `tools/update_changelog.py`, `tools/version.py`, `tools/coverage_gate.py`) MUSS zusammen mit einer glob-getriggerten Companion-`.claude/rules/*.md` installiert werden, die Claude sagt WANN + WIE er's nutzt + 1 Pointer-Zeile in CLAUDE.md. **Kein Tool-Install ohne Rule** — sonst liegt das Tool tot im Ordner (`docs/*.md` ist Menschen-Doku, wird nicht auto-geladen). Ehrlich: die Rule macht das Tool *erreichbar*, nicht garantiert-genutzt (Prosa-Enforcement) — aber totes `.py` -> geladene Anweisung ist eine echte Verbesserung.
- **Versioning-Pack-Gating (NEU v4.0):** `version.py` + `release-build.md` NUR bei Python + Release-App (Primary `code_app`) + Build/Version-Signal anbieten. **Nie wo Python fehlt** — sonst waere version.py selbst ein totes Tool. Immer OFFER, nie erzwungen.
- **update_changelog.py-Ownership (NEU v4.0):** gehoert ins Release-Hygiene-Bundle (Step 5b, `test -d .git`), NICHT ins Backup-Bundle. Nie ohne `release-hygiene.md`.
- **Doku-Gate-Gating (NEU v5.3.0):** `coverage_gate.py` + `wissenstransfer-pruefen.md` NUR bei **Python vorhanden** UND (`docs/` existiert ODER ≥10 `.md` ausserhalb vendor-Ordnern). **Nie wo Python fehlt** — sonst waere das Gate selbst ein totes Tool. Zu wenig Doku-Flaeche → INFO statt Angebot, nicht stillschweigend installieren. Immer OFFER, nie erzwungen. **Und im Angebot dazusagen, was es NICHT kann:** es misst Erwaehnung statt inhaltlicher Treue, und die absolute Prozentzahl ist wertlos (gemessen: 43 % gegen einen Stand, in dem das Material nachweislich fehlte) — nur der Zuwachs traegt eine Aussage.

⛔ **Eine Sync-Schuld (`OPEN`) tilgt NUR `/mind-all`** — dieser Lauf nicht, auch nicht mit
vollständiger Quittung (`OPEN` = „in ALLE fünf Bereiche eingearbeitet", nicht „gelesen").
Am Ende des Berichts deshalb `mind_schuld_hinweis "$PROJ" || true` — Wortlaut, Messung und
Begründung: [references/bestands-pass.md](../../references/bestands-pass.md).
