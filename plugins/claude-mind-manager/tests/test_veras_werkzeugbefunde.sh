#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Veras Werkzeug-Befunde aus Zustellplan (Laeufe 11./12.10.2026) — v5.145.0, Etappe 55.
#   M-B  das Verdichtungs-Gate pruefte nur EINE Richtung, und Versionsnummern waren keine Marke
#   M-D  ein Index-Zeiger ins PROJEKT galt als TOT
#   M-E  Startzeilen der Skills ohne Lauf-ID; VERSIONSBRUCH aus EINER alten Zeile, fuenf Laeufe lang
#   M-G  `rollen_geruest.py --pruefe` las jede fuenfte Spalte als `Ordner`
# ⛔ Jeder Abschnitt baut die Lage NACH, die Vera gemessen hat — nicht eine bequemere.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
G="$R/references/doc-templates/coverage_gate.py"

echo "=== M-B 1) eine verschwundene Versionsnummer wird als OFFEN gemeldet ==="
printf 'Zustellplan laeuft seit v1.0.22 stabil.\nDer Schalter `--frei` hilft.\n' > "$TMP/quelle.md"
printf 'Zustellplan laeuft stabil.\nDer Schalter `--frei` hilft.\n'              > "$TMP/ergebnis.md"
"$PY" "$(win "$G")" "$(win "$TMP/ergebnis.md")" "$(win "$TMP/quelle.md")" > "$TMP/b1.txt" 2>&1
pruef "⛔ rc 1 (Stufe 1 faengt es jetzt)" "$?" "1"
pruef "   ... und nennt die Version"     "$(grep -c 'OFFEN.*1.0.22' "$TMP/b1.txt")" "1"

echo "=== M-B 2) eine ERFUNDENE Marke wird ausgewiesen — ohne den rc zu aendern ==="
printf 'Zeilenende wird erhalten.\nDer Schalter `--frei` hilft.\n'                      > "$TMP/quelle.md"
printf 'Zeilenende `\\r\\n` wird erhalten.\nDer Schalter `--frei` hilft.\n'              > "$TMP/ergebnis.md"
"$PY" "$(win "$G")" "$(win "$TMP/ergebnis.md")" "$(win "$TMP/quelle.md")" > "$TMP/b2.txt" 2>&1
pruef "rc 0 (kein Gate, ein Ausweis)"       "$?" "0"
pruef "⛔ NEU: 1 Marke ausgewiesen"          "$(grep -c '^NEU: 1 ' "$TMP/b2.txt")" "1"
pruef "   ... und welche"                    "$(grep -F '\r\n' "$TMP/b2.txt" | grep -c '^    NEU ')" "1"
echo "=== M-B 3) GEGENKONTROLLE: nichts erfunden -> NEU: 0 ==="
"$PY" "$(win "$G")" "$(win "$TMP/quelle.md")" "$(win "$TMP/quelle.md")" > "$TMP/b3.txt" 2>&1
pruef "NEU: 0" "$(grep -c '^NEU: 0 ' "$TMP/b3.txt")" "1"
pruef "eine Dezimalzahl ist keine Version (1.5 ohne Einheit bleibt markenfrei)" \
  "$(printf 'Wert 1.5 hier.\n' > "$TMP/d.md"; "$PY" -c "import sys;sys.path.insert(0,sys.argv[1]);import coverage_gate as c;print(len(c.checkpoints(sys.argv[2])))" "$(win "$R/references/doc-templates")" "$(win "$TMP/d.md")")" "0"

echo "=== M-D) Index-Zeiger ins Projekt: PROJEKT, nicht TOT ==="
S="$(skill_text_datei "$R" mind-memory)"
awk '/^```bash/{f=1; b=""; next} /^```/{if(f && b ~ /echo "TOT: \$z"/){printf "%s", b; exit} f=0; next} f{b=b $0 "\n"}' "$S" \
  | tr -d '\r' > "$TMP/index.sh"
