#!/usr/bin/env bash
# =============================================================================
#  SYNC-SCHUTZ-GATE — laeuft eine Sitzung auf einer ungeschuetzten Version?
#  (NEU v5.75.0)
# =============================================================================
#
# ⛔ DER VORFALL, ZWEIMAL:
#    19.08.2026  der zweite Sync entfernte 5.3.1, auf der die Sitzung lief —
#                alle Hooks danach stumm. KEEP_VERSIONS=2 haelt genau EINEN
#                Durchlauf.
#    10.09.2026  5.70.0 stand NICHT in .sync-protect.json, waehrend DREI
#                Sitzungen darauf liefen. Sie ueberlebte als zweithoechste
#                zufaellig.
#
# ⭐ Der Schutz ist seit dem 19.08.2026 dokumentiert und wurde trotzdem nicht
#    eingetragen. Er hing an einem Handgriff, den niemand prueft — der
#    Unterschied zwischen einer Regel und einer Ratsche.
#
# ⛔ DIE WICHTIGSTE PRUEFUNG IST FALL 2: das Gate muss ROT werden koennen.
#    Ein Gate, das nur den guten Fall kennt, ist von einem, das immer gruen
#    meldet, nicht zu unterscheiden — in diesem Projekt achtmal gemessen.
# =============================================================================
set -u
WURZEL="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
GATE="$WURZEL/references/sync_schutz_gate.py"

OK=0; ROT=0
janein() {
  if [ "$2" = "$3" ]; then
    printf '    OK   %-56s ist=%s\n' "$1" "$3"; OK=$((OK + 1))
  else
    printf '    FEHL %-56s ist=%-10s soll=%s\n' "$1" "$3" "$2"; ROT=$((ROT + 1))
  fi
}

[ -f "$GATE" ] || { echo "ABBRUCH: $GATE fehlt"; exit 2; }

D=$(mktemp -d "${TMPDIR:-/tmp}/syncsXXXXXX") || exit 2
W=$(cygpath -w "$D" 2>/dev/null || echo "$D")

# ⛔ Der Bau eines KUENSTLICHEN HOME. Python liest auf Windows USERPROFILE
#   zuerst, auf MSYS HOME — deshalb werden BEIDE gesetzt. Ohne das liefe der
#   Prueffall gegen den ECHTEN Bestand und koennte ihn nicht steuern.
mkdir -p "$D/.claude/plugins/cache/probemarkt/probeplugin"
# ⭐ Eine PID, die WIRKLICH laeuft — aus der Prozessliste geholt, nicht geraten.
#   ⚠ Ohne sie kann der Lebend-Fall nicht gestellt werden; dann wird der
#     Abschnitt UEBERSPRUNGEN und sagt das, statt gruen zu melden.
LEBT=$(tasklist //FO CSV //NH 2>/dev/null | head -1 | awk -F'","' '{print $2}' | tr -d '"')
case "${LEBT:-}" in ''|*[!0-9]*) LEBT="" ;; esac
TOT=999999

schreibe_stand() {   # $1 = registrierte Version, $2 = geschuetzte Version
  printf '{"version":1,"plugins":{"probeplugin@probemarkt":[{"scope":"user","version":"%s"}]}}\n' \
         "$1" > "$D/.claude/plugins/installed_plugins.json"
  printf '{"%s": 1789000000.0}\n' "$2" \
         > "$D/.claude/plugins/cache/probemarkt/probeplugin/.sync-protect.json"
}
haelt() {            # $1 = Version, $2 = PID
  mkdir -p "$D/.claude/plugins/cache/probemarkt/probeplugin/$1/.in_use"
  printf '{"pid":%s}\n' "$2" \
    > "$D/.claude/plugins/cache/probemarkt/probeplugin/$1/.in_use/$2"
}
lauf() { USERPROFILE="$W" HOME="$D" python "$GATE" probemarkt probeplugin 2>&1; }
rc_von() { USERPROFILE="$W" HOME="$D" python "$GATE" probemarkt probeplugin >/dev/null 2>&1; echo $?; }

echo "=============================================================================="
echo "  1) Der GUTE Fall: registrierte Version ist geschuetzt"
echo "=============================================================================="
schreibe_stand "5.74.0" "5.74.0"
janein "Rueckgabe 0" "0" "$(rc_von)"
janein "die Ausgabe nennt die registrierte Version" "ja" \
  "$(lauf | grep -q '5.74.0' && echo ja || echo nein)"
