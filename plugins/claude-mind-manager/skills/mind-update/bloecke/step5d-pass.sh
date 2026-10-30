#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-update Step 5d — der Bestands-Pass in EINEM Aufruf, selbst quittiert (v5.162.0, Etappe 63 N3 §3).
#
# ⛔ GEMESSEN 30.10.2026 (Ritas Lauf 20261030-003203): Bilanz, Bestandszahlen und Stichprobe wurden einzeln
#    abgetippt und danach einzeln quittiert — je Werkzeug ein bis zwei Schritte, jeder bezahlt den ganzen Verlauf.
#    Jetzt: ein Aufruf, jede Ausgabe als Datei, Quittung mit Artefakt (`mind_schritt … --datei`) — die Form, die
#    die Zeitregel aussticht (v5.135.0). Die drei Fragen je Stichproben-Eintrag beantwortet weiter das Modell.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "ERROR: CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# Teil 1+2 ueber mind_pass_schritt (lib.sh, v5.163.0) — dieselbe Funktion wie in den vier Einzel-Skills.
mind_pass_schritt mind-update mind_kontext_bilanz mind_kontext_bilanz "$PROJ" --vergleichen
mind_pass_schritt mind-update bestandszahlen_kandidaten python "$CLAUDE_PLUGIN_ROOT/references/bestandszahlen_kandidaten.py" "$PROJ" --global
mind_pass_schritt mind-update cleaner_stichprobe python "$CLAUDE_PLUGIN_ROOT/references/cleaner_stichprobe.py" "$PROJ" --skill mind-update --verzeichnis "$PROJ/.claude/rules"
echo "=== quittiert: mind_kontext_bilanz bestandszahlen_kandidaten cleaner_stichprobe — diese drei NICHT nachtippen."
mind_pass_offen mind-update   # v5.164.0: Teil 3+4 bleiben beim Modell — die Zeile nennt den Aufruf
