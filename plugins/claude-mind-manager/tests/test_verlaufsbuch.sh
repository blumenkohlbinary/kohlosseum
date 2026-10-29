#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Das Verlaufsbuch (v5.160.0, Etappe 62) — EINE Datei je Sitzung statt N voller Chat-Rettungen.
#
# ⭐ GEMESSEN 29.10.2026 (PLAN-etappe62.md): Claudes Kompaktierungs-Zusammenfassung steht VOR dem
#    SessionStart:compact-Hook im Transkript (18/18); Abschnitt deckt 18–36 % der Marken des Chats bei 3–8 %
#    der Groesse; Zusammenfassungen sind NICHT kumulativ (34–37 % Uebernahme) -> anhaengen.
# Geprueft: der Hook schreibt den Abschnitt (und nur einmal), 20 Kompaktierungen -> eine Datei ohne doppelte
# Zeile, die Zuordnung Rettung -> Abschnitt (mind_verlauf_fuer), und dass der Sync es NENNT.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$R"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
P="$TMP/projekt mit leer"; mkdir -p "$P/.claude-mind/rescued"
SID="aaaa1111-0000-0000-0000-00000000beef"; STAMM="20261029-120000-000-0000beef"
printf '{"entscheidungen":[],"bugs":[],"dateien":["x.py"],"constraints":[]}' > "$P/.claude-mind/rescued/${STAMM}_ARBEITSSTAND.json"
: > "$P/.claude-mind/rescued/${STAMM}_chat.md"
T="$TMP/sitzung.jsonl"
grenzen() {  # $1 = Anzahl Kompaktierungen
  : > "$T"
  for i in $(seq 1 "$1"); do
    printf '{"type":"user","message":{"content":"Arbeit %d"}}\n' "$i" >> "$T"
    printf '{"type":"system","subtype":"compact_boundary"}\n' >> "$T"
    printf '{"type":"user","isCompactSummary":true,"message":{"content":"ZUSAMMENFASSUNG-%d"}}\n' "$i" >> "$T"
  done
}
start() {  # $1 = source
  printf '{"session_id":"%s","source":"%s","transcript_path":"%s","cwd":"%s"}' "$SID" "$1" "$T" "$P" \
    | ( cd "$P" && env -u CLAUDE_CODE_HOST_SESSION_ID CLAUDE_PROJECT_DIR="$P" bash "$R/hooks/session-start.sh" ) >/dev/null 2>&1
}
VB="$P/.claude-mind/verlauf/$SID.md"

echo "=== 1) der Selbsttest des Werkzeugs ==="
pruef "verlaufsbuch.py --selbsttest" "$(python "$R/references/verlaufsbuch.py" --selbsttest >/dev/null 2>&1; echo $?)" "0"

echo "=== 2) SessionStart:compact schreibt EINEN Abschnitt ==="
grenzen 1; start compact
pruef "Verlaufsbuch angelegt" "$([ -f "$VB" ] && echo ja || echo nein)" "ja"
pruef "  ... mit Claudes Zusammenfassung" "$(grep -c 'ZUSAMMENFASSUNG-1' "$VB" 2>/dev/null)" "1"
pruef "  ... und der Rettung im Kopf" "$(grep -c "rettung=$STAMM\$" "$VB" 2>/dev/null)" "1"
start compact
pruef "⛔ derselbe Start zweimal -> kein zweiter Abschnitt" "$(grep -c '^## Kompaktierung' "$VB")" "1"
grenzen 2; start startup
pruef "⛔ source=startup schreibt NICHTS" "$(grep -c '^## Kompaktierung' "$VB")" "1"

echo "=== 3) 20 Kompaktierungen -> eine Datei, keine Zeile doppelt ==="
for n in $(seq 2 20); do grenzen "$n"; start compact; done
pruef "20 Abschnitte" "$(grep -c '^## Kompaktierung' "$VB")" "20"
pruef "Dateien im Verlaufsordner" "$(ls "$P/.claude-mind/verlauf" | wc -l | tr -d ' ')" "1"
pruef "⭐ Bereiche luecklos und ohne Ueberlappung" "$(grep -oE 'zeilen=[0-9]+-[0-9]+' "$VB" | tr -d 'zeilen=' \
  | awk -F- 'NR>1 && $1!=prev+1 {bad++} {prev=$2} END {print bad+0}')" "0"
echo "      Groesse nach 20 Abschnitten: $(wc -c < "$VB") B"

echo "=== 4) Rettung -> Abschnitt (mind_verlauf_fuer) ==="
fuer() { ( . "$R/hooks/lib.sh"; mind_verlauf_fuer "$P" "$1" ) ; }
pruef "bekannte Rettung -> der Pfad" "$(fuer "$P/.claude-mind/rescued/${STAMM}_chat.md")" "$VB"
pruef "⛔ fremde Rettung -> rc 1" "$(fuer "20991231-000000-000-ffffffff_chat.md" >/dev/null; echo $?)" "1"

echo "=== 5) der Sync NENNT das Verlaufsbuch (mind-update Step 3.5) ==="
printf 'sid=%s\npath=%s\n' "$SID" "$P/.claude-mind/rescued/${STAMM}_chat.md" > "$P/.claude-mind/rescued/OPEN"
printf '## [1] USER\nx\n' > "$P/.claude-mind/rescued/${STAMM}_chat.md"
A=$( cd "$P" && CLAUDE_PROJECT_DIR="$P" bash "$R/skills/mind-update/bloecke/step3.5-sampling.sh" 2>&1 | grep -c 'Verlaufsbuch (zuerst lesen)' )
pruef "Step 3.5 nennt das Verlaufsbuch zur Rettung" "$A" "1"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
