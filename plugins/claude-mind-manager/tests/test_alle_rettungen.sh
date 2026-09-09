#!/usr/bin/env bash
# Alle offenen Rettungen kommen an (v5.57.0) — die Messung zu Auftrag D.
#
# ⛔ DIE DOKU BEHAUPTETE ES SEIT v5.4.1, GEMESSEN WAR ES NIE. `hooks.md` sagt,
#    `/mind-all` synce ALLE offenen Rettungen. Nachgestellt mit drei
#    `path=`-Zeilen kam in `mind-update` GENAU EINE an:
#
#      RESCUED=$(... alle drei ...)                 -> drei Zeilen
#      [ -n "$RESCUED" ] && [ ! -f "$RESCUED" ] && RESCUED=""
#                                                   -> LEER
#      [ -z "$RESCUED" ] && RESCUED=$(ls -t ... | head -1)
#                                                   -> juengste Datei im ORDNER
#
# ⭐ DER RUECKFALL IST DER SCHLIMMERE TEIL: er liest den Merker gar nicht mehr.
#    Er nimmt die juengste `*_chat.md` nach Aenderungszeit — auch eine, die
#    nicht in `OPEN` steht.
#
# ⚠ Und von aussen sah die Kette richtig aus: `mind-all` Step 0 zaehlte alle
#   drei korrekt AUF. Der Bericht stimmte, die Speisung nicht.
#
# ⭐ FALL 5 IST DIE POSITIVKONTROLLE GEGEN DIE ALTE BAUFORM: mit genau EINER
#    Rettung war der alte Code richtig. Ein Prueffall, der nur den Mehrfachfall
#    kennt, koennte durch eine Loesung bestanden werden, die den Einzelfall
#    zerstoert.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }

# shellcheck disable=SC1090
. "$R/hooks/lib.sh" 2>/dev/null

anlegen() {  # anlegen <projekt> <n>  — n Rettungen, alle im Merker
  local d="$1" n="$2" i
  mkdir -p "$d/.claude-mind/rescued"
  : > "$d/.claude-mind/rescued/OPEN"
  i=1
  while [ "$i" -le "$n" ]; do
    printf '## [x]\n' > "$d/.claude-mind/rescued/r${i}_chat.md"
    echo "path=$d/.claude-mind/rescued/r${i}_chat.md" >> "$d/.claude-mind/rescued/OPEN"
    i=$((i + 1))
  done
}
zahl() { mind_rettungen "$1" | grep -c . ; }

echo "=== 1) ⛔ DER FALL: DREI Rettungen -> DREI kommen an ==="
P="$TMP/p3"; anlegen "$P" 3
pruef "drei Rettungen" "3" "$(zahl "$P")"
pruef "die AELTESTE steht zuerst" "r1_chat.md" "$(basename "$(mind_rettungen "$P" | head -1)")"
pruef "die JUENGSTE zuletzt"      "r3_chat.md" "$(basename "$(mind_rettungen "$P" | tail -1)")"

echo
echo "=== 2) Zwei Rettungen — die Grenze, an der die alte Fassung kippte ==="
P="$TMP/p2"; anlegen "$P" 2
pruef "zwei Rettungen" "2" "$(zahl "$P")"

echo
echo "=== 3) ⭐ Tote Zeiger fliegen EINZELN raus ==="
P="$TMP/ptot"; anlegen "$P" 3
rm -f "$P/.claude-mind/rescued/r2_chat.md"
pruef "zwei bleiben" "2" "$(zahl "$P")"
pruef "und die tote ist nicht dabei" "0" "$(mind_rettungen "$P" | grep -c 'r2_chat')"

echo
echo "=== 4) ⛔ NEGATIVKONTROLLE: kein Merker, keine Rettung -> nichts ==="
P="$TMP/pleer"; mkdir -p "$P/.claude-mind/rescued"
pruef "keine Ausgabe" "0" "$(zahl "$P")"
mind_rettungen "$P" >/dev/null 2>&1
pruef "und Rueckgabe 1" "1" "$?"
mind_rettungen "" >/dev/null 2>&1
pruef "ohne Projekt ebenfalls 1" "1" "$?"

echo
echo "=== 5) ⭐ POSITIVKONTROLLE: EINE Rettung geht weiter ==="
P="$TMP/p1"; anlegen "$P" 1
pruef "genau eine" "1" "$(zahl "$P")"
pruef "und es ist die richtige" "r1_chat.md" "$(basename "$(mind_rettungen "$P")")"

echo
echo "=== 6) ⚠ RUECKFALL nur OHNE brauchbaren Merker ==="
# Eine Rettung aus einer Fassung vor v5.2.1: Datei da, kein OPEN.
P="$TMP/palt"; mkdir -p "$P/.claude-mind/rescued"
printf '## [x]\n' > "$P/.claude-mind/rescued/20260101-000000_chat.md"
pruef "ohne Merker greift der Rueckfall" "1" "$(zahl "$P")"
# ⛔ UND ER GREIFT NICHT, SOLANGE DER MERKER TRAEGT. Genau das war der Fehler:
#    der alte Code fiel auch dann zurueck, wenn OPEN drei gute Zeiger hatte.
P="$TMP/pfremd"; anlegen "$P" 2
printf '## [x]\n' > "$P/.claude-mind/rescued/zzz_spaeter_chat.md"
pruef "⭐ eine Datei AUSSERHALB des Merkers wird nicht genommen" "0" \
      "$(mind_rettungen "$P" | grep -c 'zzz_spaeter')"
pruef "   ... und die zwei aus dem Merker bleiben" "2" "$(zahl "$P")"

echo
echo "=== 7) ⛔ Die Auswahl steht an EINER Stelle ==="
MA="$R/skills/mind-all/SKILL.md"
MU="$R/skills/mind-update/SKILL.md"
pruef "mind-all ruft mind_rettungen"    "1" "$(grep -c 'mind_rettungen "\$PROJ"' "$MA")"
pruef "mind-update ruft mind_rettungen" "1" "$(grep -c 'RESCUED_ALLE=\$(mind_rettungen' "$MU")"
# ⛔ Die kaputte Zeile darf nicht zurueckkommen. Sie sah harmlos aus und war
#    der ganze Fehler.
# ⛔ GEZAEHLT WIRD DIE AUSFUEHRBARE ZEILE, NICHT IHRE ERWAEHNUNG. Die
#    erste Fassung zaehlte auch den Kommentar, der den alten Fehler
#    ERKLAERT — und war rot, obwohl der Code stimmte.
# ⚠ DRITTES MAL AN EINEM TAG in dieselbe Falle (AGENT_MAX=0,
#   MIND_SYNC_FORCE_TOKENS, hier). `env-vars.md` dokumentiert sie seit
#   dem 27.08.2026 fuer MIND_NOTFALL_TOKENS: "die Zaehlung per
#   `grep <name>` zaehlt ERWAEHNUNGEN, nicht Lesezugriffe".
pruef "⛔ die -f-Pruefung auf mehrzeiligen Text ist weg" "0" \
      "$(grep -cE '^[[:space:]]*.\[ -n .\$RESCUED' "$MU")"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
