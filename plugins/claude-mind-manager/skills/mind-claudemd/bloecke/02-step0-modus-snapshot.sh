#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-claudemd — aus skills/mind-claudemd/SKILL.md ausgelagert (v5.154.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
ARGS="${ARGUMENTS:-}"; AUTO_MODE="yes"
echo "$ARGS" | grep -qE '(^|[[:space:]])--(ask|interactive)([[:space:]]|$)' && AUTO_MODE="no"
# ⛔ v5.139.0: der PROBELAUF ist ERSATZLOS entfallen (Nutzer 29.09.2026: „wieso kein
#    richtiger lauf kostet geld", „allgemein keine Probelaeufe mehr … ich will Ergebnisse
#    sehen"). Wer die Flagge noch mitgibt, bekommt einen ABBRUCH und keinen stillen
#    Echtlauf: wer `--dry-run` tippt, erwartet, dass nichts geschrieben wird.
if echo "$ARGS" | grep -qE '(^|[[:space:]])--dry-run([[:space:]]|$)'; then
  echo "ABBRUCH: --dry-run ist entfallen (seit 5.139.0) — es gibt keinen Probelauf mehr." >&2
  echo "         Bitte OHNE die Flagge aufrufen. Der Lauf ist dann ein echter Lauf," >&2
  # ⛔ KEINE Backticks in diesem Text: in doppelten Anfuehrungszeichen FUEHRT BASH AUS, was
  #    zwischen ihnen steht (shell-windows.md). Hier stand "`--ask`" — das haette bei jedem
  #    Abbruch ein "--ask: command not found" erzeugt und das Wort aus der Meldung getilgt.
  echo "         mit Snapshot vorher (Rueckweg). --ask fragt weiterhin vor dem Anwenden." >&2
  exit 2
fi

# Snapshot VOR dem ersten Edit — ausgefuehrter Aufruf, kein Prosa-Versprechen.
# Laeuft dieser Skill innerhalb eines AKTIVEN /mind-all? (C1-Fix: drei Bedingungen, nicht nur
# "Datei existiert" — sonst gilt nach dem ersten /mind-all JEDER spaetere Einzellauf als Kette
# und editiert ohne Snapshot.)
CHAIN="no"; _SC="$PROJ/.claude-mind/analyzed-scopes"
if [ -f "$_SC" ]; then
  _SNAP=$(grep -m1 '^snapshot=' "$_SC" 2>/dev/null | cut -d= -f2-)
  _START=$(grep -m1 '^run_started=' "$_SC" 2>/dev/null | cut -d= -f2)
  _AGE=$(( $(date +%s) - ${_START:-0} ))
  # 1) Snapshot-Pfad eingetragen  2) Verzeichnis existiert wirklich  3) Lauf juenger als 2 h
  [ -n "$_SNAP" ] && [ -d "$_SNAP" ] && [ "$_AGE" -lt 7200 ] && CHAIN="yes"
fi

if [ "$CHAIN" = "no" ]; then
  [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { CLAUDE_PLUGIN_ROOT=$(jq -r '.plugins["claude-mind-manager@kohlosseum"][0].installPath // empty' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null); [ -n "$CLAUDE_PLUGIN_ROOT" ] && { CLAUDE_PLUGIN_ROOT=$(cygpath -u "$CLAUDE_PLUGIN_ROOT" 2>/dev/null || printf '%s' "$CLAUDE_PLUGIN_ROOT"); echo "WARN: CLAUDE_PLUGIN_ROOT war leer — Rueckfall auf installed_plugins.json: $CLAUDE_PLUGIN_ROOT (v5.107.0)" >&2; }; }   # v5.107.0 Rueckfall
  [ -z "$CLAUDE_PLUGIN_ROOT" ] && { echo "ERROR: \$CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 1; }
  source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
  SNAPSHOT=$(mind_snapshot "$PROJ" "pre-claudemd") || {
    echo "ABBRUCH: Snapshot fehlgeschlagen — es wird NICHTS editiert." >&2; exit 1; }
  echo "Snapshot: $SNAPSHOT"
fi

# ⛔ v5.163.0 (Etappe 65 §1.5): der Block quittiert SELBST, mit Artefakt (MANIFEST) — Ritas Messlauf 30.10.2026
#    tippte 9–10 Pflichtquittungen je Einzel-Skill von Hand.
_QS="${SNAPSHOT:-${_SNAP:-}}"
if [ -n "$_QS" ] && [ -f "$_QS/MANIFEST.sha256" ]; then
  mind_schritt mind_snapshot gelaufen --datei "$_QS/MANIFEST.sha256" "$PROJ"
else
  mind_schritt mind_snapshot "fehler:kein-snapshot" -1 "$PROJ"
fi
