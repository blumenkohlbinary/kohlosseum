#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Jeder menschliche Beitrag bleibt im Auszug (v5.144.0, 56 §4, Antons Vorgabe 28.10.2026).
#
# ⛔ GEMESSEN (25 groesste Transkripte aller Projekte): von 3 314 menschlichen Beitraegen kamen
#    672 (20 %) im Auszug an. Eine Ein-Wort-Korrektur traegt kein Relevanzmuster und fiel in
#    Stufe 1 heraus — genau das, was ein Sync am wenigsten verlieren darf.
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
# 400 relevante Assistenten-Beitraege (Stufe 2 greift: > 300), dazwischen:
#   Zeile 201: die Ein-Wort-Korrektur des Menschen
#   Zeile 202: eine Systemmeldung im Nutzerkanal (beginnt mit <) — zaehlt NICHT als menschlich
#   Zeile 203: ein menschlicher Beitrag MIT Relevanzmuster — darf nicht doppelt erscheinen
{
  i=1
  while [ $i -le 400 ]; do
    printf '{"type":"assistant","timestamp":"2026-10-28T10:%02d:%02dZ","message":{"content":[{"type":"text","text":"Entscheidung: Weg %d, weil der andere fehlschlaegt"}]}}\n' $((i/60)) $((i%60)) $i
    if [ $i -eq 200 ]; then
      printf '%s\n' '{"type":"user","timestamp":"2026-10-28T11:00:00Z","message":{"content":"nein"}}'
      printf '%s\n' '{"type":"user","timestamp":"2026-10-28T11:00:01Z","message":{"content":"<task-notification>agent fertig</task-notification>"}}'
      printf '%s\n' '{"type":"user","timestamp":"2026-10-28T11:00:02Z","message":{"content":"wichtig: niemals pushen ohne pull"}}'
    fi
    i=$((i+1))
  done
} > "$T"

"$PY" "$(win "$S")" "$(win "$T")" "$(win "$TMP/a.json")" >/dev/null 2>&1
pruef "Auszug geschrieben" "$([ -s "$TMP/a.json" ] && echo ja || echo nein)" "ja"
zaehle() { "$PY" -c "import json,sys;d=json.load(open(sys.argv[1],encoding='utf-8'));print(sum(1 for e in d.get('sample',[]) if e['text'].strip()==sys.argv[2]))" "$(win "$TMP/a.json")" "$1"; }

pruef "⛔ die Ein-Wort-Korrektur steht im Auszug"         "$(zaehle 'nein')" "1"
pruef "der menschliche Beitrag mit Muster steht GENAU einmal" "$(zaehle 'wichtig: niemals pushen ohne pull')" "1"
pruef "die Systemmeldung gilt nicht als menschlich (ohne Muster: draussen)" \
  "$(zaehle '<task-notification>agent fertig</task-notification>')" "0"
pruef "menschlich_behalten = 2" \
  "$("$PY" -c "import json,sys;print(json.load(open(sys.argv[1],encoding='utf-8')).get('menschlich_behalten'))" "$(win "$TMP/a.json")")" "2"
# ⛔ GEGENKONTROLLE: die Relevanzauswahl fuer den Assistenten gilt weiter (5 x 60 = 300)
pruef "Assistent weiter auf 300 begrenzt" \
  "$("$PY" -c "import json,sys;print(sum(1 for e in json.load(open(sys.argv[1],encoding='utf-8'))['sample'] if e['role']=='ASSISTANT'))" "$(win "$TMP/a.json")")" "300"
pruef "Auszug in Transkript-Reihenfolge" \
  "$("$PY" -c "import json,sys;l=[e['line'] for e in json.load(open(sys.argv[1],encoding='utf-8'))['sample']];print('ja' if l==sorted(l) else 'nein')" "$(win "$TMP/a.json")")" "ja"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
