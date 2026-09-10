#!/usr/bin/env bash
# Die Sync-Schuld trägt jetzt ALLES allein (v5.65.0).
#
# ⛔ WAS DIESE SAMMLUNG WAR (v5.50.0): `prompt-submit.sh` ist eine Kette aus
#    `if … exit 0`. Der COMPACT-FAELLIG-Zweig stieg aus, die Schuld-Meldung
#    stand 150 Zeilen weiter unten — bei BEIDEN Merkern wurde sie nie erreicht.
#    Der Fix war, die Schuld MIT in die Kompaktierungs-Meldung zu nehmen.
#
# ⭐ WAS SIE JETZT IST: `COMPACT-FAELLIG` ist entfallen (er entstand nur
#    token-getriggert, Nutzer-Entscheidung 10.09.2026). Damit gibt es nur noch
#    EINEN Weg — und die Frage kehrt sich um: trägt er allein, was die
#    zusammengelegte Meldung trug?
#
# ⛔ WO DIE ZUSICHERUNGEN GEBLIEBEN SIND:
#
#    | war (v5.50.0)                     | ist                                |
#    |-----------------------------------|------------------------------------|
#    | beide Merker -> beide Tatsachen   | ⛔ gegenstandslos — es gibt nur     |
#    |                                   |   noch einen Merker. Abschnitt 1   |
#    |                                   |   prüft, dass der EINE alles trägt.|
#    | EINE gültige JSON-Ausgabe         | ⭐ BLEIBT — Abschnitt 2.            |
#    | ohne Schuld keine erfinden        | ⭐ BLEIBT — Abschnitt 3.            |
#    | OPEN ohne grund= erfindet keinen  | ⭐ BLEIBT — Abschnitt 4.            |
#    | eine Altlast-Datei wirkt          | ⭐ umgekehrt — Abschnitt 5:         |
#    |                                   |   sie wirkt NICHT mehr.            |
#
# ⛔ JEDER FALL BEKOMMT EIN EIGENES PROJEKT. Die alte Fassung teilte eines für
#    alle fünf — das ging nur, solange der COMPACT-Zweig vorher aussteig. Über
#    den Schuld-Zweig setzt der Hook `OPEN.seen-<sid>`, und ab dem zweiten Fall
#    schwieg er turnusmäßig. ⭐ Ein Prüffall, der am Zustand des vorigen hängt,
#    misst nicht mehr, was er behauptet.
#
# ⭐ GEGENPROBE: Abschnitt 5 ist gegen v5.64.0 ROT.
#
# Aufruf:  CLAUDE_PLUGIN_ROOT=<paket> bash tests/test_schuld_bei_compact.sh
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PS="$R/hooks/prompt-submit.sh"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }
hat() { case "$3" in *"$2"*) GRUEN=$((GRUEN+1)); echo "  [ok ] $1";;
  *) ROT=$((ROT+1)); echo "  [ROT] $1 — '$2' fehlt";; esac; }
nicht() { case "$3" in *"$2"*) ROT=$((ROT+1)); echo "  [ROT] $1 — '$2' steht drin";;
  *) GRUEN=$((GRUEN+1)); echo "  [ok ] $1";; esac; }

