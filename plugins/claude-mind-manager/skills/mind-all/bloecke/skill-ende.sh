#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-all Step 2 · 2b + 2 + 3 als EIN Block (v5.175.0, Etappe 68 N1 Schnitt E).
#   bash skill-ende.sh <skill> [<geprueft> <stichprobe>]
# ⭐ In DERSELBEN Nachricht wie das `Write` von .claude-mind/bericht-<skill>.md, direkt dahinter.
#    Ritas Lauf 20261030-225134: das Ende jedes Skills war von Hand getippt (Stichprobe-Quittung,
#    Skill-Quittung, Laufspur, Scope-Marke, Bilanz) — je Skill zwei Schritte der steuernden Sitzung.
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf — mind_block_umgebung leitet PROJ, SCOPES_FILE und LAUF her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
SK="${1:-}"
case "$SK" in
  mind-files) NAECHST="Skill mind-claudemd" ;;
  mind-claudemd) NAECHST="Skill mind-memory" ;;
  mind-memory) NAECHST="Skill mind-rules mit dem Argument \"check migrate\"" ;;
  mind-rules) NAECHST="Skill mind-update" ;;
  mind-update) NAECHST="bash \"\$CLAUDE_PLUGIN_ROOT/skills/mind-all/bloecke/step2.9-kettenmarke.sh\" (Step 2.9)" ;;
  *) echo "skill-ende: unbekannter Skill '$SK' — erwartet mind-files|mind-claudemd|mind-memory|mind-rules|mind-update" >&2; exit 2 ;;
esac
BER="$PROJ/.claude-mind/bericht-$SK.md"
# ⛔ Ohne Bericht keine Quittung: `mind_schritt --datei` auf eine fehlende Datei waere `kein-artefakt` (FORMAL).
if [ ! -s "$BER" ]; then
  echo "skill-ende: $BER fehlt oder ist leer — erst den Bericht mit Write ablegen, dann diesen Block" >&2
  mind_schritt "$SK" "fehler:kein-bericht" -1 "$PROJ"
  exit 1
fi
# Teil 3+4 des Bestands-Passes (v5.164.0): die Zahlen kennt nur das Modell — ohne sie ein Hinweis, keine erfundene Quittung.
if [ -n "${2:-}" ]; then
  python "$CLAUDE_PLUGIN_ROOT/references/cleaner_stichprobe.py" "$PROJ" --quittung --skill "$SK" --geprueft "$2" --stichprobe "${3:-$2}" 2>&1 | tail -2
else
  echo "  Stichprobe: keine Zahlen uebergeben — gab es PRUEFEN-Eintraege, den Block mit <geprueft> <stichprobe> erneut fahren"
fi
mind_schritt "$SK" gelaufen --datei "$BER" "$PROJ"
if [ -n "${SCOPES_FILE:-}" ] && [ -f "$SCOPES_FILE" ]; then
  echo "skill=$SK|$LAUF" >> "$SCOPES_FILE"
  # KEINE rules-Marke: mind-rules dispatcht keinen Agenten (Step 2 Punkt 3).
  case "$SK" in
    mind-claudemd) echo "claude-md=mind-claudemd:default" >> "$SCOPES_FILE" ;;
    mind-memory)   echo "memory=mind-memory:default"      >> "$SCOPES_FILE" ;;
  esac
else
  echo "  ⚠ keine Kettenmarke ($SCOPES_FILE) — Laufspur nicht geschrieben; laeuft hier ein /mind-all?" >&2
fi
mind_schritt_bilanz "$PROJ" 2>&1 | tail -6
echo "WEITER: $NAECHST"
