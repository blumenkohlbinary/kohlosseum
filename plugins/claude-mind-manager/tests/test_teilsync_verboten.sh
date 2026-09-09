#!/usr/bin/env bash
# Teilsync ist verboten (v5.55.0) — 4 Agents oder gar nichts.
#
# Nutzer-Entscheidung 10.09.2026, woertlich: "ein teilsync soll verboten sein
# keine ausreden wenn ich einen sync haben will immer voll keine ausreden".
#
# ⛔ DER WIDERSPRUCH, DEN DAS AUFLOEST, WAR REAL UND STAND IN DER DOKU:
#    MIND_SYNC_FORCE_TOKENS (800 000) erzwang einen Sync genau an der Grenze,
#    an der MIND_AGENT_HALB_TOKENS (ebenfalls 800 000) ihm null Agents gibt.
#    Der Zwang produzierte den Teilsync, den er verhindern sollte — in
#    `env-vars.md` stand das nebeneinander und war dort als "Absicht" erklaert.
#
# ⭐ FALL 5 IST DER WICHTIGSTE: die Abbruch-Pruefung muss VOR dem Snapshot
#    stehen. Ein Lauf, der ohnehin abbricht, darf nicht vorher eine Sicherung,
#    eine Kettenmarke und eine Agent-Quittung hinterlassen — die Quittung waere
#    danach eine Spur ohne Lauf, und genau daran misst `mind_agent_bilanz`.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }
hat() { case "$3" in *"$2"*) GRUEN=$((GRUEN+1)); echo "  [ok ] $1";;
  *) ROT=$((ROT+1)); echo "  [ROT] $1 — '$2' fehlt";; esac; }

# shellcheck disable=SC1090
. "$R/hooks/lib.sh" 2>/dev/null

mach_transkript() {  # <datei> <tokens>
  printf '{"type":"assistant","message":{"role":"assistant","content":"x","usage":{"input_tokens":%s,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":5}}}\n' \
    "$2" > "$1"
}

P="$TMP/proj"; mkdir -p "$P/.claude-mind"
mach_transkript "$TMP/klein.jsonl" 599999
mach_transkript "$TMP/gross.jsonl" 600000
printf '{"type":"user"}\n{"foo":1}\n' > "$TMP/ohne.jsonl"

echo "=== 1) Die Schwelle ==="
mind_sync_moeglich "$P" "$TMP/klein.jsonl" >/dev/null
pruef "599 999 -> der Lauf faehrt" "0" "$?"
mind_sync_moeglich "$P" "$TMP/gross.jsonl" >/dev/null
pruef "⛔ 600 000 -> ABBRUCH" "1" "$?"

echo
echo "=== 2) ⛔ FAIL-SAFE: keine Messung ist KEIN Abbruch ==="
mind_sync_moeglich "$P" "$TMP/ohne.jsonl" >/dev/null
pruef "Transkript ohne usage -> faehrt" "0" "$?"
mind_sync_moeglich "$P" "$TMP/gibtsnicht.jsonl" >/dev/null
pruef "Transkript fehlt -> faehrt" "0" "$?"
mind_sync_moeglich "" "" >/dev/null
pruef "kein Projekt -> faehrt" "0" "$?"

echo
echo "=== 3) Der Abbruchtext sagt, was der Mensch tun muss ==="
A=$(mind_sync_moeglich "$P" "$TMP/gross.jsonl" 2>&1)
hat "nennt die gemessene Zahl"      "600000" "$A"
hat "nennt die Grenze"              "MIND_AGENT_VOLL_TOKENS" "$A"
hat "sagt, dass NICHT gefahren wird" "faehrt NICHT" "$A"
hat "nennt den Weg (kompaktieren oder neu starten)" "kompaktieren" "$A"
hat "⭐ und dass nichts verloren geht" "geht nichts verloren" "$A"

