#!/usr/bin/env bash
# Das Rollen-Gate (v5.54.0) — mahnt nur noch die Sitzung, die zustaendig ist.
#
# ⛔ DER FALL, FUER DEN ES GEBAUT IST, IST FALL 9: drei Sitzungen im selben
#    Ordner, eine davon `sync`, und die Sync-Mahnung erschien in allen dreien.
#    Alle Merker liegen unter EINEM `.claude-mind/` und tragen keine
#    Sitzungskennung — der Hook konnte gar nicht unterscheiden.
#
# ⭐ POSITIV- UND NEGATIVKONTROLLE STEHEN NEBENEINANDER, und zwar an jeder
#    Stelle. Ein Gate, das alle stilllegt, waere so wertlos wie eines, das
#    niemanden stilllegt — die Faelle 8, 10 und 12 pruefen, dass GEREDET wird.
#
# ⛔ FALL 12 IST DIE STELLE, AN DER DER AUFTRAG UND ICH AUSEINANDERGEHEN.
#    Die Auftragstabelle sagt "prompt-submit.sh komplett still". Der Hook gibt
#    aber FUENF Dinge aus, und eines davon ist keine Mahnung: die UEBERGABE des
#    Arbeitsstands nach einer Kompaktierung. Sie gehoert der Sitzung, die
#    kompaktiert hat — fast immer der arbeiter, nie der sync. Wer sie
#    mitstilllegt, nimmt der arbeitenden Sitzung ihr Gedaechtnis.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIB="$R/hooks/lib.sh"
PS="$R/hooks/prompt-submit.sh"
ST="$R/hooks/stop.sh"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }
hat() { case "$3" in *"$2"*) GRUEN=$((GRUEN+1)); echo "  [ok ] $1";;
  *) ROT=$((ROT+1)); echo "  [ROT] $1 — '$2' fehlt";; esac; }

# shellcheck disable=SC1090
. "$LIB" 2>/dev/null

SYNC="local_61d97508-9fbd-444f-beb8-612fb89fdf06"
MGR="local_acd4e029-dfa6-45ca-8987-379614bc3124"
ARB="local_a02a245a-690c-4433-a201-e5d3485917fb"
FREMD="local_ffffffff-0000-0000-0000-000000000000"

P="$TMP/proj"; mkdir -p "$P/.claude/rules" "$P/.claude-mind/rescued"

roster() {  # roster <sync-kennung>  — leer laesst die sync-Zeile ohne Kennung
  {
    echo '# Rollen'
    echo
    echo '| Rolle | Name | sessionId | Tut |'
    echo '|---|---|---|---|'
    echo "| **manager** | **Anton** | \`$MGR\` | liest, beauftragt |"
    echo "| **arbeiter** | **Nils** | \`$ARB\` | baut, misst |"
    if [ -n "${1:-}" ]; then
      echo "| **sync** | **Rita** | \`$1\` | faehrt die Werkzeuge |"
    else
      echo '| **sync** | **Rita** | — | faehrt die Werkzeuge |'
    fi
  } > "$P/.claude/rules/rollen.md"
}

still_ps() {  # still_ps <sid>  -> ja|nein  (gibt prompt-submit ueberhaupt etwas aus?)
  echo '{"cwd":"'"$P"'","session_id":"'"$1"'"}' > "$TMP/in.json"
  A=$(CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PROJECT_DIR="$P" bash "$PS" < "$TMP/in.json" 2>/dev/null)
  [ -z "$A" ] && echo ja || echo nein
}
ausgabe_ps() {
  echo '{"cwd":"'"$P"'","session_id":"'"$1"'"}' > "$TMP/in.json"
  CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PROJECT_DIR="$P" bash "$PS" < "$TMP/in.json" 2>/dev/null
}
blockt() {  # blockt <sid> -> ja|nein
  echo '{"cwd":"'"$P"'","session_id":"'"$1"'","stop_hook_active":false}' > "$TMP/sin.json"
  B=$(CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PROJECT_DIR="$P" bash "$ST" < "$TMP/sin.json" 2>/dev/null)
  case "$B" in *'"block"'*) echo ja ;; *) echo nein ;; esac
}
schuld() {
  printf 'path=%s/x_chat.md\nresume=%s/x_RESUME.md\n' \
    "$P/.claude-mind/rescued" "$P/.claude-mind/rescued" > "$P/.claude-mind/rescued/OPEN"
  touch "$P/.claude-mind/rescued/x_chat.md"
  printf '## Auftrag\nweiterbauen\n' > "$P/.claude-mind/rescued/x_RESUME.md"
  rm -f "$P/.claude-mind/rescued/OPEN.seen-"* 2>/dev/null
}
sauber() { rm -f "$P/.claude-mind/rescued/OPEN"* "$P/.claude-mind/rescued/COMPACT-FAELLIG" \
                 "$P/.claude-mind/rescued/UEBERGABE" 2>/dev/null; }

