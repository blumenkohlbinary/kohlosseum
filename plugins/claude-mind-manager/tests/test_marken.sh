#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
# MARKEN (v5.136.0, Etappe 47 §1) — ein Leser greift die MARKE, nie den Satz.
#
# ⛔ DER ANLASS steht in Etappe 46: der FORMAL-Satz wurde um seinen GRUND erweitert
#    („kein pruefbares Artefakt"), und zwei Prueffaelle wurden rot — nicht weil die
#    Zusicherung brach, sondern weil ihr Suchmuster am deutschen Wortlaut hing.
#    Gezaehlt am 26.09.2026: von 8 Lesern in `lib.sh` hingen FUENF am Satz, nicht an
#    einer Marke: `FORMAL: mind-all (kein Kopf-Block`, `FEHLT (= noch nicht quittiert,
#    NICHT tot):`, `^ *FORMAL: mind-(files|…) `, `^ *UNGEPRUEFT: <bereich> `,
#    `^ *FORMAL: <x> .*`. Ein Satz ist fuer Menschen da und darf sich aendern.
#
# ⛔ DIE MARKEN SIND ADDITIV. Kein vorhandener Satz aendert sich um ein Byte — deshalb
#    bleiben die 79 gezaehlten Fundstellen in hooks/, skills/, references/ und tests/
#    gruen, ohne angefasst zu werden. §5 ist die Zusicherung darauf.
#
# §1 FORMAL_SKILLS= nennt genau die Skills der FORMAL-Saetze
# §2 FORMAL_KOPFBLOCK=1 nur mit --alle UND fehlendem Kopf-Block
# §3 FEHLT= neben der Prosa; _mind_fehlt_liste liest die Marke
# §4 UNGEPRUEFT= in mind_agent_bilanz; mind_ungepruef_bilden trifft ueber die Marke
# §5 ⭐ RUECKFALL — ein Bilanz-Text OHNE Marken (alter Wortlaut) bleibt lesbar
# §6 ⭐ RATSCHE — die alten Saetze stehen woertlich noch da
#
# Gegen 5.135.0 GEMESSEN: 10 rot, 12 gruen — §1-§4 rot.
#   §5 und §6 sind dort gruen, und das ist richtig: §5 prueft den Rueckfall, der
#   DER ALTE WEG IST, und §6 prueft, dass die Saetze noch stehen — in 5.135.0 stehen
#   sie ohnehin. Hier stand zuerst „§6 rot“; das war geraten, nicht gefahren.
#
# Aufruf:  CLAUDE_PLUGIN_ROOT=<paket> bash tests/test_marken.sh
set -u
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
# shellcheck disable=SC1090
. "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh" >/dev/null 2>&1
export MIND_SKILL_VERSION="$(basename "$CLAUDE_PLUGIN_ROOT")"
unset MIND_DEBUG_DIR MIND_SCHRITT_MIN_S

OK=0; ROT=0
janein() { if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  [ok ] %s\n' "$1"
           else ROT=$((ROT+1)); printf '  [ROT] %s — erwartet %s, bekommen %s\n' "$1" "$2" "$3"; fi; }

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
zeile_start()   { printf '{"ereignis":"start","skill":"%s","erwartet":"%s","ts":"%s","code":"%s","text":"%s","versionsbruch":false}\n' "$1" "${4:-verdichten}" "$2" "$3" "$3"; }
zeile_schritt() { printf '{"ereignis":"schritt","name":"%s","status":"gelaufen","bytes":50,"quelle":"zahl","ts":"%s"}\n' "$1" "$2"; }
VER=$(basename "$CLAUDE_PLUGIN_ROOT")

echo "== §1  FORMAL_SKILLS= nennt genau die Skills der FORMAL-Saetze =="
T=$(mktemp -d); P="$T/p"; mkdir -p "$P/.claude-mind"; Q="$P/.claude-mind/schritt-quittung.jsonl"
# Fuenf Skills, alle in derselben Sekunde und mit quelle:zahl -> jeder FORMAL
{ zeile_start mind-all "$NOW" "$VER"
  for s in mind-files mind-claudemd mind-memory mind-rules mind-update; do
    zeile_start "$s" "$NOW" "$VER"; zeile_schritt verdichten "$NOW"
  done; } > "$Q"
B=$(mind_schritt_bilanz "$P" --alle 2>/dev/null)
janein "FORMAL_SKILLS= steht in der Bilanz" ja \
  "$(printf '%s\n' "$B" | grep -q '^  FORMAL_SKILLS=' && echo ja || echo nein)"
