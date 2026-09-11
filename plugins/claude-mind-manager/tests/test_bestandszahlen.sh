#!/usr/bin/env bash
# =============================================================================
#  ART 6 — der Kandidaten-Lister fuer ungegatete Bestandszahlen  (NEU v5.79.0)
# =============================================================================
#
# ⛔ WOZU. Sechs falsche Bestandszahlen an einem Tag (10.09.2026), alle in
#    Prosa, alle ungegatet. Anton entschied nach der Messung
#    (docs/plugin/art6-bestandszahlen.md): KEIN Gate — 8 von 8 „FALSCH"-Urteile
#    lagen daneben — aber ein LISTER: 48 -> 7, die bekannten Faelle dabei.
#
# ⭐ Was hier festgehalten wird: er findet die zwei ECHTEN Fehlzahlen des
#    Tages · er laesst datiert/gegatet/Messwert weg · er urteilt nie (rc 0) ·
#    die Meldezeile steht auch bei 0 Kandidaten · mind-rules ruft ihn.
# =============================================================================
set -u
WURZEL="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
L="$WURZEL/references/bestandszahlen_kandidaten.py"

OK=0; ROT=0
janein() {
  if [ "$2" = "$3" ]; then
    printf '    OK   %-58s ist=%s\n' "$1" "$3"; OK=$((OK + 1))
  else
    printf '    FEHL %-58s ist=%-12s soll=%s\n' "$1" "$3" "$2"; ROT=$((ROT + 1))
  fi
}
[ -f "$L" ] || { echo "ABBRUCH: $L fehlt"; exit 2; }

echo "=============================================================================="
echo "  1) Selbsttest: Positiv- UND Negativkontrolle"
echo "=============================================================================="
AUS=$(python "$L" --selbsttest 2>&1); RC=$?
janein "Selbsttest rc 0" "0" "$RC"
janein "Selbsttest: 11 ok, 0 rot" "ja" "$(printf '%s\n' "$AUS" | grep -q '11 ok, 0 rot' && echo ja || echo nein)"
janein "⭐ 'zwei Einmal-Messungen' gefunden (Positivkontrolle 1)" "ja" \
  "$(printf '%s\n' "$AUS" | grep -q "OK   ⭐ 'zwei Einmal-Messungen'" && echo ja || echo nein)"
janein "⭐ 'vier Gates' gefunden (Positivkontrolle 2)" "ja" \
  "$(printf '%s\n' "$AUS" | grep -q "OK   ⭐ 'vier Gates'" && echo ja || echo nein)"

echo
echo "=============================================================================="
echo "  2) ⛔ Er urteilt nie: rc 0 auf einem Projekt mit Kandidaten UND auf einem leeren"
echo "=============================================================================="
D=$(mktemp -d "${TMPDIR:-/tmp}/bzXXXXXX") || exit 2
mkdir -p "$D/.claude/rules"
cat > "$D/CLAUDE.md" <<'EOF'
# P

Es gibt vier Gates und drei Hooks.
Gemessen 01.09.2026: 12 Dateien.   # eigene Zeile: datiert gilt je ZEILE
EOF
AUS=$(python "$L" "$D" 2>&1); RC=$?
janein "Projekt mit Kandidaten -> rc 0" "0" "$RC"
janein "Meldezeile 'BESTANDSZAHLEN:' vorhanden" "ja" "$(printf '%s\n' "$AUS" | grep -q '^BESTANDSZAHLEN:' && echo ja || echo nein)"
janein "2 UNGEGATET+UNDATIERT (vier Gates, drei Hooks)" "ja" "$(printf '%s\n' "$AUS" | grep -q '2 UNGEGATET+UNDATIERT' && echo ja || echo nein)"
janein "1 datiert (12 Dateien, 01.09.2026)" "ja" "$(printf '%s\n' "$AUS" | grep -q '1 datiert' && echo ja || echo nein)"
printf '# leer\n\nNur Prosa ohne Zahl.\n' > "$D/CLAUDE.md"
AUS=$(python "$L" "$D" 2>&1); RC=$?
janein "leeres Projekt -> rc 0" "0" "$RC"
janein "... und die Zeile sagt '0 Kandidaten', statt zu schweigen" "ja" \
  "$(printf '%s\n' "$AUS" | grep -q '^BESTANDSZAHLEN: 0 Kandidaten' && echo ja || echo nein)"
janein "ohne Argument: Hilfe, rc 0" "0" "$(python "$L" >/dev/null 2>&1; echo $?)"
# v5.89.0: weitere Dateien (Memory-Topics) als Positionsargumente — nur was es gibt
printf '# Topic\n\nEs gibt vier Gates.\n' > "$D/topic.md"
AUS=$(python "$L" "$D" "$D/topic.md" "$D/gibtsnicht.md" 2>&1); RC=$?
janein "Topic-Datei als weiteres Argument: 1 Kandidat, rc 0" "0|ja" "$(echo "$RC|$(printf '%s\n' "$AUS" | grep -q '1 UNGEGATET+UNDATIERT' && echo ja || echo nein)")"
janein "   ... fehlende Datei wird still uebergangen" "ja" "$(printf '%s\n' "$AUS" | grep -q 'gibtsnicht' && echo nein || echo ja)"
janein "mind-memory ruft den Lister mit \$MEMORY_DIR/*.md" "ja" "$(grep -q 'bestandszahlen_kandidaten.py" "\$PROJ" "\$MEMORY_DIR"/\*.md' "$WURZEL/skills/mind-memory/SKILL.md" && echo ja || echo nein)"
rm -rf "$D"

echo
echo "=============================================================================="
echo "  3) Eingebaut: mind-rules ruft ihn, bestands-pass.md fuehrt ihn"
echo "=============================================================================="
janein "mind-rules/SKILL.md ruft bestandszahlen_kandidaten.py" "ja" \
  "$(grep -q 'references/bestandszahlen_kandidaten.py' "$WURZEL/skills/mind-rules/SKILL.md" && echo ja || echo nein)"
janein "mind-rules: PFLICHTSCHRITT eingetragen" "ja" \
  "$(grep -qx 'bestandszahlen_kandidaten' "$WURZEL/skills/mind-rules/SKILL.md" && echo ja || echo nein)"
janein "mind-rules: in mind_schritt_start genannt" "ja" \
  "$(grep -E '^mind_schritt_start .*bestandszahlen_kandidaten' "$WURZEL/skills/mind-rules/SKILL.md" >/dev/null && echo ja || echo nein)"
janein "v5.85.0: mind-claudemd ruft den Lister (Schritt 1b)" "ja" \
  "$(grep -q 'references/bestandszahlen_kandidaten.py' "$WURZEL/skills/mind-claudemd/SKILL.md" && echo ja || echo nein)"
janein "mind-claudemd: PFLICHTSCHRITT + mind_schritt_start" "2" \
  "$(grep -cE '^bestandszahlen_kandidaten$|^mind_schritt_start .*bestandszahlen_kandidaten' "$WURZEL/skills/mind-claudemd/SKILL.md")"
janein "bestands-pass.md: Abschnitt 1b mit 'urteilt nie'" "ja" \
  "$(grep -q 'urteilt nie' "$WURZEL/references/bestands-pass.md" && echo ja || echo nein)"

echo
echo "=============================================================================="
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
