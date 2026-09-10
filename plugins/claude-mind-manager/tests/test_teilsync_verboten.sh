#!/usr/bin/env bash
# Teilsync ist verboten — aber gemessen wird HINTERHER (v5.64.0).
#
# ⛔ NUTZER-ENTSCHEIDUNG 10.09.2026, woertlich: "die sollen garnicht mehr tokens
#    messen das soll komplett raus ea nervt ihr seit zu bloed zum messrn".
#
# Diese Sammlung hiess bis v5.63.0 dasselbe und pruefte das GEGENTEIL: dass
# `mind_sync_moeglich` den Lauf oberhalb einer Tokenschwelle ABBRICHT. Das
# Verbot bleibt, die Funktion ist weg — deshalb wird die Sammlung umgebaut und
# nicht geloescht.
#
# ⛔ DER MESSFEHLER, der sie gekostet hat (Palvedo, 10.09.2026): der Tokenstand
#    kam aus `mind_transkript_pfad` — EINE Merkerdatei je PROJEKT fuer MEHRERE
#    Sitzungen im selben Ordner, der Letzte gewinnt. Fuenf aktive Transkripte:
#      169 971 · 472 250 · 650 698 · 721 405 (der Merker) · 867 259
#    Nora (sync) stand bei ~130 000 und wurde mit 721 405 abgewiesen.
#    ⭐ Der Kommentar in `lib.sh` nannte diesen Rest seit v5.38.0 selbst.
#       Solange er eine Mahnung kostete, war er tragbar; als er den ganzen Lauf
#       kostete, nicht mehr.
#
# ⛔ WO DIE ALTEN ZUSICHERUNGEN HINGEGANGEN SIND — keine faellt still weg
#    (`autonom-arbeiten.md`: verliert ein Prueffall sein ZIEL, ist das eine
#    LUECKE, bis die Zusicherung anderswo steht):
#
#    | war (v5.55.0)                     | ist                                   |
#    |-----------------------------------|---------------------------------------|
#    | 1 Schwelle 599 999 / 600 000      | ⛔ gegenstandslos — es gibt keine      |
#    |                                   |   Schwelle. Abschnitt 1 sichert zu,   |
#    |                                   |   dass sie WEG ist.                   |
#    | 2 Fail-safe "keine Messung"       | ⛔ gegenstandslos — nichts wird mehr   |
#    |                                   |   gemessen, also faellt nichts aus.   |
#    | 3 der Abbruchtext                 | ⛔ gegenstandslos — kein Abbruch.      |
#    | 4 der Regler wirkt                | ⛔ gegenstandslos — kein Regler.       |
#    | 5 Gate VOR dem Snapshot           | ⭐ die LAUFSPERRE steht weiter davor:  |
#    |                                   |   tests/test_lauf_sperre.sh           |
#    | 6 AGENT_MAX fest 4                | ⭐ BLEIBT — Abschnitt 4 hier.          |
#    | 7 FORCE_TOKENS wird nicht gelesen | ⭐ BLEIBT — Abschnitt 5 hier.          |
#    | — das Verbot selbst               | ⭐ `mind_sync_voll` + `OPEN`:          |
#    |                                   |   Abschnitt 3 hier, ausfuehrlich in   |
#    |                                   |   tests/test_teilsync.sh.             |
#
# ⭐ GEGENPROBE GEGEN DEN ALTEN STAND ist Pflicht, sonst ist gruen nur
#    Schweigen. Abschnitt 1 und 2 sind gegen v5.63.0 ROT:
#      CLAUDE_PLUGIN_ROOT=<alter-stand> bash tests/test_teilsync_verboten.sh
#
# Aufruf:  CLAUDE_PLUGIN_ROOT=<paket> bash tests/test_teilsync_verboten.sh
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }

# shellcheck disable=SC1090
. "$R/hooks/lib.sh" 2>/dev/null

MA="$R/skills/mind-all/SKILL.md"
MU="$R/skills/mind-update/SKILL.md"

echo "=== 1) ⛔ Die Funktion ist WEG — nicht nur ungenutzt ==="
# ⛔ GEGEN DEN ALTEN STAND ROT. Das ist der Zweck dieses Abschnitts: er
#   unterscheidet "entfernt" von "war nie da".
type mind_sync_moeglich >/dev/null 2>&1
pruef "mind_sync_moeglich ist nicht mehr definiert" "1" "$?"
# ⚠ GEZAEHLT WIRD DER AUFRUF, NICHT DIE NENNUNG. Der Kommentar in lib.sh sagt,
#   dass die Funktion entfernt WURDE — das ist kein Aufrufer. Dieselbe
#   Verwechslung ist in diesem Projekt viermal aufgetreten (env-vars.md fuer
#   MIND_NOTFALL_TOKENS, dreimal am 10.09.2026 in eigenen Prueffaellen).
#   Ein Aufruf hat ein Argument dahinter, eine Nennung nicht.
pruef "kein Aufruf in den Hooks" "0" \
      "$(grep -rhoE 'mind_sync_moeglich "' "$R/hooks/" 2>/dev/null | wc -l | tr -d ' ')"
