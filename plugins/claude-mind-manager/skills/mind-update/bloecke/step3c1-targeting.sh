#!/usr/bin/env bash
# /mind-update — aus skills/mind-update/SKILL.md ausgelagert (v5.153.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# Existenz-Guards (H3/Skill-Review G): ohne .git kein Scope-Signal, ohne rules-Dir nichts zu targeten.
if [ ! -d .claude/rules ]; then
  echo "kein .claude/rules/ -> 3c.1 gegenstandslos"; SEM_RULES=""; TARGET_MODE="none"
else
  # 1) Größe des gesamten Rules-Satzes — entscheidet, ob Targeting überhaupt nötig ist.
  RULES_KB=$(( $(cat .claude/rules/*.md 2>/dev/null | wc -c) / 1024 ))

  # 2) Commit-Scopes als Targeting-Signal (nur wenn .git). SCOPE bevorzugen (mappt auf Datei-Inhalt).
  KEYS=""
  if [ -d .git ]; then
    STOP='the|and|for|that|with|from|into|als|der|die|das|und|fix|feat|add|new|update'
    KEYS=$(git log --oneline -30 | grep -iE '^[0-9a-f]+ (feat|fix|refactor|perf)(\(|:)' | while read -r line; do
      subj=$(echo "$line" | cut -d' ' -f2-)
      scope=$(echo "$subj" | sed -nE 's/^[a-z]+\(([a-z0-9_-]{3,})\).*/\1/p' | head -1)
      key="${scope:-$(echo "$subj" | tr ' ' '\n' | grep -iE '^[a-z_]{4,}$' | grep -ivE "^($STOP)$" | head -1)}"
      [ -n "$key" ] && echo "$key"
    done | sort -u)
  fi

  # 3) Touched-Map: robuster per-Datei-grep OHNE -r und OHNE -F (crashen zusammen auf Git-Bash/MSYS
  #    bei UTF-8-Rules, verifiziert 2026-07-15). Keys sind regex-safe ([a-z0-9_-]).
  TOUCHED_RULES=$(for key in $KEYS; do for f in .claude/rules/*.md; do grep -li "$key" "$f" 2>/dev/null; done; done | sort -u)

  # 4) Entscheidungsbaum — KEIN stilles 0 (Skill-Review B):
  if [ "$RULES_KB" -lt 160 ]; then
    TARGET_MODE="all"; SEM_RULES=$(ls .claude/rules/*.md)   # klein genug -> alle passen, Targeting unnötig
    echo "Rules-Satz klein (${RULES_KB}KB) -> semantischer Pass: ALLE Rules"
  elif [ -n "$TOUCHED_RULES" ]; then
    TARGET_MODE="targeted"; SEM_RULES="$TOUCHED_RULES"
    echo "Rules groß (${RULES_KB}KB) -> semantischer Pass NUR session-berührte:"; echo "$SEM_RULES"
  else
    TARGET_MODE="unscopable"; SEM_RULES=""
    echo "WARN: Rules groß (${RULES_KB}KB) ABER kein Commit-Scope-Signal (kein .git / keine passenden Scopes)."
    echo "      -> semantischer Rules-Pass NICHT scopebar. Report MUSS das als 'deterministisch-only,"
    echo "         nicht semantisch geprüft' ausweisen + /mind-rules einzeln empfehlen. KEIN stilles 0."
  fi
  echo "=== NICHT im semantischen Pass (nur deterministisch: 3e+3e.2) ==="
  for f in .claude/rules/*.md; do echo "$SEM_RULES" | grep -qxF "$f" || printf "  %s (%s Z.)\n" "$f" "$(wc -l < "$f")"; done
fi