pruef "Index-Block auffindbar" "$([ -s "$TMP/index.sh" ] && echo ja || echo nein)" "ja"
PJ="$TMP/projekt mit leer"; MD="$TMP/memory mit leer"
mkdir -p "$PJ/docs" "$MD"
: > "$PJ/docs/bericht.md"; : > "$MD/da.md"
printf -- '- [da](da.md) — x\n- [Bericht](docs/bericht.md) — y\n- [weg](gibtsnicht.md) — z\n' > "$MD/MEMORY.md"
A=$(MEMORY_DIR="$MD" PROJ="$PJ" bash "$TMP/index.sh" 2>&1)
pruef "⛔ docs/bericht.md ist PROJEKT"   "$(printf '%s\n' "$A" | grep -c '^PROJEKT: docs/bericht.md')" "1"
pruef "   ... und NICHT tot"             "$(printf '%s\n' "$A" | grep -c '^TOT: docs/bericht.md')" "0"
pruef "GEGENKONTROLLE: das echte Loch bleibt TOT" "$(printf '%s\n' "$A" | grep -c '^TOT: gibtsnicht.md')" "1"
A=$(env -u MEMORY_DIR PROJ="$PJ" bash "$TMP/index.sh" 2>&1)
pruef "ohne MEMORY_DIR: sagt es, statt still leer zu sein" "$(printf '%s\n' "$A" | grep -c 'NICHT gefahren')" "1"

echo "=== M-E) Lauf-ID in der Startzeile, VERSIONSBRUCH nur aus diesem Lauf ==="
P="$TMP/kette mit leer"; mkdir -p "$P/.claude-mind/mind-all.lock"
printf 'L-HEUTE-123456789' > "$P/.claude-mind/mind-all.lock/lauf"; date +%s > "$P/.claude-mind/mind-all.lock/ts"
: > "$P/.claude-mind/analyzed-scopes"
Q="$P/.claude-mind/schritt-quittung.jsonl"
# die EINE alte Zeile vom 04.10. mit Bruch — vor dem Kopf des heutigen Laufs
printf '{"ereignis":"start","skill":"mind-memory","erwartet":"x","ts":"2026-10-04T10:00:00Z","code":"5.140.0","text":"5.139.0","versionsbruch":true}\n' > "$Q"
printf '{"ereignis":"start","skill":"mind-all","erwartet":"x","ts":"%s","code":"v","text":"v","versionsbruch":false,"lauf":"L-HEUTE-123456789"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$Q"
( source "$R/hooks/lib.sh"; MIND_SKILL_VERSION="$(basename "$R")" MIND_LOG_FILE="$TMP/log.txt" \
    mind_schritt_start "$P" mind-update verdichten >/dev/null 2>&1 )
pruef "⛔ die Startzeile von mind-update traegt die Lauf-ID aus dem Lock" \
  "$(tail -1 "$Q" | grep -c '"skill":"mind-update".*"lauf":"L-HEUTE-123456789"')" "1"
B=$( source "$R/hooks/lib.sh"; MIND_LOG_FILE="$TMP/log.txt" mind_schritt_bilanz "$P" --alle 2>&1 )
pruef "⛔ kein VERSIONSBRUCH aus der Zeile vom 04.10." "$(printf '%s\n' "$B" | grep -c 'VERSIONSBRUCH in')" "0"
# GEGENKONTROLLE: ein Bruch IN diesem Lauf wird weiter gemeldet
printf '{"ereignis":"start","skill":"mind-files","erwartet":"x","ts":"%s","code":"5.145.0","text":"5.139.0","versionsbruch":true,"lauf":"L-HEUTE-123456789"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$Q"
B=$( source "$R/hooks/lib.sh"; MIND_LOG_FILE="$TMP/log.txt" mind_schritt_bilanz "$P" --alle 2>&1 )
pruef "GEGENKONTROLLE: ein Bruch in DIESEM Lauf wird gemeldet" "$(printf '%s\n' "$B" | grep -c 'VERSIONSBRUCH in 1 ')" "1"