pruef "kein Aufruf in mind-all" "0" \
      "$(grep -coE 'mind_sync_moeglich "' "$MA")"
pruef "kein Aufruf in mind-update" "0" \
      "$(grep -coE 'mind_sync_moeglich "' "$MU")"

echo
echo "=== 2) ⛔ Kein Lauf bricht mehr wegen einer Tokenzahl ab ==="
# Der Abbruch war ein `exit 1` direkt hinter dem Gate. Beide Stellen sind weg.
pruef "mind-all: kein Abbruch ueber \$_TSGRUND"    "0" "$(grep -c '_TSGRUND' "$MA")"
pruef "mind-update: kein Abbruch ueber \$_TSGRUND" "0" "$(grep -c '_TSGRUND' "$MU")"
# ⭐ POSITIVKONTROLLE: die Sammlung darf nicht dadurch gruen sein, dass sie die
#   falschen Dateien liest. Beide Skills muessen es geben und sie muessen den
#   Fan-out ueberhaupt noch enthalten.
pruef "mind-all ist lesbar"              "ja" "$([ -s "$MA" ] && echo ja || echo nein)"
pruef "mind-update enthaelt den Fan-out"  "ja" \
      "$([ "$(grep -c '^AGENT_MAX=4' "$MU")" -ge 1 ] && echo ja || echo nein)"

echo
echo "=== 3) ⭐ Das VERBOT bleibt — es wird jetzt HINTERHER gemessen ==="
# Nicht die Vorhersage entscheidet, sondern die Quittung. Ausfuehrlich in
# tests/test_teilsync.sh; hier die drei Kernfaelle, damit diese Sammlung ihr
# eigenes Ziel traegt und nicht nur auf eine andere zeigt.
printf 'umfang=5/5 skills 4/4 agents\n' > "$TMP/voll"
printf 'umfang=5/5 skills 0/4 agents\n' > "$TMP/keine_agents"
printf 'umfang=5/5 skills 4/4 agents\nungepruef=custom-context\n' > "$TMP/leer_zurueck"
mind_sync_voll "$TMP/voll" >/dev/null 2>&1
pruef "4/4 Agents -> voll"                      "0" "$?"
mind_sync_voll "$TMP/keine_agents" >/dev/null 2>&1
pruef "⛔ 0/4 Agents -> TEIL, die Schuld bleibt" "1" "$?"
mind_sync_voll "$TMP/leer_zurueck" >/dev/null 2>&1
pruef "⛔ 4/4 dispatcht, einer leer -> TEIL"     "1" "$?"

echo
echo "=== 4) ⛔ Es gibt keine Zwischenstufe — AGENT_MAX ist fest 4 ==="
# ⛔ GEZAEHLT WIRD DIE ZUWEISUNG, NICHT DIE NENNUNG — und diese Zeile ist der
#   Beleg dafuer, dass der Unterschied zaehlt: die erste Fassung fiel an ihrem
#   eigenen Erfolg durch. Der Satz "hier stand `AGENT_MAX=0`, es ist
#   gegenstandslos" ist eine NENNUNG und wurde als Rueckfall gewertet.
pruef "keine Zuweisung AGENT_MAX=2 mehr" "0" "$(grep -cE '^[[:space:]]*(\*\) *)?AGENT_MAX=2' "$MU")"
pruef "keine Zuweisung AGENT_MAX=0 mehr" "0" "$(grep -cE '^[[:space:]]*(\*\) *)?AGENT_MAX=0' "$MU")"
pruef "AGENT_MAX ist fest 4"             "1" "$(grep -c '^AGENT_MAX=4' "$MU")"

echo
echo "=== 5) ⛔ Die entfallenen Regler werden von keinem Hook gelesen ==="
# ⚠ Gezaehlt werden LESEZUGRIFFE (`${VAR:-`), nicht Erwaehnungen: ein
#   Kommentar, der sagt "der Regler ist entfallen", ist kein Leser.
pruef "kein MIND_SYNC_FORCE_TOKENS:- in den Hooks" "0" \
      "$(grep -rl 'MIND_SYNC_FORCE_TOKENS:-' "$R/hooks/" 2>/dev/null | wc -l | tr -d ' ')"
pruef "kein MIND_AGENT_HALB_TOKENS:- in den Hooks" "0" \
      "$(grep -rl 'MIND_AGENT_HALB_TOKENS:-' "$R/hooks/" 2>/dev/null | wc -l | tr -d ' ')"
pruef "kein MIND_AGENT_VOLL_TOKENS:- in den Hooks" "0" \
      "$(grep -rl 'MIND_AGENT_VOLL_TOKENS:-' "$R/hooks/" 2>/dev/null | wc -l | tr -d ' ')"
pruef "stop.sh gibt gar kein JSON mehr aus" "0" \
      "$(grep -c 'jq -nc' "$R/hooks/stop.sh")"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