# ⛔ HIER STAND: "sagt, dass eine AELTERE Version UNGEMESSEN bleibt".
#   Die Zusicherung hat ihr Ziel verloren, WEIL DIE LUECKE GESCHLOSSEN IST:
#   `.in_use` misst genau das, was der Satz als unmessbar auswies. Sie wird
#   deshalb NICHT gestrichen, sondern auf die neue ehrliche Aussage gerichtet —
#   `autonom-arbeiten.md`: ein Prueffall ohne Ziel ist der Beleg fuer eine
#   Luecke, gestrichen wird er erst, wenn die Zusicherung anderswo steht.
janein "⚠ er sagt, dass tote Eintraege KEIN Schutzgrund sind" "ja" \
  "$(lauf | grep -q 'Leichen und KEIN Schutzgrund' && echo ja || echo nein)"

echo
echo "=============================================================================="
echo "  2) ⛔ DER FALL, FUER DEN ES GEBAUT IST: NICHT geschuetzt"
echo "=============================================================================="
schreibe_stand "5.70.0" "5.74.0"
janein "⛔ Rueckgabe 1 — das Gate wird ROT" "1" "$(rc_von)"
janein "es nennt die ungeschuetzte Version beim Namen" "ja" \
  "$(lauf | grep -q 'REGISTRIERTE Version 5.70.0 ist ebenfalls ungeschuetzt' \
     && echo ja || echo nein)"
janein "⭐ und nennt den Vorfall als Grund, nicht nur die Regel" "ja" \
  "$(lauf | grep -q '19.08.2026' && echo ja || echo nein)"
janein "⭐ es sagt, WIE man es eintraegt" "ja" \
  "$(lauf | grep -q 'Eintragen VOR dem Sync' && echo ja || echo nein)"

echo
echo "=============================================================================="
echo "  2b) ⭐ .in_use — die Version, die WIRKLICH gehalten wird"
echo "=============================================================================="
# ⛔ HIER STAND EINE STUNDE LANG "UNGEMESSEN". Claude Code schreibt je Cache-
#   Version ein `.in_use/<pid>`. Gemessen 10.09.2026: 5.2.0 wurde von SECHS
#   lebenden Prozessen gehalten und war ungeschuetzt — 72 Versionen alt.
schreibe_stand "5.74.0" "5.74.0"
haelt "5.9.0" "$TOT"
janein "⛔ eine TOTE PID ist KEIN Schutzgrund -> Rueckgabe 0" "0" "$(rc_von)"
janein "die Ausgabe fuehrt die Version mit lebend=0" "ja" \
  "$(lauf | grep -qE '5\.9\.0 +1 +0' && echo ja || echo nein)"

if [ -n "$LEBT" ]; then
  haelt "5.9.0" "$LEBT"
  janein "⛔ eine LEBENDE PID auf ungeschuetzter Version -> Rueckgabe 1" "1" "$(rc_von)"
  janein "sie wird beim Namen genannt" "ja" \
    "$(lauf | grep -q 'UNGESCHUETZT, obwohl in Benutzung: 5.9.0' && echo ja || echo nein)"
  janein "⛔ und es steht da: NICHT loeschen, eintragen" "ja" \
    "$(lauf | grep -q 'NICHT LOESCHEN' && echo ja || echo nein)"
  printf '{"5.74.0": 1789000000.0, "5.9.0": 1789000000.0}\n' \
    > "$D/.claude/plugins/cache/probemarkt/probeplugin/.sync-protect.json"
  janein "⭐ eingetragen -> wieder gruen" "0" "$(rc_von)"
  rm -rf "$D/.claude/plugins/cache/probemarkt/probeplugin/5.9.0"
else
  echo "  [--- ] UEBERSPRUNGEN: keine lebende PID ermittelbar (tasklist fehlt)."
  echo "         ⚠ Ein uebersprungener Fall ist KEIN bestandener."
fi
schreibe_stand "5.74.0" "5.74.0"
rm -rf "$D/.claude/plugins/cache/probemarkt/probeplugin/5.9.0"

echo
echo "=============================================================================="
echo "  3) NICHT MESSBAR ist kein bestandenes Gate"
echo "=============================================================================="
rm -f "$D/.claude/plugins/installed_plugins.json"
janein "⛔ fehlende Registrierung -> Rueckgabe 3, nicht 0" "3" "$(rc_von)"
janein "und die Ausgabe sagt es ausdruecklich" "ja" \
  "$(lauf | grep -q 'KEIN bestandenes Gate' && echo ja || echo nein)"
schreibe_stand "5.74.0" "5.74.0"
rm -f "$D/.claude/plugins/cache/probemarkt/probeplugin/.sync-protect.json"
janein "⛔ fehlende .sync-protect.json -> ebenfalls 3" "3" "$(rc_von)"

echo
echo "=============================================================================="
echo "  4) Aufruffehler"
echo "=============================================================================="
janein "ohne Argumente -> Rueckgabe 2" "2" \
  "$(python "$GATE" >/dev/null 2>&1; echo $?)"

rm -rf "$D"
echo
echo "=============================================================================="
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
