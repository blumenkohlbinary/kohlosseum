#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-claudemd Bestands-Pass Teil 1+2 in EINEM Aufruf, selbst quittiert (v5.163.0, Etappe 65 §1.5).
# ⛔ Gemessen 30.10.2026 (Ritas Messlauf): 9–10 Pflichtquittungen je Einzel-Skill von Hand getippt. Die drei
#    Fragen je Stichproben-Eintrag (Teil 3) und die Pass-Quittung mit <n> (Teil 4) bleiben beim Modell.
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
ARGUMENTS="${ARGUMENTS:-}" . "$CLAUDE_PLUGIN_ROOT/skills/mind-claudemd/bloecke/_ziele.sh"   # BEREICH aus Step 1
[ "${BEREICH:-}" = "global" ] && _BZ="--global" || _BZ=""
mind_pass_schritt mind-claudemd mind_kontext_bilanz mind_kontext_bilanz "$PROJ" --vergleichen
mind_pass_schritt mind-claudemd bestandszahlen_kandidaten python "$CLAUDE_PLUGIN_ROOT/references/bestandszahlen_kandidaten.py" "$PROJ" $_BZ
mind_pass_schritt mind-claudemd cleaner_stichprobe python "$CLAUDE_PLUGIN_ROOT/references/cleaner_stichprobe.py" "$PROJ" --skill mind-claudemd "$PROJ/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