_S=$(printf '%s\n' "$B" | sed -n 's/^  FORMAL_SKILLS=//p' | head -1 | tr ' ' '\n' | sort | tr '\n' ' ')
# ⚠ VIER, nicht fuenf: beurteilt wird der ABSTAND zum vorherigen Block, und der
#   erste Block hat keinen Vorgaenger. mind-claudemd fehlt deshalb zu Recht — hier
#   stand zuerst eine Fuenf, und das war meine Erwartung, nicht das Verhalten.
janein "   ... genau die vier beurteilbaren Context-Skills, sortiert" \
  "mind-files mind-memory mind-rules mind-update " "$_S"
# ⛔ Die Negativhaelfte: die Zahl in FORMAL= und die Liste muessen zusammenpassen.
#    Ohne sie waere „schreib einfach alle fuenf hin" gruen.
janein "   ... Zahl in FORMAL= deckt sich mit der Laenge der Liste" \
  "$(printf '%s\n' "$B" | sed -n 's/^  FORMAL=//p' | head -1)" \
  "$(printf '%s\n' "$B" | sed -n 's/^  FORMAL_SKILLS=//p' | head -1 | tr ' ' '\n' | grep -c .)"
janein "   ... mind_umfang_bilden liest die Marke: 1/5 echt (5 minus 4 FORMAL)" ja \
  "$(mind_umfang_bilden "$P" 2>/dev/null | grep -q '1/5 echt' && echo ja || echo nein)"
rm -rf "$T"

echo "== §2  FORMAL_KOPFBLOCK=1 nur mit --alle UND fehlendem Kopf-Block =="
T=$(mktemp -d); P="$T/p"; mkdir -p "$P/.claude-mind"; Q="$P/.claude-mind/schritt-quittung.jsonl"
# OHNE mind-all-Startzeile, aber mit einer anderen -> Mischung
{ zeile_start mind-files "$NOW" "$VER"; zeile_schritt verdichten "$NOW"; } > "$Q"
B=$(mind_schritt_bilanz "$P" --alle 2>/dev/null)
janein "kein Kopf-Block: FORMAL_KOPFBLOCK=1" ja \
  "$(printf '%s\n' "$B" | grep -q '^  FORMAL_KOPFBLOCK=1$' && echo ja || echo nein)"
janein "   ... _mind_fehlt_liste liest daraus 'unbekannt' als ersten Block" ja \
  "$(_mind_fehlt_liste "  FORMAL_KOPFBLOCK=1
  FEHLT=audit" | grep -q '^unbekannt:audit$' && echo ja || echo nein)"
# ⛔ Negativhaelfte: MIT Kopf-Block darf die Marke NICHT stehen.
{ zeile_start mind-all "$NOW" "$VER"; zeile_start mind-files "$NOW" "$VER"; zeile_schritt verdichten "$NOW"; } > "$Q"
janein "mit Kopf-Block: keine KOPFBLOCK-Marke" nein \
  "$(mind_schritt_bilanz "$P" --alle 2>/dev/null | grep -q 'FORMAL_KOPFBLOCK' && echo ja || echo nein)"
janein "ohne --alle: keine KOPFBLOCK-Marke" nein \
  "$(mind_schritt_bilanz "$P" 2>/dev/null | grep -q 'FORMAL_KOPFBLOCK' && echo ja || echo nein)"
rm -rf "$T"

echo "== §3  FEHLT= neben der Prosa; _mind_fehlt_liste liest die Marke =="
T=$(mktemp -d); P="$T/p"; mkdir -p "$P/.claude-mind"; Q="$P/.claude-mind/schritt-quittung.jsonl"
# zwei Pflichtschritte erwartet, einer quittiert
{ zeile_start mind-rules "$NOW" "$VER" "cleaner_duplikate audit"
  zeile_schritt audit "$NOW"; } > "$Q"
B=$(mind_schritt_bilanz "$P" 2>/dev/null)
janein "FEHLT= steht in der Bilanz" ja \
  "$(printf '%s\n' "$B" | grep -q '^  FEHLT=' && echo ja || echo nein)"
janein "   ... nennt den nicht quittierten Schritt" ja \
  "$(printf '%s\n' "$B" | grep -q '^  FEHLT=.*cleaner_duplikate' && echo ja || echo nein)"
janein "   ... und NICHT den quittierten" nein \
  "$(printf '%s\n' "$B" | grep -q '^  FEHLT=.*audit' && echo ja || echo nein)"
janein "_mind_fehlt_liste ueber die Marke allein (ohne Prosa)" "mind-rules:cleaner_duplikate" \
  "$(_mind_fehlt_liste '  FEHLT= mind-rules/cleaner_duplikate')"
rm -rf "$T"

