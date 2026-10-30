#!/usr/bin/env bash
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"; export CLAUDE_PLUGIN_ROOT   # v5.163.0: die Desktop-Bash setzt sie nicht (Ritas Lauf 30.10.)
# /mind-update — aus skills/mind-update/SKILL.md ausgelagert (v5.153.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
# Python-Helper extrahiert relevante Events aus aktueller JSONL
# (gleicher Code wie mind-compact Step 3, hier zur Wiederverwendung)
# --- QUELLEN-WAHL (NEU v5.1.0): geretteter Chat schlaegt Live-Sampling ---
# Nach einer Kompaktierung enthaelt das Live-Transkript nur noch die Zusammenfassung.
# Der PreCompact-Hook hat den VOLLEN Chat vorher nach .claude-mind/rescued/ gerettet —
# DAS ist dann die richtige Quelle. Ohne diese Wahl wuerde der Knowledge-Sync nach jeder
# Kompaktierung auf Resten arbeiten und genau das verpassen, wofuer er da ist.
# v5.2.1: Vorrang hat der Zeiger aus der offenen Schuld (OPEN) — er nennt genau die Rettung,
# fuer die der Sync noch aussteht. Fehlt OPEN (aeltere Version): neueste Datei per Zeitstempel.
_MU_OPEN="$PROJ/.claude-mind/rescued/OPEN"
# ⛔ v5.57.0: EINE Stelle, und sie liegt in `lib.sh`. Hier stand ein Halbfix
#    aus v5.4.1: das Sammeln war auf mehrere Zeilen umgestellt, die
#    Einzeldatei-Pruefung darunter nicht. `[ ! -f "$RESCUED" ]` auf einen
#    mehrzeiligen Text ist immer wahr — bei ZWEI oder mehr Rettungen wurde die
#    Liste geleert und der Rueckfall nahm die juengste Datei im Ordner.
#    GEMESSEN mit drei Rettungen: EINE kam an. Die Doku behauptete seit v5.4.1
#    das Gegenteil, und niemand hatte es je nachgestellt.
RESCUED_ALLE=$(mind_rettungen "$PROJ")
RESCUED_N=$(printf '%s' "$RESCUED_ALLE" | grep -c . 2>/dev/null)
case "$RESCUED_N" in ''|*[!0-9]*) RESCUED_N=0 ;; esac
# Die JUENGSTE ist die Leitrettung fuer Zaehlungen und Meldungen; gespeist
# werden die Agents mit ALLEN (siehe unten).
RESCUED=$(printf '%s' "$RESCUED_ALLE" | tail -1)

# ⛔ FIX v5.2.2 — hier stand ein ENTWEDER-ODER, und das war ein Konstruktionsfehler.
# Die Rettung enthaelt per Definition nur, was VOR der Kompaktierung war. Alles, was danach
# gearbeitet wird, steht ausschliesslich im Live-Transkript. Wer nur die Rettung nimmt, ist
# blind fuer die juengste Arbeitsphase — und genau die ist der Grund, warum der Stop-Hook den
# Lauf ueberhaupt erzwingt.
# BELEGT am 2026-08-16 im eigenen Projekt: die Rettung endete 17:40:15, der gesamte
# v5.2.1-Bau lag danach. Der rules-Agent fand NULL Treffer fuer "stop.sh", "OPEN",
# "Flut-Sperre", "listeverbesserungen" — er konnte sie nicht finden, sie waren nicht drin.
# Der Sync haette die Arbeit, wegen der er lief, komplett verpasst.
# Deshalb jetzt: BEIDE Quellen, wenn beide da sind.
if [ -n "$RESCUED" ] && [ -s "$RESCUED" ]; then
  SESSION_SOURCE="gerettet+live"
  # NUR ZAEHLEN, NICHT LESEN (Kontext-Flut-Sperre v5.2.1)
  echo "Session-Quelle: gerettet -> $RESCUED_N Rettung(en), aelteste zuerst:"
  printf '%s\n' "$RESCUED_ALLE" | while IFS= read -r _r; do
    [ -n "$_r" ] || continue
    echo "    $_r ($(grep -c '^## \[' "$_r") Beitraege)"
    # v5.160.0 (Etappe 62): das Verlaufsbuch ist die ERSTE Quelle, die Rettung der Rueckfall
    _vb=$(mind_verlauf_fuer "$PROJ" "$_r") && echo "      -> Verlaufsbuch (zuerst lesen): $_vb  — Abschnitt rettung=$(basename "${_r%%_*}")"
  done
  # ⛔ ALLE Rettungen gehen an die Agents, nicht nur die juengste. Bei
  #    mehreren Sitzungen im selben Ordner gehoert jede einer anderen — wer
  #    nur die juengste nimmt, synct eine Sitzung und verliert die anderen.
  echo "                + live    -> Sampler ueber das laufende Transkript (deckt die Zeit NACH der Rettung ab)"
else
  SESSION_SOURCE="live"
  echo "Session-Quelle: live (kein geretteter Chat vorhanden)"
