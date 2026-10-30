#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-update Step 3.5 — EIN Aufruf je Agentenwelle (v5.162.0, Etappe 63 N3 §1+§3).
#
#   bash agent-schritt.sh start <a>[,<b>]                  Quittung anlegen (3/4), dispatch der ersten Welle
#   bash agent-schritt.sh <fertig>[,<fertig2>] [<naechste>[,<naechste2>]]
#                                                           Ergebnis der fertigen Welle quittieren, naechste dispatchen
#   bash agent-schritt.sh <fertig> --ohne-bericht           Agent ohne tool_result: bytes:0 quittieren (ungeprueft)
#
# ⛔ GEMESSEN 30.10.2026 (Ritas Lauf 20261030-003203): je Bereich VIER Schritte — dispatch, Agent, Bericht per
#    Write abgetippt, ergebnis — dazu Weck-Turns; 16+ Schritte fuer vier Bereiche, jeder bezahlt den ganzen
#    Verlauf (~280k). Jetzt: 3 Bloecke + 2 Wellen; der context-analyzer schreibt seinen Bericht selbst nach
#    `mind_agent_bericht_pfad`. Hoechstens ZWEI je Welle (Anti-Burst, v4.0.1).
# ⛔ Unveraendert: dispatch VOR dem Agentenstart, ergebnis ueber `mind_agent_ergebnis --datei` — eine fehlende
#    oder leere Datei bleibt bytes:0 (LEER, `agent-fehlbericht`), das Hintergrund-Ack und ein Rohdump ebenso.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "ERROR: CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
A="${1:-}"; B="${2:-}"
[ -n "$A" ] || { echo "Aufruf: agent-schritt.sh start <a>[,<b>] | <fertig>[,<f2>] [<naechste>[,<n2>]|--ohne-bericht]" >&2; exit 2; }
liste() { printf '%s\n' "$1" | tr ',' '\n' | sed '/^$/d'; }
anzahl() { liste "$1" | grep -c .; }
[ "$(anzahl "$B")" -le 2 ] && [ "$A" = start -o "$(anzahl "$A")" -le 2 ] \
  || { echo "⛔ hoechstens ZWEI Bereiche je Welle (Anti-Burst, v4.0.1)." >&2; exit 2; }

if [ "$A" = start ]; then
  [ -n "$B" ] || { echo "Aufruf: agent-schritt.sh start <a>[,<b>]" >&2; exit 2; }
  CCF=()
  mapfile -t CCF < "$(mind_sampler_pfad "$PROJ" mind-update-ccf.txt)" 2>/dev/null   # Step 1.5 (v5.153.0)
  if [ "${#CCF[@]}" -eq 0 ] || [ -z "${CCF[0]:-}" ]; then
    [ -f "$PROJ/.claude-mind/agent-quittung.jsonl" ] || mind_agent_quittung_start "$PROJ" 3
    mind_agent_uebersprungen custom-context 0 "$PROJ"
    echo "custom-context: 0 Dateien — uebersprungen und quittiert (3 Bereiche)."
  else
    [ -f "$PROJ/.claude-mind/agent-quittung.jsonl" ] || mind_agent_quittung_start "$PROJ" 4
  fi
else
  RC=0
  while IFS= read -r a; do
    F=$(mind_agent_bericht_pfad "$a" "$PROJ") || exit 2
    if [ "$B" = "--ohne-bericht" ]; then
      mind_agent_ergebnis "$a" --datei "$F" "$PROJ"; echo "$a: ohne Bericht quittiert (bytes:0, ungeprueft)."
      continue
    fi
    if [ ! -s "$F" ]; then
      echo "⛔ $a: kein Bericht unter $F."
      echo "   Hat der Agent ihn nicht geschrieben (aelteres Paket ohne Write): den tool_result WOERTLICH dorthin"
      echo "   legen und diesen Aufruf wiederholen. Kam gar kein tool_result: '$a --ohne-bericht'."
      RC=3; continue
    fi
    mind_agent_ergebnis "$a" --datei "$F" "$PROJ"
    echo "$a: quittiert ($(wc -c < "$F" | tr -d ' ') B)."
  done < <(liste "$A")
  [ "$B" = "--ohne-bericht" ] && exit 0
  [ "$RC" = 0 ] || { echo "⛔ naechste Welle NICHT dispatcht — erst die fehlenden Berichte." ; exit 3; }
fi

if [ -n "$B" ]; then
  while IFS= read -r n; do
    mind_agent_dispatch "$n" "$PROJ" || exit 2
    echo "dispatch $n — Bericht-Pfad fuer den Auftrag: $(mind_agent_bericht_pfad "$n" "$PROJ")"
  done < <(liste "$B")
  echo "Jetzt die Welle starten: $(anzahl "$B") Agent(s) in EINER Nachricht, run_in_background: false."
  echo "⛔ Nicht mit ScheduleWakeup/sleep warten — die Rueckmeldung kommt von selbst."
else
  echo "Alle Bereiche quittiert — weiter mit der Agent-Bilanz."
fi