echo "=== 1) ohne Roster: alles wie heute ==="
rm -f "$P/.claude/rules/rollen.md"
pruef "mind_rolle meldet 'keine'" "keine" "$(mind_rolle "$ARB" "$P")"
mind_sync_zustaendig "$ARB" "$P"; pruef "und niemand ist zustaendig (Rueckgabe 1)" "1" "$?"

echo
echo "=== 2) Roster da: jede Kennung findet ihre Rolle ==="
roster "$SYNC"
pruef "manager"  "manager"  "$(mind_rolle "$MGR"  "$P")"
pruef "arbeiter" "arbeiter" "$(mind_rolle "$ARB"  "$P")"
pruef "sync"     "sync"     "$(mind_rolle "$SYNC" "$P")"
pruef "die sync-Kennung wird gefunden" "$SYNC" "$(mind_sync_kennung "$P/.claude/rules/rollen.md")"

echo
echo "=== 3) ⛔ FAIL-SAFE: alles Unklare REDET ==="
mind_sync_zustaendig "$FREMD" "$P"; pruef "fremde Kennung -> redet" "1" "$?"
pruef "   ... und heisst 'unbekannt'" "unbekannt" "$(mind_rolle "$FREMD" "$P")"
mind_sync_zustaendig "" "$P";      pruef "leere Kennung -> redet" "1" "$?"
mind_sync_zustaendig "$SYNC" "$P"; pruef "⭐ der sync selbst -> redet" "1" "$?"

echo
echo "=== 4) ⭐ sync-Zeile OHNE Kennung legt NIEMANDEN still ==="
roster ""
pruef "keine sync-Kennung ableitbar" "" "$(mind_sync_kennung "$P/.claude/rules/rollen.md")"
mind_sync_zustaendig "$ARB" "$P"; pruef "arbeiter redet trotzdem" "1" "$?"

echo
echo "=== 5) ⛔ NEGATIVKONTROLLE des Formfilters: Platzhalter ist keine Kennung ==="
roster "tbd"
mind_sync_zustaendig "$ARB" "$P"; pruef "'tbd' ist zu kurz -> redet" "1" "$?"
roster "local_?????-nicht-erlaubt"
mind_sync_zustaendig "$ARB" "$P"; pruef "Fragezeichen sind keine Kennung -> redet" "1" "$?"

echo
echo "=== 6) Form-Toleranz: Grossschreibung und Leerraum ==="
{
  echo '|Rolle|Name|sessionId|'
  echo '|---|---|---|'
  echo "|  **SYNC**  |  Rita  |   \`$SYNC\`   |"
  echo "| Arbeiter | Nils | \`$ARB\` |"
} > "$P/.claude/rules/rollen.md"
pruef "'**SYNC**' mit Leerraum wird erkannt" "$SYNC" "$(mind_sync_kennung "$P/.claude/rules/rollen.md")"
pruef "'Arbeiter' gross geschrieben auch" "arbeiter" "$(mind_rolle "$ARB" "$P")"

echo
echo "=== 7) ⛔ Eine Kennung ausserhalb der Tabelle zaehlt nicht ==="
{
  echo '# Rollen'
  echo "Gemessen an $ARB stand die Zahl falsch."
  echo '|Rolle|Name|sessionId|'
  echo '|---|---|---|'
  echo "| **sync** | **Rita** | \`$SYNC\` | x |"
} > "$P/.claude/rules/rollen.md"
pruef "Prosa-Nennung macht keine Rolle" "unbekannt" "$(mind_rolle "$ARB" "$P")"

echo
echo "=== 8) ohne Roster mahnt prompt-submit wie heute (Ausgangslage) ==="
rm -f "$P/.claude/rules/rollen.md"; sauber; schuld
pruef "arbeiter bekommt die Schuld-Mahnung" "nein" "$(still_ps "$ARB")"

echo
echo "=== 9) ⛔ DER FALL: Roster mit sync -> arbeiter und manager sind STILL ==="
roster "$SYNC"; sauber; schuld
pruef "arbeiter: keine Ausgabe" "ja" "$(still_ps "$ARB")"
sauber; schuld
pruef "manager: keine Ausgabe"  "ja" "$(still_ps "$MGR")"

echo
echo "=== 10) ⭐ POSITIVKONTROLLE: der sync selbst wird WEITER gemahnt ==="
sauber; schuld
pruef "sync bekommt die Mahnung" "nein" "$(still_ps "$SYNC")"
sauber; schuld
pruef "fremde Kennung ebenfalls (fail-safe)" "nein" "$(still_ps "$FREMD")"

echo
echo "=== 11) COMPACT-FAELLIG: still fuer den arbeiter, laut fuer den sync ==="
sauber; touch "$P/.claude-mind/rescued/COMPACT-FAELLIG"
pruef "arbeiter: keine Bitte um /compact" "ja"   "$(still_ps "$ARB")"
sauber; touch "$P/.claude-mind/rescued/COMPACT-FAELLIG"
pruef "sync: die Bitte kommt"             "nein" "$(still_ps "$SYNC")"

