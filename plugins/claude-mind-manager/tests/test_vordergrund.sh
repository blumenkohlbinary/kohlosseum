#!/usr/bin/env bash
# =============================================================================
#  VORDERGRUND-DISPATCH + QUITTUNG PER DATEI  (NEU v5.94.0)
# =============================================================================
#
# ⛔ WOZU. Gemessen 10.09.2026 (docs/plugin/rueckkanal-messung.md): kein Skill setzt
#    `run_in_background`, die Werkzeug-Vorgabe ist Hintergrund. Der tool_result ist
#    dann nur ein Ack; getrennte Tool-Calls serialisieren nichts (vier Agenten
#    gleichzeitig bei "sequenziellen" Aufrufen), und 5 von 8 Ergebnissen kamen nie
#    an — die Quittung trug trotzdem `bytes:800` (geschaetzt), die Bilanz sagte 4/4.
#
# ⭐ Zwei Zusicherungen (Anton, 11.09.2026, nils-etappe-5.md):
#    1  jeder Agent-Dispatch in mind-update / mind-claudemd / mind-memory (+ der
#       project-scanner in mind-files) traegt `run_in_background: false` — TEXT-GATE
#    2  die Quittung luegt nie mit Bytes: `--datei` misst eine Datei, die es gibt,
#       oder schreibt 0 — nie einen Schaetzwert
#    Gegenprobe gegen v5.93.0: dort fehlt beides (beim Bau gefahren: 17 von 22 rot).
# =============================================================================
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$R"
[ -f "$R/hooks/lib.sh" ] || { echo "ABBRUCH: lib.sh fehlt"; exit 2; }
# shellcheck disable=SC1090
. "$R/hooks/lib.sh" >/dev/null 2>&1

OK=0; ROT=0
janein() {
  if [ "$2" = "$3" ]; then printf '    OK   %-64s ist=%s\n' "$1" "$3"; OK=$((OK + 1))
  else printf '    FEHL %-64s ist=%-10s soll=%s\n' "$1" "$3" "$2"; ROT=$((ROT + 1)); fi
}
mind() { if [ "$3" -ge "$2" ] 2>/dev/null; then printf '    OK   %-64s ist=%s\n' "$1" "$3"; OK=$((OK + 1))
  else printf '    FEHL %-64s ist=%-10s soll>=%s\n' "$1" "$3" "$2"; ROT=$((ROT + 1)); fi; }

echo "=============================================================================="
echo "  1) TEXT-GATE: jeder Dispatch traegt run_in_background: false"
echo "=============================================================================="
# Erwartung = Zahl der Dispatch-Stellen je Skill (Launch/Dispatch-Zeilen + der
# Aufruf-Kasten in mind-update). Ein neuer Dispatch ohne die Marke faellt hier auf,
# weil die Marke je Stelle steht, nicht einmal je Datei.
for s in mind-update:2 mind-claudemd:2 mind-memory:1 mind-files:1; do
  n="${s##*:}"; s="${s%%:*}"; f="$R/skills/$s/SKILL.md"
  ist=$(grep -c 'run_in_background: false' "$f" 2>/dev/null)
  mind "$s: mindestens $n Stellen mit run_in_background: false" "$n" "${ist:-0}"
  janein "$s: keine Stelle mit run_in_background: true" 0 "$(grep -c 'run_in_background: true' "$f" 2>/dev/null)"
done
# Die Dispatch-Zeilen selbst: jede "Launch **context-analyzer**"- bzw.
# "Dispatch **project-scanner**"-Zeile nennt die Marke IN DERSELBEN Zeile oder der
# Klammer dahinter — hier ueber ein Fenster von 3 Zeilen geprueft.
for s in mind-claudemd mind-memory mind-files; do
  f="$R/skills/$s/SKILL.md"
  fehl=0
  while IFS= read -r ln; do
    [ -n "$ln" ] || continue
    if ! sed -n "${ln},$((ln + 2))p" "$f" | grep -q 'run_in_background: false'; then fehl=$((fehl + 1)); fi
  done <<EOF
$(grep -nE '^(Launch \*\*context-analyzer\*\*|Dispatch \*\*project-scanner\*\*)' "$f" | cut -d: -f1)
EOF
  janein "$s: jede Launch/Dispatch-Zeile traegt die Marke im 3-Zeilen-Fenster" 0 "$fehl"
done
janein "mind-update: der Aufruf-Kasten nennt subagent_type UND die Marke" ja \
  "$(grep -q 'subagent_type: "claude-mind-manager:context-analyzer", run_in_background: false' "$R/skills/mind-update/SKILL.md" && echo ja || echo nein)"
janein "mind-update: die Quittung im Skill-Text laeuft ueber --datei" ja \
  "$(grep -q 'mind_agent_ergebnis "<bereich>" --datei' "$R/skills/mind-update/SKILL.md" && echo ja || echo nein)"
janein "mind-update: die alte wc-c-Form steht nicht mehr im Text" 0 \
  "$(grep -c "printf '%s' \"\$RUECKGABE\" | wc -c" "$R/skills/mind-update/SKILL.md")"
