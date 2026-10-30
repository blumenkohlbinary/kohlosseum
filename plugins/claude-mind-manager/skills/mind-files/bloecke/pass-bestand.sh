#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-files Bestands-Pass Teil 1+2 in EINEM Aufruf, selbst quittiert (v5.163.0, Etappe 65 §1.5).
# ⛔ Gemessen 30.10.2026 (Ritas Messlauf): 9–10 Pflichtquittungen je Einzel-Skill von Hand getippt. Die drei
#    Fragen je Stichproben-Eintrag (Teil 3) und die Pass-Quittung mit <n> (Teil 4) bleiben beim Modell.
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
mind_pass_schritt mind-files mind_kontext_bilanz mind_kontext_bilanz "$PROJ" --vergleichen
mind_pass_schritt mind-files bestandszahlen_kandidaten python "$CLAUDE_PLUGIN_ROOT/references/bestandszahlen_kandidaten.py" "$PROJ"
mind_pass_schritt mind-files cleaner_stichprobe python "$CLAUDE_PLUGIN_ROOT/references/cleaner_stichprobe.py" "$PROJ" --skill mind-files --verzeichnis "$PROJ/.claude/rules"