echo
echo "=== 12) ⭐ DIE UEBERGABE BLEIBT — auch fuer den arbeiter ==="
sauber
printf 'resume=%s/x_RESUME.md\n' "$P/.claude-mind/rescued" > "$P/.claude-mind/rescued/UEBERGABE"
printf '## Auftrag\nden Umbau zu Ende bringen\n' > "$P/.claude-mind/rescued/x_RESUME.md"
U=$(ausgabe_ps "$ARB")
hat "der arbeiter bekommt seinen Arbeitsstand" "den Umbau zu Ende bringen" "$U"
hat "   ... als Kompaktierungs-Uebergabe" "kompaktiert" "$U"

echo
echo "=== 13) ⛔ stop.sh blockt NIEMANDEN mehr — auch den sync nicht ==="
# ⛔ v5.55.0: DAS ROLLEN-GATE IST AUS stop.sh WIEDER VERSCHWUNDEN, eine
#    Version nach seinem Einbau. Es unterdrueckte den Zwang fuer Sitzungen, die
#    nicht `sync` sind — und seit v5.55.0 gibt es keinen Zwang mehr, den man
#    unterdruecken koennte. Hier stand deshalb bis v5.54.0 "sync: block".
# ⭐ Die tragende Unterscheidung des Rollen-Gates sitzt in den Abschnitten
#    9 bis 12 an `prompt-submit.sh`. DORT wird gemessen, ob es wirkt; hier nur
#    noch, dass der Block wirklich weg ist. ⚠ Ohne die Abschnitte 9–12 waere
#    dieser hier blind — drei Faelle, die alle dasselbe Nichts pruefen.
if command -v jq >/dev/null 2>&1; then
  sauber; schuld
  pruef "arbeiter: kein block" "nein" "$(blockt "$ARB")"
  sauber; schuld
  pruef "⛔ sync: AUCH kein block" "nein" "$(blockt "$SYNC")"
  rm -f "$P/.claude/rules/rollen.md"; sauber; schuld
  pruef "⛔ ohne Roster: ebenfalls nicht" "nein" "$(blockt "$ARB")"
else
  echo "  [--] jq fehlt — uebersprungen (ein uebersprungener Fall ist kein bestandener)"
fi

echo
echo "=== 14) ⛔ Die Huelle entscheidet nichts — sie reicht durch ==="
pruef "rollen-gate.sh ohne Argumente -> Rueckgabe 1" "1" \
  "$(CLAUDE_PLUGIN_ROOT="$R" bash "$R/hooks/rollen-gate.sh" >/dev/null 2>&1; echo $?)"
pruef "ohne CLAUDE_PLUGIN_ROOT -> Rueckgabe 1" "1" \
  "$(CLAUDE_PLUGIN_ROOT="" bash "$R/hooks/rollen-gate.sh" "$ARB" "$P" >/dev/null 2>&1; echo $?)"

echo
echo "=== 15) ⛔ EIN ROSTER KANN MEHR ALS DREI ROLLEN HABEN ==="
# ⛔ Palvedo hat VIER: manager, arbeiter, sync, forschung. Bis v5.60.0 gab
#    `mind_rolle` nur drei feste Werte heraus und meldete die vierte als
#    `unbekannt` — und `unbekannt` redet. Eine forschung-Sitzung waere weiter
#    gemahnt worden, obwohl dort ein sync sitzt.
FORSCH="local_ee11ee22-3333-4444-5555-666677778888"
{
  echo '| Rolle | Name | sessionId | Tut |'
  echo '|---|---|---|---|'
  echo "| **manager** | **Timo** | \`$MGR\` | leitet |"
  echo "| **arbeiter** | **Kalle** | \`$ARB\` | baut |"
  echo "| **sync** | **Nora** | \`$SYNC\` | faehrt die Werkzeuge |"
  echo "| **forschung** | **Emil** | \`$FORSCH\` | recherchiert |"
} > "$P/.claude/rules/rollen.md"
pruef "die vierte Rolle wird beim Namen genannt" "forschung" "$(mind_rolle "$FORSCH" "$P")"
mind_sync_zustaendig "$FORSCH" "$P"
pruef "⭐ und sie wird STILLGELEGT wie die anderen" "0" "$?"
mind_sync_zustaendig "$SYNC" "$P"
pruef "⛔ der sync selbst weiterhin nicht" "1" "$?"
mind_sync_zustaendig "$FREMD" "$P"
pruef "⛔ eine Kennung ausserhalb des Rosters weiterhin nicht" "1" "$?"
sauber; schuld
pruef "am Hook: forschung ist still" "ja" "$(still_ps "$FORSCH")"
sauber; schuld
pruef "⭐ POSITIVKONTROLLE: der sync redet weiter" "nein" "$(still_ps "$SYNC")"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