echo "== §4  UNGEPRUEFT= in mind_agent_bilanz =="
T=$(mktemp -d); P="$T/p"; mkdir -p "$P/.claude-mind"
_disp() { printf '{"ereignis":"dispatch","bereich":"%s","ts":"%s"}\n' "$1" \
          "$(date -u -d '-120 seconds' +%Y-%m-%dT%H:%M:%SZ)" >> "$P/.claude-mind/agent-quittung.jsonl"; }
_erg()  { local f="$P/.claude-mind/agent-$1.md"
          head -c "$2" /dev/zero | tr '\0' x > "$f"
          mind_agent_ergebnis "$1" --datei "$f" "$P" 2>/dev/null; }
mind_agent_quittung_start "$P" 4 >/dev/null 2>&1
_disp claude-md; _erg claude-md 4096
_disp memory;    _erg memory 0          # leer
_disp rules                             # stumm
_disp custom-context; _erg custom-context 800
A=$(mind_agent_bilanz "$P" 2>/dev/null)
janein "UNGEPRUEFT= steht in der Bilanz" ja \
  "$(printf '%s\n' "$A" | grep -q '^  UNGEPRUEFT=' && echo ja || echo nein)"
_U=$(printf '%s\n' "$A" | sed -n 's/^  UNGEPRUEFT=//p' | head -1 | tr ' ' '\n' | sort | tr '\n' ' ')
janein "   ... genau die beiden kranken Bereiche" "memory rules " "$_U"
# ⛔ Negativhaelfte, dieselbe wie in test_quittung.sh: die GESUNDEN duerfen nicht drinstehen.
#    Ohne sie waere „melde alles als UNGEPRUEFT" gruen.
janein "   ... claude-md NICHT in der Marke" nein \
  "$(printf '%s\n' "$A" | grep -q '^  UNGEPRUEFT=.*claude-md' && echo ja || echo nein)"
janein "   ... custom-context NICHT in der Marke" nein \
  "$(printf '%s\n' "$A" | grep -q '^  UNGEPRUEFT=.*custom-context' && echo ja || echo nein)"
rm -rf "$T"

echo "== §5  ⭐ RUECKFALL: ein Bilanz-Text OHNE Marken bleibt lesbar =="
# ⛔ Das ist die Zusicherung darauf, dass der Umbau ADDITIV ist. Ein gespeicherter
#    Bericht aus 5.135.0 und aelter traegt keine Marke — er muss weiter geparst werden,
#    sonst waere jeder alte Merker still unlesbar geworden.
janein "FEHLT nur als Prosa -> trotzdem erkannt" "mind-rules:cleaner_duplikate" \
  "$(_mind_fehlt_liste '  ⛔ FEHLT (= noch nicht quittiert, NICHT tot): mind-rules/cleaner_duplikate')"
janein "Kopf-Block nur als Prosa -> trotzdem 'unbekannt'" ja \
  "$(_mind_fehlt_liste '  FORMAL: mind-all (kein Kopf-Block — Bilanz ueber die ganze Datei, nicht ueber diesen Lauf)
  ⛔ FEHLT (= noch nicht quittiert, NICHT tot): audit' | grep -q '^unbekannt:audit$' && echo ja || echo nein)"
# ⛔ Und die Gegenprobe, die TREFFEN MUSS: ohne FEHLT-Angabe kommt NICHTS zurueck —
#    sonst waere „gib immer etwas zurueck" gruen und beide Faelle oben wertlos.
janein "kein FEHLT im Text -> leere Rueckgabe" 0 \
  "$(_mind_fehlt_liste '  FORMAL=1' | grep -c .)"

echo "== §6  ⭐ RATSCHE: die alten Saetze stehen woertlich noch da =="
# ⛔ Wer eine Marke einbaut, ist versucht, die Prosa danach „aufzuraeumen". Genau das
#    waere der Bruch, den dieser Bau verhindern soll: 79 Fundstellen greppen die Saetze.
L="$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
janein "Satz 'FEHLT (= noch nicht quittiert, NICHT tot):' unveraendert" ja \
  "$(grep -q 'FEHLT (= noch nicht quittiert, NICHT tot):' "$L" && echo ja || echo nein)"
janein "Satz 'FORMAL: mind-all (kein Kopf-Block' unveraendert" ja \
  "$(grep -q 'FORMAL: mind-all (kein Kopf-Block' "$L" && echo ja || echo nein)"
janein "Zeile 'UNGEPRUEFT: \${bereich} (' unveraendert" ja \
  "$(grep -q 'UNGEPRUEFT: ${bereich} (' "$L" && echo ja || echo nein)"

echo
echo "gruen: $OK   rot: $ROT"
[ "$ROT" -eq 0 ]
