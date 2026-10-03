#!/bin/bash
. "$(dirname "$0")/lib_test.sh"
# Ratsche gegen den Rueckfall auf "zehn" (v5.142.0, Etappe 52 §1, Teil 4).
#
# ⛔ WARUM EINE RATSCHE UND NICHT NUR EIN EINMALIGES NACHZIEHEN
#    `/mind-denkstufe` ist der elfte Befehl, und die Zahl "zehn" stand an 14 Stellen.
#    Vier davon sind PRUEFSAMMLUNGEN und melden sich selbst, wenn sie veralten — die
#    anderen zehn sind Prosa und veralten LAUTLOS. Genau diese Klasse hat in
#    `architecture.md` und in der globalen `CLAUDE.md` je eine feste Zahl gekostet.
#
# ⛔ UND WAS HIER ABSICHTLICH NICHT GEPRUEFT WIRD:
#    historische Stellen bleiben, wie sie sind. "zwei von zehn Commands" beschreibt ein
#    vergangenes Ereignis; `art6-bestandszahlen.md` ist ein MESSPROTOKOLL — wer es
#    glaettet, faelscht es; `design-history.md` nennt "den zehnten Command" und meint
#    den Zeitpunkt. Eine Zahl, die einen anderen Gegenstand meint, wird nicht
#    mitgezogen (`art6-bestandszahlen.md`: eine Bestandszahl nennt ihren Gegenstand GENAU).

export CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-C:/CD/KOHLEKTIV/Plugin - Entwicklung/hackj-plugins/plugins/claude-mind-manager}"

ok=0; rot=0; uebersprungen=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

# --- 1 · der Skill selbst ----------------------------------------------------
S="$CLAUDE_PLUGIN_ROOT/skills/mind-denkstufe/SKILL.md"
pruef "der elfte Skill liegt im Paket" "$([ -f "$S" ] && echo ja || echo nein)" "ja"
pruef "es sind elf Skills" \
  "$(ls -1 "$CLAUDE_PLUGIN_ROOT"/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')" "11"

# --- 2 · der Stempel-Hinweis in JEDEM Skill ---------------------------------
# ⛔ Der Stempler schreibt diese Zeile in jede Datei. Sagt eine noch "zehn", ist der
#    Stempler nicht gelaufen — und dann stimmen auch die Versionen nicht.
pruef "alle elf Stempel sagen 'alle elf'" \
  "$(grep -l 'prueft alle elf' "$CLAUDE_PLUGIN_ROOT"/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')" "11"
pruef "keiner sagt noch 'alle zehn'" \
  "$(grep -l 'prueft alle zehn' "$CLAUDE_PLUGIN_ROOT"/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')" "0"

# --- 3 · die Stellen im PAKET ------------------------------------------------
pruef "lib.sh: elf Skills dieses Plugins" \
  "$(grep -c 'fuer die elf Skills dieses Plugins' "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh")" "1"
pruef "lib.sh sagt nicht mehr 'die zehn Skills dieses Plugins'" \
  "$(grep -c 'die zehn Skills dieses Plugins' "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh")" "0"
# ⚠ `alle zehn Aufrufer` DARF bleiben — es zaehlt Aufrufer, nicht Skills.
pruef "'alle zehn Aufrufer' bleibt unangetastet (anderer Gegenstand)" \
  "$(grep -c 'alle zehn Aufrufer' "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh")" "1"

# --- 4 · die Stellen im WORKSPACE -------------------------------------------
# ⛔ Fehlt CLAUDE_PROJECT_DIR, wird LAUT uebersprungen. Ein stiller Sprung waere
#    derselbe Fehler wie in test_bestandspass.sh vor v5.72.0: ein uebersprungener
#    Fall ist KEIN bestandener.
W="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$W" ] || [ ! -f "$W/CLAUDE.md" ]; then
  echo "  [--- ] UEBERSPRUNGEN: CLAUDE_PROJECT_DIR fehlt oder zeigt nicht auf den Workspace."
  echo "         ⚠ Ein uebersprungener Fall ist KEIN bestandener — mit CLAUDE_PROJECT_DIR fahren."
  uebersprungen=$((uebersprungen+1))
else
  pruef "CLAUDE.md: Slash-Commands (11)" \
    "$(grep -c 'Slash-Commands des Plugins (11)' "$W/CLAUDE.md")" "1"
  pruef "CLAUDE.md nennt /mind-denkstufe" \
    "$(grep -c '/mind-denkstufe' "$W/CLAUDE.md" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"
  pruef "CLAUDE.md: 6 der 11" "$(grep -c '6 der 11' "$W/CLAUDE.md")" "1"
  pruef "CLAUDE.md: stempelt alle elf" \
    "$(grep -c 'stempelt alle elf' "$W/CLAUDE.md")" "1"
  pruef "CLAUDE.md sagt nirgends mehr '(10)' fuer die Commands" \
    "$(grep -c 'Slash-Commands des Plugins (10)' "$W/CLAUDE.md")" "0"
  pruef "architecture.md: Skills (11" \
    "$(grep -c '## Skills (11' "$W/.claude/rules/architecture.md")" "1"
  pruef "architecture.md listet mind-denkstufe" \
    "$(grep -c 'mind-denkstufe' "$W/.claude/rules/architecture.md" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"
  pruef "werkzeuge-zuerst.md: Alle elf SKILL.md" \
    "$(grep -c 'Alle elf SKILL.md' "$W/.claude/rules/werkzeuge-zuerst.md")" "1"
  pruef "skill_stempel.py: in alle elf" \
    "$(grep -c 'in alle elf SKILL.md' "$W/Learnings/skill_stempel.py")" "1"
  pruef "skill_stempel.py schreibt 'alle elf' in den Block" \
    "$(grep -c 'prueft alle elf' "$W/Learnings/skill_stempel.py")" "1"
  pruef "README.md: Commands (11)" \
    "$(grep -c '### Commands (11)' "$W/docs/plugin/README.md")" "1"
  pruef "README.md verlinkt die neue Seite" \
    "$(grep -c 'commands/mind-denkstufe.md' "$W/docs/plugin/README.md" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"
  pruef "die neue Doku-Seite existiert" \
    "$([ -f "$W/docs/plugin/commands/mind-denkstufe.md" ] && echo ja || echo nein)" "ja"
  pruef "wohin-gehoert-es.md: Skill im Plugin (11)" \
    "$(grep -c 'Skill \*\*im Plugin\*\* (11)' "$W/docs/plugin/wohin-gehoert-es.md")" "1"
  pruef "mind-cleaner.md: einziger der elf Commands" \
    "$(grep -c 'einziger der elf Commands' "$W/docs/plugin/commands/mind-cleaner.md")" "1"

  # ⚠ GEGENKONTROLLE: die historischen Stellen MUESSEN noch "zehn" sagen. Waeren sie
  #   mitgezogen, waere ein Messprotokoll gefaelscht — und diese Sammlung haette es
  #   nicht gemerkt, weil sie nur nach "elf" gesucht haette.
  pruef "historisch: 'zwei von zehn Commands' steht noch da" \
    "$(grep -c 'zwei von zehn Commands' "$W/docs/plugin/commands/mind-cleaner.md")" "1"
  pruef "historisch: das Messprotokoll ist unangetastet" \
    "$(grep -c 'zehn Ordner' "$W/docs/plugin/art6-bestandszahlen.md")" "1"
fi

echo ""
echo "  $ok gruen · $rot rot · $uebersprungen uebersprungen"
[ "$rot" -eq 0 ] || exit 1