neu_projekt() {   # jeder Fall bekommt sein eigenes — siehe Kopf
  # ⛔ KEIN Zaehler in der Elternschale. `P=$(neu_projekt)` laeuft in einer
  #   SUBSHELL — ein `n=$((n+1))` darin ist beim naechsten Aufruf wieder weg,
  #   und alle Faelle bekaemen DASSELBE Verzeichnis. Genau das ist beim Bau
  #   dieser Fassung passiert: die Faelle 4 und 5 wurden rot, weil Fall 1
  #   bereits `OPEN.seen-t1` gesetzt hatte. Die Falle steht in
  #   `~/.claude/rules/shell-windows.md` als erste der stillen.
  local d; d=$(mktemp -d "$TMP/pXXXXXX")
  mkdir -p "$d/.claude-mind/rescued"; touch "$d/.claude-mind/rescued/x_chat.md"
  printf '%s' "$d"
}
schuld() {        # projekt [grund] [ungepruef]
  { printf 'path=%s/.claude-mind/rescued/x_chat.md\n' "$1"
    [ -n "${2:-}" ] && printf 'grund=%s\n' "$2"
    [ -n "${3:-}" ] && printf 'ungepruef=%s\n' "$3"
  } > "$1/.claude-mind/rescued/OPEN"
}
lauf() { printf '{"cwd":"%s","session_id":"t1"}' "$1" \
  | CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PROJECT_DIR="$1" bash "$PS" 2>/dev/null; }

echo "=== 1) ⭐ POSITIVKONTROLLE: der EINE Weg trägt alles ==="
P=$(neu_projekt); schuld "$P" teilsync "claude-md,memory"
A=$(lauf "$P")
hat "die Schuld wird gemeldet"                  "Sync-Schuld" "$A"
hat "   ... mit dem Grund"                      "teilsync"    "$A"
hat "   ... und den UNGEPRUEFTEN Bereichen"     "claude-md"   "$A"
hat "   ... als ungeprueft, nicht als unauffaellig" "UNGEPRUEFT" "$A"
hat "   ... und mit dem Weg heraus"             "/mind-all"   "$A"

echo
echo "=== 2) ⛔ Es bleibt EINE gueltige JSON-Ausgabe ==="
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$A" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1
  pruef "gueltiges JSON mit additionalContext" 0 "$?"
  pruef "genau EIN Objekt" 1 "$(printf '%s' "$A" | grep -c 'hookSpecificOutput')"
else
  echo "  [--] jq fehlt — uebersprungen (ein uebersprungener Fall ist kein bestandener)"
fi

echo
echo "=== 3) ⛔ NEGATIVKONTROLLE: ohne Schuld wird keine behauptet ==="
P=$(neu_projekt)
B=$(lauf "$P")
nicht "keine Schuld erfunden" "SYNC-SCHULD" "$B"
nicht "   ... und kein TEILSYNC" "TEILSYNC" "$B"

echo
echo "=== 4) ⛔ Eine OPEN ohne grund= behauptet keinen Teilsync ==="
P=$(neu_projekt); schuld "$P"
D=$(lauf "$P")
hat   "die Schuld steht da"              "Sync-Schuld" "$D"
nicht "   ... aber ohne erfundenen Grund" "Grund:"      "$D"
nicht "   ... und ohne erfundene Bereiche" "UNGEPRUEFT" "$D"

echo
echo "=== 5) ⛔ Eine COMPACT-FAELLIG-Altlast wirkt NICHT mehr ==="
# ⛔ Der Merker ist in v5.65.0 entfallen. Eine liegengebliebene Datei aus einer
#   aelteren Fassung darf weder eine Meldung ausloesen noch die Schuld-Meldung
#   verdraengen. ⭐ GEGEN DEN ALTEN STAND ROT — dort verdraengte sie sie genau.
P=$(neu_projekt); schuld "$P" teilsync "rules"
printf 'ts=2026-09-10 12:00:00\ntokens=772345\n' > "$P/.claude-mind/rescued/COMPACT-FAELLIG"
E=$(lauf "$P")
hat   "die SCHULD wird trotzdem gemeldet"        "Sync-Schuld" "$E"
hat   "   ... mit Grund"                          "teilsync"    "$E"
nicht "⛔ und KEINE Bitte um eine Kompaktierung"  "Kompaktierung steht aus" "$E"

P=$(neu_projekt)
printf 'ts=2026-09-10 12:00:00\n' > "$P/.claude-mind/rescued/COMPACT-FAELLIG"
F=$(lauf "$P")
nicht "⛔ allein liegend loest sie gar nichts aus" "Kompaktierung steht aus" "$F"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
