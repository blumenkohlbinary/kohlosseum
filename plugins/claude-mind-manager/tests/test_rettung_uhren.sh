#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Die Rettung benennt ihre zwei Uhren (v5.143.0, Etappe 53 §3 + 56 §4).
#
# ⛔ WAS GEMESSEN WURDE (28.10.2026, drei Rettungen aus Palvedo): der Inhalt traegt UTC
#    (`...Z`), Dateiname und „Gerettet" tragen Ortszeit. Gemeldet war eine Luecke von „rund
#    zwei Stunden" — in Wahrheit 34 s bis 2 min 37 s. Ein Mensch und vier Agenten haben die
#    beiden Uhren verglichen, und alle kamen auf zwei Stunden.
# ⭐ Der Fix ist nicht, die Luecke zu suchen, sondern die Uhr ZU BENENNEN.
# ⛔ Fall 3 haelt die Falle selbst fest: wer die Zeiten so vergleicht, wie sie dastehen,
#    bekommt die falsche Antwort. Diese Zusicherung wird nicht „repariert", sie DOKUMENTIERT.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
S="$R/references/session_sampler.py"
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }

pruef "Sampler liegt im Paket" "$([ -f "$S" ] && echo ja || echo nein)" "ja"
[ -f "$S" ] && [ -n "$PY" ] || { echo "  Gegenstand fehlt"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
T="$TMP/sitzung mit leer.jsonl"
printf '%s\n' \
  '{"type":"user","timestamp":"2026-10-03T18:58:00.000Z","message":{"content":"bitte pruefen, ob die Entscheidung passt"}}' \
  '{"type":"assistant","timestamp":"2026-10-03T18:58:34.460Z","message":{"content":[{"type":"text","text":"Ja, entschieden: Weg A, weil B fehlschlaegt"}]}}' \
  > "$T"

echo "=== 1) Voll-Rettung: der Kopf benennt BEIDE Uhren ==="
"$PY" "$(win "$S")" --full "$(win "$T")" "$(win "$TMP/r.md")" >/dev/null 2>&1
K="$TMP/r.md"
pruef "Rettung geschrieben"                    "$([ -s "$K" ] && echo ja || echo nein)" "ja"
pruef "die Zeile Gerettet sagt Ortszeit"       "$(grep -c '^- Gerettet: .* Ortszeit = .*Z UTC$' "$K")" "1"
pruef "der Kopf sagt, dass die Beitraege UTC sind" "$(grep -c 'Zeitstempel der Beitraege unten: UTC' "$K")" "1"
pruef "erster und letzter Beitrag stehen im Kopf" \
  "$(grep -c '^- Erster Beitrag: 2026-10-03T18:58:00.000Z UTC .* letzter Beitrag: 2026-10-03T18:58:34.460Z UTC$' "$K")" "1"
pruef "Werkzeugaufrufe als fehlend benannt (stand schon vor v5.143.0 da)" \
  "$(grep -c 'Tool-Aufrufe/-Ergebnisse sind bewusst nicht enthalten' "$K")" "1"
# ⛔ GEGENKONTROLLE: die Beitrags-Kopfzeilen selbst sind UNVERAENDERT — `mind_rettung_nach_sync`
#    liest genau dieses Format. Wuerde der neue Kopf es stoeren, kaeme die Schuld-Erkennung
#    still durcheinander.
pruef "Beitrags-Kopfzeilen im alten Format" "$(grep -cE '^## \[[0-9]+\] (USER|ASSISTANT) — 2026-' "$K")" "2"
pruef "die neuen Kopfzeilen beginnen NICHT mit '## ['" \
  "$(grep -E '^- (Gerettet|Erster)' "$K" | grep -c '^## \[')" "0"

echo "=== 2) Auszug: jeder Beitrag traegt seinen Zeitstempel ==="
"$PY" "$(win "$S")" "$(win "$T")" "$(win "$TMP/a.json")" >/dev/null 2>&1
pruef "Auszug geschrieben" "$([ -s "$TMP/a.json" ] && echo ja || echo nein)" "ja"
pruef "jeder Eintrag hat ts" \
  "$("$PY" -c "import json,sys;d=json.load(open(sys.argv[1],encoding='utf-8'));s=d.get('sample',[]);print('ja' if s and all(e.get('ts') for e in s) else 'nein')" "$(win "$TMP/a.json")")" "ja"

echo "=== 3) ⛔ DIE FALLE, festgehalten: so verglichen, wie es dasteht ==="
# Dateiname 20261003-205954 (Ortszeit, Oktober = UTC+2), letzter Beitrag 18:58:34Z.
NAIV=$("$PY" -c "
import datetime as d
r=d.datetime.strptime('20261003-205954','%Y%m%d-%H%M%S')
u=d.datetime.strptime('2026-10-03T18:58:34','%Y-%m-%dT%H:%M:%S')
print(int((r-u).total_seconds()//60))")
RICHTIG=$("$PY" -c "
import datetime as d
r=d.datetime.strptime('20261003-205954','%Y%m%d-%H%M%S')
u=d.datetime.strptime('2026-10-03T18:58:34','%Y-%m-%dT%H:%M:%S')+d.timedelta(hours=2)
print(int((r-u).total_seconds()//60))")
pruef "naiv verglichen: rund zwei Stunden (die falsche Antwort)" "$([ "$NAIV" -ge 118 ] && [ "$NAIV" -le 122 ] && echo ja || echo nein)" "ja"
pruef "in EINER Zeitzone: eine Minute (die richtige)"          "$RICHTIG" "1"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
