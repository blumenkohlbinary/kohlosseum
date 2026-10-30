#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# mind-files: was die Install-Bloecke anlegen, ist genau das, was gemeldet wird (v5.166.0, Etappe 65 Nachtrag 1 (b)).
#
# ⛔ Gemessen im A/B-Lauf vom 30.10.2026 (5.165.0, eingefrorene Kopie dieses Workspace): mind-files legte
#    tools/{update_changelog,version,zaehl_gate}.py und .claude/rules/{release-build,release-hygiene,zaehlwerte-pruefen}.md
#    an und berichtete „Keine Dateien angelegt“. Ursache: seit Hebel B (5.154.0) kopierten die Bloecke 03–09
#    bedingungslos — das Gating (Versions-Signal, code_app, Python, Zahlen) stand nur im SKILL-Text, und
#    HAT_VERSION aus Block 05 war in Block 06 leer (Prozessgrenze). 5.151.0 legte hier nichts an.
# Gegen 5.165.0 sind Abschnitt 1 und 3 rot.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$R"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
B="$R/skills/mind-files/bloecke"
dateien() { ( cd "$1" && find . -type f -not -path './.claude-mind/*' -not -path './.git/*' | sed 's#^\./##' | sort ); }
fahre() {  # <projekt> [argumente fuer die Bloecke]
  local p="$1" b; shift
  for b in 03-backup-system 04-backup-system 05-step5b-release-hygiene 06-step5b-release-hygiene \
           07-step5c-versioning-pack 08-step5d-doku-gate 09-step5e-zaehl-gate; do
    ( cd "$p" && env -u PROJ -u LAUF CLAUDE_PROJECT_DIR="$p" MIND_LOG_FILE="$TMP/log" \
        bash "$B/$b.sh" "$@" >> "$p/.claude-mind/aus" 2>&1 )
  done
}
liste() { sort "$1/.claude-mind/mind-files-angelegt-ohne-lauf.txt" 2>/dev/null; }

echo "=== 1) ⛔ Bestand wie dieser Workspace: Git ohne Versions-Signal, Werkzeuge da, zaehl_gate unter Learnings/ ==="
A="$TMP/arbeits bereich"; mkdir -p "$A/tools" "$A/docs" "$A/Learnings" "$A/.claude/rules" "$A/.claude-mind"
git -C "$A" init -q 2>/dev/null
printf '# Projekt\n11 Skills, 2 Agents, 9 Hooks, 102 Funktionen\n' > "$A/CLAUDE.md"
for f in backup_tools rollback mutation_guard coverage_gate; do echo "# $f" > "$A/tools/$f.py"; done
echo x > "$A/docs/BACKUP_USAGE.md"; echo "# zaehl" > "$A/Learnings/zaehl_gate.py"
echo "eigene Liste" > "$A/.backupignore"
for f in backup-usage wissenstransfer-pruefen; do echo "# $f" > "$A/.claude/rules/$f.md"; done
VOR=$(dateien "$A"); fahre "$A" workspace
pruef "keine Datei angelegt" "$(diff <(echo "$VOR") <(dateien "$A") | grep -c '^>')" "0"
pruef "   ... und keine gemeldet" "$(liste "$A" | grep -c .)" "0"
pruef "   ... .backupignore nicht ueberschrieben" "$(cat "$A/.backupignore")" "eigene Liste"
pruef "   ... Release-Hygiene nennt den Grund" "$(grep -c 'NICHT ANGELEGT: Release-Hygiene' "$A/.claude-mind/aus")" "1"
pruef "   ... Zaehl-Gate: schon da (Learnings/)" "$(grep -c 'NICHT ANGELEGT: Zaehl-Gate — schon da: Learnings/zaehl_gate.py' "$A/.claude-mind/aus")" "1"

echo "=== 2a) v5.167.0: dieselbe App OHNE --anlegen: Tool-Bundles bleiben ein Angebot ==="
P0="$TMP/app ohne zusage"; mkdir -p "$P0/docs" "$P0/.claude-mind"; git -C "$P0" init -q 2>/dev/null
printf '[project]
version = "1.0"
' > "$P0/pyproject.toml"; printf '# App
3 Fenster, 4 Dialoge, 5 Tabellen
' > "$P0/CLAUDE.md"
VOR=$(dateien "$P0"); fahre "$P0" code_app
pruef "nichts angelegt" "$(diff <(echo "$VOR") <(dateien "$P0") | grep -c '^>')" "0"
pruef "   ... FUENF Bundles als ANGEBOT gemeldet (Backup, Release, Versioning, Doku, Zaehl; die Backup-Rule folgt dem Werkzeug)" "$(grep -c '^ANGEBOT (nicht angelegt): ' "$P0/.claude-mind/aus")" "5"

echo "=== 2) Python-App mit Versions-Signal, leer, MIT --anlegen: angelegt == gemeldet ==="
P="$TMP/app mit leer"; mkdir -p "$P/docs" "$P/.claude-mind"
git -C "$P" init -q 2>/dev/null
printf '[project]\nversion = "1.0"\n' > "$P/pyproject.toml"; printf '# App\n3 Fenster, 4 Dialoge, 5 Tabellen\n' > "$P/CLAUDE.md"
VOR=$(dateien "$P"); fahre "$P" code_app --anlegen
NEU=$(diff <(echo "$VOR") <(dateien "$P") | sed -n 's/^> //p' | sort)
pruef "es wurde etwas angelegt" "$([ -n "$NEU" ] && echo ja || echo nein)" "ja"
pruef "⛔ angelegte Dateien == gemeldete Liste" "$([ "$NEU" = "$(liste "$P")" ] && echo gleich || echo "verschieden: $(echo $NEU) / $(echo $(liste "$P"))")" "gleich"
pruef "   ... Versioning-Pack dabei (code_app)" "$(liste "$P" | grep -c '^tools/version.py$')" "1"
pruef "   ... jede Zeile auch als ANGELEGT: ausgegeben" "$(grep -c '^ANGELEGT: ' "$P/.claude-mind/aus")" "$(liste "$P" | grep -c .)"
( cd "$P" && env -u PROJ -u LAUF CLAUDE_PROJECT_DIR="$P" MIND_LOG_FILE="$TMP/log" bash "$B/13-step6-report-pflicht.sh" > "$P/.claude-mind/b13" 2>&1 )
pruef "Block 13 nennt die Zahl" "$(grep -c "ANGELEGT in diesem Lauf: $(echo "$NEU" | grep -c .) Datei" "$P/.claude-mind/b13")" "1"

echo "=== 3) Versioning-Pack ohne Primary-Argument: nichts ==="
Q="$TMP/ohne typ"; mkdir -p "$Q/.claude-mind"; printf 'VERSION\n' > "$Q/VERSION"
( cd "$Q" && env -u PROJ -u LAUF CLAUDE_PROJECT_DIR="$Q" MIND_LOG_FILE="$TMP/log" bash "$B/07-step5c-versioning-pack.sh" > "$Q/.claude-mind/aus" 2>&1 )
pruef "kein version.py" "$([ -e "$Q/tools/version.py" ] && echo da || echo fehlt)" "fehlt"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
