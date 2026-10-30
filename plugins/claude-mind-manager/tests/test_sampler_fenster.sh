#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Der Live-Sampler von mind-update sieht den Zeitraum SEIT DEM LETZTEN SYNC (v5.161.0, Etappe 63 N1).
#
# ⛔ GEMESSEN 30.10.2026 (Ritas Lauf 20261030-003203): `mind-update.<sid>.json` trug nur Ereignisse vom
#    10.09.2026, 0 aus dem Zeitraum des Laufs. Ursache: der Selbst-Ausschluss schnitt an der letzten Zeile mit
#    `<command-name>/mind-all` — die entsteht nur beim GETIPPTEN Befehl; Starts ueber das Skill-Werkzeug
#    (11 von 14 in Ritas Sitzung) hinterlassen „Base directory for this skill: …mind-all". Und ein Fenster
#    „seit dem letzten Sync" gab es nicht.
# Gegen 5.160.0 sind Abschnitt 1 und 3 rot.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
S="$R/references/session_sampler.py"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
T="$TMP/sitzung.jsonl"; O="$TMP/out.json"
u() { printf '{"type":"user","timestamp":"%s","message":{"content":"%s"}}\n' "$1" "$2" >> "$T"; }
: > "$T"
u 2026-09-10T10:00:00.000Z '<command-name>/claude-mind-manager:mind-all</command-name>'
u 2026-09-10T11:00:00.000Z 'ALT vom zehnten'
u 2026-10-30T01:00:00.000Z 'NEU eins'
u 2026-10-30T02:00:00.000Z 'NEU zwei'
u 2026-10-30T03:00:00.000Z 'Base directory for this skill: C:\\\\x\\\\skills\\\\mind-all'
u 2026-10-30T03:05:00.000Z 'LAUF selbst'
zaehl() { python - "$O" "$1" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print(sum(1 for s in d["sample"] if s["text"].startswith(sys.argv[2])))
EOF
}

echo "=== 1) Start ueber das Skill-Werkzeug: Selbst-Ausschluss an DIESER Zeile, nicht am 10.09. ==="
python "$S" "$T" "$O" >/dev/null 2>&1
pruef "Ereignisse seit dem Sync sind drin" "$(zaehl NEU)" "2"
pruef "⛔ der laufende Lauf selbst NICHT" "$(zaehl LAUF)" "0"

echo "=== 2) --von: nichts vor dem letzten Sync ==="
python "$S" "$T" "$O" --von 2026-10-30T00:30:36Z >/dev/null 2>&1
pruef "vor dem Sync: nichts" "$(zaehl ALT)" "0"
pruef "  ... danach: alles" "$(zaehl NEU)" "2"

echo "=== 3) --bis: Laufbeginn schneidet, auch OHNE jede Marke ==="
grep -v 'Base directory' "$T" > "$TMP/t2.jsonl"
python "$S" "$TMP/t2.jsonl" "$O" --bis 2026-10-30T03:00:00Z >/dev/null 2>&1
pruef "nach dem Laufbeginn: nichts" "$(zaehl LAUF)" "0"
pruef "  ... davor: alles" "$(zaehl NEU)" "2"
pruef "das Fenster steht in der Ausgabe" "$(grep -c '"bis": "2026-10-30T03:00:00Z"' "$O")" "1"

echo "=== 4) ohne Flaggen wie bisher: der getippte Befehl schneidet ==="
: > "$TMP/t3.jsonl"; T0="$T"; T="$TMP/t3.jsonl"
u 2026-10-30T01:00:00.000Z 'NEU vorher'
u 2026-10-30T02:00:00.000Z '<command-name>/mind-update</command-name>'
u 2026-10-30T02:01:00.000Z 'LAUF nachher'
T="$T0"
python "$S" "$TMP/t3.jsonl" "$O" >/dev/null 2>&1
pruef "getippte Marke schneidet weiter" "$(zaehl LAUF)" "0"
pruef "  ... davor bleibt" "$(zaehl NEU)" "1"

echo "=== 5) der Block reicht das Fenster durch ==="
B="$R/skills/mind-update/bloecke/step3.5-sampling.sh"
pruef "Step 3.5 liest utc= aus letzter-sync" "$(grep -c 'utc=.*letzter-sync' "$B")" "1"
pruef "Step 3.5 uebergibt --von und --bis" "$(grep -c -- '--von "$_VON"} ${_BIS:+--bis' "$B")" "1"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