fi

SAMPLER="$CLAUDE_PLUGIN_ROOT/references/session_sampler.py"   # v5.0.0: ausgeliefert, KEIN Heredoc
# Frueher wurde das Skript zur Laufzeit per Heredoc nach /tmp geschrieben — auf Windows/Git-Bash
# unzuverlaessig (Pfade mit '&', Leerzeichen, Umlauten). Jetzt liegt es im Plugin.
[ -f "$SAMPLER" ] || { echo "ERROR: session_sampler.py fehlt: $SAMPLER" >&2; exit 1; }

# cygpath ist Pflicht (Windows-Pfade fuer den Python-Aufruf)
command -v cygpath >/dev/null 2>&1 || { echo "ERROR: cygpath nicht verfuegbar" >&2; exit 1; }
SAMPLER_WIN=$(cygpath -w "$SAMPLER")

# JSONL der aktuellen Session finden (Slug via lib.sh)
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { CLAUDE_PLUGIN_ROOT=$(jq -r '.plugins["claude-mind-manager@kohlosseum"][0].installPath // empty' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null); [ -n "$CLAUDE_PLUGIN_ROOT" ] && { CLAUDE_PLUGIN_ROOT=$(cygpath -u "$CLAUDE_PLUGIN_ROOT" 2>/dev/null || printf '%s' "$CLAUDE_PLUGIN_ROOT"); echo "WARN: CLAUDE_PLUGIN_ROOT war leer — Rueckfall auf installed_plugins.json: $CLAUDE_PLUGIN_ROOT (v5.107.0)" >&2; }; }   # v5.107.0 Rueckfall
[ -z "$CLAUDE_PLUGIN_ROOT" ] && { echo "ERROR: \$CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 1; }
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung   # v5.152.0: Werte frueherer Bloecke sind hier leer
SLUG=$(hash_project_dir)
PROJECTS_DIR="$HOME/.claude/projects/$SLUG"
# ⛔ v5.69.0: HIER STAND EIN RUECKFALL AUF DAS NEUESTE PROJEKT.
#    `[ ! -d "$PROJECTS_DIR" ] && PROJECTS_DIR=$(ls -td .../projects/*/ | head -1)`
#    Fehlte der Slug-Ordner, schob er IRGENDEIN anderes Projekt unter — und
#    der Sync haette den Chat eines FREMDEN PROJEKTS als Quelle genommen.
#    ⭐ Nachgestellt 10.09.2026: 25 Projekt-Ordner lagen dort, gewaehlt wurde
#       der nach Aenderungszeit juengste. `mind_transkript_pfad` faengt das
#       NICHT — sie rechnet ihren Slug selbst, kommt leer zurueck, und der
#       Rueckfall las dann aus dem fremden Ordner.
#
# ⛔ STREICHEN FUEGT KEIN VERHALTEN HINZU. Der Abbruch steht schon weiter
#    unten (`kein Session-JSONL` -> exit 1); der Rueckfall hat ihn nur
#    verhindert. ⭐ Ein ausgefallener Lauf hinterlaesst NICHTS, ein falsch
#    gespeister hinterlaesst FALSCHES.
#
# ⚠ Der Ausloeser ist KEIN kaputter Slug: `slug_regression.py` bestand alle
#   12 Faelle, und live trafen 3 von 3 echten Projekten. Es ist ein Projekt,
#   in dem NIE eine Sitzung lief — dort gibt es nichts zu syncen, und der
#   Abbruch ist die richtige Antwort, nicht die harte.
if [ ! -d "$PROJECTS_DIR" ]; then
  echo "ABBRUCH: kein Transkript-Ordner fuer dieses Projekt." >&2
  echo "  erwartet: $PROJECTS_DIR" >&2
  echo "  Das heisst: in diesem Projekt lief noch nie eine Claude-Sitzung," >&2
  echo "  also gibt es auch nichts zu syncen. ⛔ KEIN kaputter Slug — nicht" >&2
  echo "  danach suchen. Frueher wurde hier ein FREMDES Projekt untergeschoben." >&2
  exit 1
fi
# ⛔ v5.68.0: NICHT `ls -t | head -1`. Das ist die nach AENDERUNGSZEIT
#    juengste Datei — bei mehreren Rollen im selben Ordner also die
#    Sitzung, die GERADE schreibt. ⚠ Gemessen 10.09.2026: 17 Transkripte,
#    drei Rollen. Die syncende Sitzung schreibt waehrend ihres Laufs am
#    wenigsten — sie verliert dieses Rennen fast immer.
#
# ⭐ `mind_transkript_pfad` tut seit v5.66.0 genau das Richtige: sie
#    adressiert `$CLAUDE_CODE_SESSION_ID.jsonl` direkt. Der Griff hier war
#    ein NACHBAU davon — Klasse `instrument-nachgebaut`, 9 Vorkommen.
#
# ⛔ DER RUECKFALL MELDET SICH (Auflage). Ein stiller Fehlgriff darf nicht
#    wie ein richtiger Griff aussehen: greift die Kennung nicht, steht das
#    im Bericht, statt lautlos eine fremde Sitzung zu analysieren.
JSONL=$(mind_transkript_pfad "${PROJ:-$(mind_projekt_wurzel)}" 2>/dev/null)
_JQUELLE=kennung
if [ -z "$JSONL" ] || [ ! -f "$JSONL" ]; then
  JSONL=$(ls -t "$PROJECTS_DIR"/*.jsonl 2>/dev/null | grep -v '/subagents/' | head -1)
  _JQUELLE=rueckfall
elif [ -z "${CLAUDE_CODE_SESSION_ID:-}" ] \
     || [ "$JSONL" != "$PROJECTS_DIR/$CLAUDE_CODE_SESSION_ID.jsonl" ]; then
  # ⚠ Ein Treffer, der NICHT aus der eigenen Kennung stammt (Hook-Vorgabe
  #   oder die alte cwd-Heuristik), ist ebenfalls ein Rueckfall — er kann
  #   richtig sein, belegt ist er nicht.
  _JQUELLE=rueckfall
fi
if [ "$_JQUELLE" = rueckfall ]; then
  echo "⚠ TRANSKRIPT ueber den RUECKFALL gewaehlt, nicht ueber die eigene Kennung."
  echo "  Gewaehlt: $(basename "${JSONL:-(nichts)}")"
  echo "  CLAUDE_CODE_SESSION_ID: ${CLAUDE_CODE_SESSION_ID:-(leer)}"
  echo "  ⛔ Bei mehreren Sitzungen im selben Ordner kann das eine FREMDE sein."
  echo "     Das gehoert in den Bericht — nicht verschweigen."
fi
[ -z "$JSONL" ] && { echo "ERROR: kein Session-JSONL in $PROJECTS_DIR" >&2; exit 1; }
JSONL_WIN=$(cygpath -w "$JSONL")

# Python-Path
if [ -x ".venv/Scripts/python.exe" ]; then PYTHON=".venv/Scripts/python.exe"
elif command -v python3 &>/dev/null; then PYTHON="python3"
else PYTHON="python"; fi

# ⛔ v5.126.0 (Etappe 38 §2): JE SITZUNG, IM PROJEKT — nicht mehr fest /tmp/mind_update_session.json.
#    Der feste Pfad kollidierte zwischen gleichzeitigen Sitzungen (Creator 16.09.2026) und war
#    aus der Agent-Sandbox nicht erreichbar (17./18.09.2026, memory-Agent). Aufraeumen: Step 6.
SESSION_SAMPLE_BASH=$(mind_sampler_pfad "$PROJ" mind-update)     # <PROJ>/.claude-mind/sampler/mind-update.<sid>.json
SESSION_SAMPLE_WIN=$(cygpath -w "$SESSION_SAMPLE_BASH")
# ⛔ v5.161.0 (Etappe 63 N1): FENSTER seit dem letzten Sync bis zum Laufbeginn. Ohne es schnitt der Sampler an
#    der letzten GETIPPTEN /mind-all-Marke — in Ritas Sitzung vom 10.09. — und sah 0 Ereignisse des Zeitraums.
_VON=$(sed -n 's/^utc=//p' "$PROJ/.claude-mind/rescued/letzter-sync" 2>/dev/null | tail -1)
_BIS=""; _LTS=$(cat "$PROJ/.claude-mind/mind-all.lock/ts" 2>/dev/null)
case "$_LTS" in ''|*[!0-9]*) ;; *) _BIS=$(date -u -d "@$_LTS" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) ;; esac
"$PYTHON" "$SAMPLER_WIN" "$JSONL_WIN" "$SESSION_SAMPLE_WIN" ${_VON:+--von "$_VON"} ${_BIS:+--bis "$_BIS"}
echo "Sampler-Fenster: von ${_VON:-(Anfang)} bis ${_BIS:-(Selbst-Ausschluss)}"
# v5.162.0 (Etappe 63 N3 §3): selbst quittiert, mit Artefakt — nicht nachtippen.
if [ -s "$SESSION_SAMPLE_BASH" ]; then mind_schritt session_sampler gelaufen --datei "$SESSION_SAMPLE_BASH" "$PROJ"
else mind_schritt session_sampler "fehler:keine-stichprobe" -1 "$PROJ"; fi

# Hinweis bei sehr langer Session
TOTAL=$(grep -oE '"total_events":\s*[0-9]+' "$SESSION_SAMPLE_BASH" | grep -oE '[0-9]+')
LONG=$(grep -oE '"long_session_hint":\s*(true|false)' "$SESSION_SAMPLE_BASH" | grep -oE '(true|false)')
if [ "$LONG" = "true" ]; then
  echo "WARN: Session sehr lang ($TOTAL Events). Empfehlung: erst /mind-compact + /compact, dann /mind-update erneut."
fi