echo "=== M-G) Veras gesunder Roster mit fuenf Spalten ist STILL ==="
RG="$R/references/rollen_geruest.py"
B=$("$PY" -c "
import sys; sys.path.insert(0, sys.argv[1]); import rollen_geruest as r
t = '''| Rolle | Name | sessionId | Kennung belegt | Tut |
|---|---|---|---|---|
| **manager** | **Otto** | \`11111111-2222-3333-4444-555555555555\` | ja | liest und beauftragt |
| **sync** | **Vera** | \`66666666-7777-8888-9999-000000000000\` | ja | faehrt die Werkzeuge |
'''
B, H = r.spalten_pruefen(t, uo=[], projekt=sys.argv[2])
print(len(B))" "$(win "$R/references")" "$(win "$TMP")")
pruef "⛔ 0 Befunde (vorher vier Fehlalarme)" "$B" "0"
B=$("$PY" -c "
import sys; sys.path.insert(0, sys.argv[1]); import rollen_geruest as r
t = '''| Rolle | Name | sessionId | Tut |
|---|---|---|---|
| **manager** | **Otto** | \`11111111-2222-3333-4444-555555555555\` | liest |
'''
B, H = r.spalten_pruefen(t, uo=['Creator Stimme'], projekt=sys.argv[2])
print(len(B))" "$(win "$R/references")" "$(win "$TMP")")
pruef "GEGENKONTROLLE: Unterordner-Aufbau ohne Ordner-Spalte bleibt ein Befund" "$B" "1"
B=$("$PY" -c "
import sys; sys.path.insert(0, sys.argv[1]); import rollen_geruest as r
t = '''| Rolle | Name | sessionId | Tut | Kennung | Ordner |
|---|---|---|---|---|---|
| **manager** | **Otto** | \`11111111-2222-3333-4444-555555555555\` | liest | ja | gibtsnicht/ |
'''
B, H = r.spalten_pruefen(t, uo=['x'], projekt=sys.argv[2])
print(sum(1 for b in B if 'gibtsnicht' in b))" "$(win "$R/references")" "$(win "$TMP")")
# ⚠ Gegen den alten Stand traefe ein blosses len(B)==1 aus dem FALSCHEN Grund
#   („kennt vier oder fuenf Spalten") — deshalb wird der Inhalt des Befunds geprueft.
pruef "Ordner-Spalte an SECHSTER Stelle wird gelesen (fehlender Ordner = Befund)" "$B" "1"

echo "=== M-J) ein Rohdump ist kein Agentenbericht ==="
P="$TMP/agent mit leer"; mkdir -p "$P/.claude-mind"
agent() {  # $1 = Bereich, $2 = Datei  -> bytes der Ergebniszeile
  ( source "$R/hooks/lib.sh"; export MIND_LOG_FILE="$TMP/log.txt"
    mind_agent_quittung_start "$P" 4 >/dev/null 2>&1
    mind_agent_dispatch "$1" "$P" >/dev/null 2>&1
    mind_agent_ergebnis "$1" --datei "$2" "$P" >/dev/null 2>&1 )
  grep '"ereignis":"ergebnis"' "$P/.claude-mind/agent-quittung.jsonl" | tail -1 | sed -n 's/.*"bytes":\([0-9]*\).*/\1/p'
}
printf '{"parentUuid":"a","type":"user"}\n{"parentUuid":"b","type":"assistant"}\n{"parentUuid":"c","type":"user"}\n' > "$P/dump.md"
pruef "⛔ JSONL-Rohdump -> bytes 0" "$(agent claude-md "$P/dump.md")" "0"
printf '# Bericht\n\n[Datei](docs/x.md) ist veraltet.\n' > "$P/link.md"
printf '[Datei](docs/x.md) — erste Zeile ist ein Link.\nKein JSON.\n' > "$P/link2.md"
pruef "GEGENKONTROLLE: ein echter Bericht zaehlt" "$( [ "$(agent memory "$P/link.md")" -gt 0 ] && echo ja || echo nein)" "ja"
pruef "GEGENKONTROLLE: ein Bericht, der mit einem Markdown-Link BEGINNT, zaehlt" \
  "$( [ "$(agent rules "$P/link2.md")" -gt 0 ] && echo ja || echo nein)" "ja"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
