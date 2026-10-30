#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Der Agenten-Fan-out in Wellen, der Agent schreibt seinen Bericht selbst (v5.162.0, Etappe 63 N3).
#
# ⛔ GEMESSEN 30.10.2026 (Ritas Lauf 20261030-003203): je Bereich vier Schritte (dispatch, Agent, Bericht per
#    Write abgetippt, ergebnis) plus Weck-Turns — mind-update 67 von 161 Schritten. Jetzt: 3 Bloecke + 2 Wellen.
# ⛔ Anton-Entscheidung 30.10.: die Agent-Quittung entsteht UNVERAENDERT — ein leer zurueckkehrender Agent bleibt
#    LEER (`agent-fehlbericht`), nicht „voll". Das prueft Abschnitt 3 — es ist der Grund, warum der Bau erlaubt ist.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$R"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
P="$TMP/projekt mit leer"; mkdir -p "$P/.claude-mind/sampler"
export CLAUDE_CODE_SESSION_ID="aaaa1111-0000-0000-0000-00000000beef"
L="20261030-010000-0000beef"
printf 'docs/x.md\n' > "$P/.claude-mind/sampler/mind-update-ccf.aaaa1111.txt"
Q="$P/.claude-mind/agent-quittung.jsonl"
S() { ( cd "$P" && LAUF="$L" PROJ="$P" CLAUDE_PROJECT_DIR="$P" bash "$R/skills/mind-update/bloecke/agent-schritt.sh" "$@" 2>&1 ); }
bericht() { printf '%s' "$2" > "$P/.claude-mind/agent/$L-mind-update-$1.md"; }
alt() { sed -i 's/"ereignis":"dispatch","bereich":"\([a-z-]*\)","ts":"[^"]*"/"ereignis":"dispatch","bereich":"\1","ts":"2026-10-30T00:00:00Z"/' "$Q"; }
bilanz() { ( . "$R/hooks/lib.sh"; mind_agent_bilanz "$P" 2>/dev/null | head -1 ); }

echo "=== 1) Welle 1: Quittung anlegen, zwei Dispatches, Pfade mit Lauf-ID ==="
A=$(S start claude-md,memory)
pruef "Quittung erwartet 4" "$(grep -c '"erwartet":4' "$Q")" "1"
pruef "zwei Dispatches" "$(grep -c '"ereignis":"dispatch"' "$Q")" "2"
pruef "Bericht-Pfad traegt die Lauf-ID" "$(printf '%s\n' "$A" | grep -c "agent/$L-mind-update-memory.md")" "1"
pruef "⛔ sagt: nicht mit ScheduleWakeup warten" "$(printf '%s\n' "$A" | grep -c 'ScheduleWakeup')" "1"

echo "=== 2) Welle 2: beide Berichte da -> quittiert, naechste Welle dispatcht ==="
alt; bericht claude-md "$(printf 'Befund %.0s' $(seq 1 40))"; bericht memory "$(printf 'Befund %.0s' $(seq 1 40))"
S claude-md,memory rules,custom-context >/dev/null
pruef "zwei Ergebnisse mit Bytes" "$(grep '"ereignis":"ergebnis"' "$Q" | grep -vc '"bytes":0')" "2"
pruef "vier Dispatches" "$(grep -c '"ereignis":"dispatch"' "$Q")" "4"

echo "=== 3) ⛔ ein LEERER Bericht bleibt LEER (agent-fehlbericht), nicht voll ==="
alt; bericht rules "Befund rules $(printf 'x%.0s' $(seq 1 200))"; : > "$P/.claude-mind/agent/$L-mind-update-custom-context.md"
B=$(S rules,custom-context)
pruef "leerer Bericht: Block weist ihn ab (rc 3)" "$(S rules,custom-context >/dev/null; echo $?)" "3"
S custom-context --ohne-bericht >/dev/null
pruef "Bilanz: LEER=1" "$(bilanz | grep -o 'LEER=[0-9]*')" "LEER=1"

echo "=== 4) fehlender Bericht: naechste Welle wird NICHT dispatcht ==="
rm -f "$Q"; rm -rf "${P:?}/.claude-mind/agent"; S start claude-md >/dev/null; alt
pruef "rc 3" "$(S claude-md memory >/dev/null; echo $?)" "3"
pruef "memory NICHT dispatcht" "$(grep -c '"bereich":"memory"' "$Q")" "0"

echo "=== 5) Anti-Burst: drei in einer Welle -> abgewiesen ==="
pruef "rc 2" "$(S start claude-md,memory,rules >/dev/null; echo $?)" "2"

echo "=== 6) ohne Lauf-Kopf: Pfad je Sitzung, nie geteilt ==="
pruef "ohne-lauf-<sid8>" "$( ( cd "$P"; unset LAUF; . "$R/hooks/lib.sh"; mind_agent_bericht_pfad memory "$P" ) | grep -c 'agent/ohne-lauf-aaaa1111-mind-update-memory.md')" "1"

echo "=== 6b) ⛔ Skill im Namen: mind-claudemd und mind-update teilen KEINEN Pfad (Ritas Messlauf 30.10.) ==="
pa=$( ( cd "$P"; . "$R/hooks/lib.sh"; LAUF="$L" mind_agent_bericht_pfad claude-md "$P" mind-claudemd ) )
pb=$( ( cd "$P"; . "$R/hooks/lib.sh"; LAUF="$L" mind_agent_bericht_pfad claude-md "$P" ) )
pruef "verschiedene Pfade" "$([ -n "$pa" ] && [ "$pa" != "$pb" ] && echo ja || echo nein)" "ja"
pruef "⛔ fremder Skillname abgewiesen" "$( ( . "$R/hooks/lib.sh"; mind_agent_bericht_pfad claude-md "$P" ../x >/dev/null 2>&1; echo $? ) )" "2"

echo "=== 7) der Agent darf genau seinen Bericht schreiben ==="
AG="$R/agents/context-analyzer.md"
pruef "Write in tools" "$(sed -n '/^tools:/,/^disallowedTools:/p' "$AG" | grep -c '^  - Write')" "1"
pruef "description sagt: ausser dem eigenen Bericht" "$(grep -c 'Read-only except its own report' "$AG")" "1"

echo "=== 8) ⛔ der default-Analyzer der Einzel-Skills gehoert NICHT in die Quittung (Ritas Messlauf 30.10.) ==="
for s in mind-claudemd mind-memory; do
  pruef "$s sagt es beim Aufruf" "$(grep -c 'Nicht in die Agent-Quittung' "$R/skills/$s/SKILL.md")" "1"
done
rm -f "$Q"; ( . "$R/hooks/lib.sh"; mind_agent_quittung_start "$P" 4 >/dev/null 2>&1 )
H=$( ( . "$R/hooks/lib.sh"; mind_agent_ergebnis claude-md --datei "$P/x.md" "$P" 2>&1 ) )
pruef "Abweis ohne dispatch nennt den Einzel-Skill-Fall" "$(printf '%s\n' "$H" | grep -c 'default-Analyzer eines Einzel-Skills')" "1"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