echo
echo "=== 4) Der Regler wirkt (die Schwelle ist keine Konstante) ==="
MIND_AGENT_VOLL_TOKENS=900000 mind_sync_moeglich "$P" "$TMP/gross.jsonl" >/dev/null
pruef "hochgesetzt -> 600 000 faehrt wieder" "0" "$?"
MIND_AGENT_VOLL_TOKENS=1 mind_sync_moeglich "$P" "$TMP/klein.jsonl" >/dev/null
pruef "heruntergesetzt -> auch 599 999 bricht ab" "1" "$?"

echo
echo "=== 5) ⭐ Das Gate steht VOR dem Snapshot ==="
MA="$R/skills/mind-all/SKILL.md"
_G=$(grep -n 'mind_sync_moeglich "$PROJ" "$MIND_TP"' "$MA" | head -1 | cut -d: -f1)
_S=$(grep -n 'mind_snapshot "$PROJ" "pre-mind-all"' "$MA" | head -1 | cut -d: -f1)
pruef "mind-all ruft mind_sync_moeglich" "ja" "$([ -n "$_G" ] && echo ja || echo nein)"
pruef "mind-all legt einen Snapshot an"  "ja" "$([ -n "$_S" ] && echo ja || echo nein)"
pruef "⭐ das Gate steht VOR dem Snapshot" "ja" \
      "$([ -n "$_G" ] && [ -n "$_S" ] && [ "$_G" -lt "$_S" ] && echo ja || echo nein)"

echo
echo "=== 6) ⛔ Die Zwischenstufe 2 ist WEG ==="
MU="$R/skills/mind-update/SKILL.md"
# ⛔ GEZAEHLT WIRD DIE ZUWEISUNG, NICHT DIE NENNUNG — und diese Zeile ist
#   der Beleg dafuer, dass der Unterschied zaehlt: die erste Fassung fiel
#   an ihrem eigenen Erfolg durch. Der Satz "hier stand `AGENT_MAX=0`, es
#   ist gegenstandslos" ist eine NENNUNG und wurde als Rueckfall gewertet.
#   Dieselbe Verwechslung steht in `env-vars.md` fuer MIND_NOTFALL_TOKENS
#   dokumentiert — sie ist in diesem Projekt jetzt zweimal aufgetreten.
pruef "keine Zuweisung AGENT_MAX=2 mehr" "0" "$(grep -cE '^[[:space:]]*(\*\) *)?AGENT_MAX=2' "$MU")"
pruef "keine Zuweisung AGENT_MAX=0 mehr" "0" "$(grep -cE '^[[:space:]]*(\*\) *)?AGENT_MAX=0' "$MU")"
pruef "AGENT_MAX ist fest 4"  "1" "$(grep -c '^AGENT_MAX=4' "$MU")"
# ⚠ Zwei Vorkommen sind richtig (Waechter + Aufruf); gezaehlt wird die
#   AUFRUFFORM, nicht die Erwaehnung — dieselbe Umstellung wie in
#   test_leitplanke.sh (v5.25.0).
pruef "mind-update ruft das Gate ebenfalls" "1" \
      "$(grep -c 'mind_sync_moeglich "$PROJ"' "$MU")"

echo
echo "=== 7) ⛔ MIND_SYNC_FORCE_TOKENS wird von keinem Hook mehr gelesen ==="
# ⚠ Gezaehlt werden LESEZUGRIFFE, nicht Erwaehnungen: ein Kommentar, der sagt
#   "der Regler ist entfallen", ist kein Leser. Genau diese Verwechslung steht
#   in `env-vars.md` fuer MIND_NOTFALL_TOKENS dokumentiert.
pruef "kein ${MIND_SYNC_FORCE_TOKENS:+}\${MIND_SYNC_FORCE_TOKENS:-} in den Hooks" "0" \
      "$(grep -rl 'MIND_SYNC_FORCE_TOKENS:-' "$R/hooks/" 2>/dev/null | wc -l | tr -d ' ')"
pruef "stop.sh gibt gar kein JSON mehr aus" "0" \
      "$(grep -c 'jq -nc' "$R/hooks/stop.sh")"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
