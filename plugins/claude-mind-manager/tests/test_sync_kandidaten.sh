#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# v5.175.0 (Etappe 68): die knowledge-sync-Agenten bekommen ihre Kandidaten MECHANISCH vorgelegt.
# Isolierter Einzeltest 31.10.2026 (cwd = Stand e66): rules pruefte die Optionen nur einer Werkzeug-Rule, memory
# das Zitat in rotes-gate nicht. Gegen 5.174.0 sind Abschnitt 1 (kein Werkzeug) und 2 (kein Aufruf) rot.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)

echo "=== 1) das Werkzeug und sein Selbsttest ==="
pruef "references/sync_kandidaten.py liegt im Paket" "$([ -f "$R/references/sync_kandidaten.py" ] && echo ja || echo nein)" "ja"
"$PY" "$R/references/sync_kandidaten.py" --selbsttest >/dev/null 2>&1; pruef "Selbsttest rc 0" "$?" "0"
"$PY" "$R/references/sync_kandidaten.py" >/dev/null 2>&1; pruef "ohne Liste: rc 2" "$?" "2"

echo "=== 2) der Auftragsgenerator legt die Listen vor ==="
A="$R/skills/mind-update/bloecke/agent-schritt.sh"
pruef "rules: Optionen-Liste" "$(grep -c 'kandidaten --optionen' "$A")" "1"
pruef "memory: Zitat-Liste" "$(grep -c 'kandidaten --zitate' "$A")" "1"
pruef "rules + memory + claude-md: Buch-Liste" "$(grep -c 'kandidaten "\${_BUCH\[@\]}"' "$A")" "3"
pruef "claude-md: Zeiger-Liste" "$(grep -c 'kandidaten --zeiger' "$A")" "1"
pruef "Pflichtabschnitt KANDIDATEN" "$(grep -c 'einen Abschnitt KANDIDATEN' "$A")" "1"
pruef "jede Topic-Datei bekommt ein Urteil" "$(grep -c 'JEDE Topic-Datei bekommt ein Urteil' "$A")" "1"

echo "=== 3) projektfremdes Themenwissen -> docs/wissen/ (Etappe 68 §6, Nutzer 30.10.2026) ==="
pruef "memory + custom-context: NEW_FILE docs/wissen" "$(grep -c 'NEW_FILE docs/wissen/<thema>.md' "$A")" "1"
pruef "context-analyzer kennt EC4" "$(grep -c 'EC4 Themenwissen AUSSERHALB' "$R/agents/context-analyzer.md")" "1"
pruef "Kontext-Tor W1 nennt docs/wissen" "$(grep -c '^| \*\*W1\*\* .*docs/wissen/<thema>.md' "$R/references/kontext-tor.md")" "1"
pruef "cleaner_tor W1 nennt docs/wissen" "$(grep -c 'Themenwissen ausserhalb des Projekts -> docs/wissen' "$R/references/cleaner_tor.py")" "1"
pruef "keine W1-Quittung mehr mit <joplin>" "$(cat "$R"/skills/mind-{claudemd,files,memory,rules,update}/SKILL.md | grep -c '/<joplin>/')" "0"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