janein "mind-memory: 'While the agent runs' ist weg (Hintergrund-Annahme)" 0 \
  "$(grep -c 'While the agent runs' "$R/skills/mind-memory/SKILL.md")"

echo "=============================================================================="
echo "  2) QUITTUNG: --datei misst die Datei, fehlende Datei = 0"
echo "=============================================================================="
T=$(mktemp -d "${TMPDIR:-/tmp}/vgXXXXXX") || exit 2
P="$T/proj"; mkdir -p "$P/.claude-mind"
Q="$P/.claude-mind/agent-quittung.jsonl"
mind_agent_quittung_start "$P" 2
printf 'abcdefghij' > "$P/.claude-mind/agent-claude-md.md"      # 10 Byte
mind_agent_dispatch "claude-md" "$P"
mind_agent_ergebnis "claude-md" --datei "$P/.claude-mind/agent-claude-md.md" "$P"
janein "--datei: bytes = Dateigroesse (10)" ja "$(grep -q '"bereich":"claude-md","bytes":10,' "$Q" && echo ja || echo nein)"
janein "   ... und quelle:datei steht dabei" ja "$(grep -q '"bytes":10,"quelle":"datei"' "$Q" && echo ja || echo nein)"
mind_agent_dispatch "memory" "$P"
mind_agent_ergebnis "memory" --datei "$P/.claude-mind/gibt-es-nicht.md" "$P"
janein "⛔ --datei auf fehlende Datei: bytes=0, kein Schaetzwert" ja "$(grep -q '"bereich":"memory","bytes":0,"quelle":"datei"' "$Q" && echo ja || echo nein)"
janein "   ... die Bilanz fuehrt memory als UNGEPRUEFT" ja \
  "$(mind_agent_bilanz "$P" 2>/dev/null | grep -q 'UNGEPRUEFT: memory' && echo ja || echo nein)"
janein "   ... Zeile 1: DISPATCH=2 ERGEBNIS=2 LEER=1" "DISPATCH=2 ERGEBNIS=2 LEER=1 STUMM=0" \
  "$(mind_agent_bilanz "$P" 2>/dev/null | head -1)"
# Die Zahlform bleibt (Prueffaelle) und ist als solche gekennzeichnet.
mind_agent_ergebnis "rules" 4096 "$P"
janein "Zahlform bleibt erlaubt und traegt quelle:zahl" ja "$(grep -q '"bereich":"rules","bytes":4096,"quelle":"zahl"' "$Q" && echo ja || echo nein)"
janein "   ... Projekt-Argument an Position 4 bei --datei wird gelesen (Quittung liegt im Projekt)" 3 \
  "$(grep -c '"ereignis":"ergebnis"' "$Q")"
rm -rf "$T"

echo "=============================================================================="
echo "  3) TURN-LIMIT: Fortsetzung per SendMessage, nie ein neuer Agent (v5.96.0)"
echo "=============================================================================="
# Gemessen 12.09.2026 (Rita): zwei blockierende Agenten trafen das 20-Turn-Limit vor dem
# Bericht; SendMessage {to: <agentId>} brachte beide zum vollstaendigen Bericht. Ein neuer
# Agent-Aufruf waere ein zweiter Agent gegen dieselbe Grenze. Im Desktop-Reiter ist das
# Werkzeug verzoegert — der Kasten muss ToolSearch select:SendMessage nennen.
for s in mind-update mind-claudemd mind-memory mind-files mind-all; do
  f="$R/skills/$s/SKILL.md"
  mind "$s: nennt SendMessage {to: <agentId>} als Fortsetzung" 1 "$(grep -c 'SendMessage {to: <agentId>' "$f")"
  mind "$s: nennt ToolSearch select:SendMessage" 1 "$(grep -c 'ToolSearch select:SendMessage' "$f")"
done
# Die Fortsetzung steht an JEDER Dispatch-Stelle, nicht irgendwo in der Datei: im Fenster
# von 12 Zeilen um jede Launch-/Dispatch-Zeile und den Aufruf-Kasten. Beim Bau gefunden:
# mind-claudemd hat ZWEI Kaesten, der project-scanner-Kasten fehlte beim ersten Schnitt.
for s in mind-update mind-claudemd mind-memory mind-files; do
  f="$R/skills/$s/SKILL.md"
  fehl=0; n=0
  while IFS= read -r ln; do
    [ -n "$ln" ] || continue
    n=$((n + 1)); von=$((ln - 12)); [ "$von" -lt 1 ] && von=1
    if ! sed -n "${von},$((ln + 12))p" "$f" | grep -q 'SendMessage {to: <agentId>'; then fehl=$((fehl + 1)); fi
  done <<EOF
$(grep -nE '^(Launch \*\*context-analyzer\*\*|Dispatch \*\*project-scanner\*\*|Agent\(subagent_type)' "$f" | cut -d: -f1)
EOF
  mind "$s: mindestens eine Dispatch-Stelle gefunden" 1 "$n"
  janein "$s: SendMessage-Satz an jeder der $n Dispatch-Stellen (Fenster 12 Zeilen)" 0 "$fehl"
done

echo
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
