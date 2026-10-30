#!/usr/bin/env bash
# /mind-update Step 5d — der Bestands-Pass in EINEM Aufruf, selbst quittiert (v5.162.0, Etappe 63 N3 §3).
#
# ⛔ GEMESSEN 30.10.2026 (Ritas Lauf 20261030-003203): Bilanz, Bestandszahlen und Stichprobe wurden einzeln
#    abgetippt und danach einzeln quittiert — je Werkzeug ein bis zwei Schritte, jeder bezahlt den ganzen Verlauf.
#    Jetzt: ein Aufruf, jede Ausgabe als Datei, Quittung mit Artefakt (`mind_schritt … --datei`) — die Form, die
#    die Zeitregel aussticht (v5.135.0). Die drei Fragen je Stichproben-Eintrag beantwortet weiter das Modell.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "ERROR: CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
D="$PROJ/.claude-mind/pass-mind-update"; mkdir -p "$D"

lauf() {  # $1 = Pflichtschritt, Rest = Befehl
  local name="$1" f="$D/$1.txt"; shift
  "$@" > "$f" 2>&1; local rc=$?
  if [ -s "$f" ]; then mind_schritt "$name" gelaufen --datei "$f" "$PROJ"
  else mind_schritt "$name" "fehler:rc$rc-ohne-ausgabe" -1 "$PROJ"; fi
  echo "=== $name (rc $rc, $(wc -c < "$f" | tr -d ' ') B, $f)"
  cat "$f"
}
# 1) PFLICHTZEILE — sie MUSS woertlich in den Self-Check-Block des Berichts.
lauf mind_kontext_bilanz mind_kontext_bilanz "$PROJ" --vergleichen
lauf bestandszahlen_kandidaten python "$CLAUDE_PLUGIN_ROOT/references/bestandszahlen_kandidaten.py" "$PROJ" --global
# 2) Stichprobe: 3 Eintraege, die am laengsten ungeprueft sind (max. 15 je Kettenlauf)
lauf cleaner_stichprobe python "$CLAUDE_PLUGIN_ROOT/references/cleaner_stichprobe.py" "$PROJ" \
     --skill mind-update --verzeichnis "$PROJ/.claude/rules"
echo "=== quittiert: mind_kontext_bilanz bestandszahlen_kandidaten cleaner_stichprobe — NICHT nachtippen."
