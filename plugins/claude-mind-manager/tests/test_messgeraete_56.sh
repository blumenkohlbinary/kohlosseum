#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Messgeraete, die ihren Gegenstand nicht trafen (v5.147.0, Etappe 56 §5).
# ⛔ Die geprueften Zeilen werden AUS DEM SKILL.md gelesen, nicht abgeschrieben — sonst prueft
#    der Test seine eigene Kopie.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
U="$(skill_text_datei "$R" mind-update)"; M="$(skill_text_datei "$R" mind-memory)"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

echo "=== 3e.2) ein Datum ist keine Versionsnummer ==="
RX=$(tr -d '\r' < "$U" | grep -m1 '    hits=$(grep -nE "v?' | sed -n 's/.*grep -nE "\([^"]*\)".*/\1/p')
pruef "Muster gefunden" "$([ -n "$RX" ] && echo ja || echo nein)" "ja"
pruef "⛔ 'Stable 10.09.2026' ist KEIN Treffer" "$(printf 'Stable 10.09.2026 erreicht\n' | grep -cE "$RX")" "0"
pruef "'Stable v5.143.0' ist einer"            "$(printf 'Stable v5.143.0\n' | grep -cE "$RX")" "1"
pruef "'Tag 1.2.3-dev.4' ist einer"            "$(printf 'Tag 1.2.3-dev.4\n' | grep -cE "$RX")" "1"

echo "=== 1.5) eine Schreibweise je Datei ==="
NORM=$(tr -d '\r' < "$U" | grep -m1 "sed 's#^\\\\(\\\\./\\\\)\*##" | sed 's/^[[:space:]]*|[[:space:]]*//; s/)$//')   # die Zeile endet mit der schliessenden Klammer von < <(...)
pruef "Normalisierung gefunden" "$([ -n "$NORM" ] && echo ja || echo nein)" "ja"
printf '%s\n' "./docs/x.md" "././docs/x.md" "docs/x.md" "./docs/y.md" > "$TMP/l.txt"
pruef "⛔ drei Schreibweisen derselben Datei -> eine" \
  "$(bash -c "$NORM" < "$TMP/l.txt" | grep -c 'docs/x.md')" "1"
pruef "eine andere Datei bleibt" "$(bash -c "$NORM" < "$TMP/l.txt" | grep -c 'docs/y.md')" "1"

echo "=== 3c) ohne Conventional Commits: NICHT ANWENDBAR statt Schweigen ==="
G="$TMP/repo mit leer"; mkdir -p "$G"
( cd "$G" && git init -q && git config user.email t@t && git config user.name t \
  && for i in 1 2 3; do echo $i > f$i; git add f$i; git commit -qm "Kapitel $i ueberarbeitet"; done )
Z=$(tr -d '\r' < "$U" | grep -E '^_KC=|^_KK=|^\[ "\$\{_KK:-0\}" -eq 0 \]')
pruef "drei Zeilen gefunden" "$(printf '%s\n' "$Z" | grep -c .)" "3"
A=$(cd "$G" && bash -c "$Z")
pruef "⛔ meldet NICHT ANWENDBAR mit 0 von 3" "$(printf '%s' "$A" | grep -c 'NICHT ANWENDBAR: 0 von 3')" "1"
( cd "$G" && echo 4 > f4 && git add f4 && git commit -qm "feat: neue Sache" )
A=$(cd "$G" && bash -c "$Z")
pruef "GEGENKONTROLLE: mit einem feat:-Commit schweigt die Zeile" "$(printf '%s' "$A" | grep -c 'NICHT ANWENDBAR')" "0"

echo "=== mind-memory) der Poisoning-Scan schreibt eine Zaehlzeile ==="
pruef "DATEIEN=/BEFUNDE=-Zeile steht im Block" "$(grep -c 'echo "DATEIEN=$_n BEFUNDE=' "$M")" "1"
pruef "   ... und wird quittiert"                "$(grep -c 'mind_schritt mind_scan_poisoning gelaufen --datei' "$M")" "1"

echo "=== mind_zeilenenden_waechter) falscher Aufruf ist kein Ergebnis ==="
P="$TMP/proj mit leer"; mkdir -p "$P/.claude-mind" "$TMP/snap"; : > "$TMP/snap/CLAUDE.md"
A=$( source "$R/hooks/lib.sh"; MIND_LOG_FILE="$TMP/log" mind_zeilenenden_waechter "$P" "$TMP/snap" 2>/dev/null ); RC=$?
pruef "⛔ vertauschte Argumente -> rc 2"        "$RC" "2"
pruef "   ... und AUFRUF=falsch in der Zeile"  "$(printf '%s' "$A" | grep -c 'AUFRUF=falsch')" "1"

echo "=== §6) mind_projekt_wurzel: ein cwd IN .claude-mind/ oder .claude/ ist nicht das Projekt ==="
Q="$TMP/p mit leer"; mkdir -p "$Q/.claude-mind/sub" "$Q/.claude/rules"
w() { ( source "$R/hooks/lib.sh"; mind_projekt_wurzel "$1" ); }
pruef "⛔ aus .claude-mind/ -> das Projekt"     "$(w "$Q/.claude-mind")"     "$Q"
pruef "   ... auch aus einem Unterordner davon" "$(w "$Q/.claude-mind/sub")" "$Q"
pruef "aus .claude/rules -> das Projekt"        "$(w "$Q/.claude/rules")"    "$Q"
pruef "GEGENKONTROLLE: das Projekt selbst bleibt" "$(w "$Q")"                "$Q"
pruef "GEGENKONTROLLE: ~/.claude wird NICHT zu HOME" "$(w "$HOME/.claude")"  "$HOME/.claude"

echo "=== §6) mind_stufe3_datei: Memory-Dateien haben einen eigenen Ort, projektgetrennt ==="
H2="$TMP/home mit leer"; mkdir -p "$H2/.claude/projects/proj-a/memory" "$H2/.claude/projects/proj-b/memory"
s3() { ( export HOME="$H2"; source "$R/hooks/lib.sh"; mind_stufe3_datei "$1" ); }
A1=$(s3 "$H2/.claude/projects/proj-a/memory/thema.md"); B1=$(s3 "$H2/.claude/projects/proj-b/memory/thema.md")
pruef "⛔ zwei Projekte, gleicher Dateiname -> zwei Orte" "$([ "$A1" != "$B1" ] && echo ja || echo nein)" "ja"
pruef "   ... neben dem Memory-Ordner, nicht darin"      "$(printf '%s' "$A1" | grep -c '/proj-a/stufe3/thema.stufe3.md$')" "1"
pruef "GEGENKONTROLLE: eine Rule bleibt unter .claude/archiv/"   "$(mkdir -p "$Q/.claude/rules"; : > "$Q/.claude/rules/r.md"; s3 "$Q/.claude/rules/r.md" | grep -c '/.claude/archiv/r.stufe3.md$')" "1"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
