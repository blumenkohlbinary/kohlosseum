#!/usr/bin/env bash
# Die UEBERGABE gehoert der Sitzung, die kompaktiert hat (v5.61.0).
#
# ⛔ DER FALL, FUER DEN SIE GEBAUT IST, IST FALL 2 — und er ist gemessen, nicht
#    vermutet. Am 10.09.2026 ohne Kompaktierung nachgestellt: `UEBERGABE` von
#    Hand angelegt, zwei Sitzungen schicken einen Prompt.
#      Sitzung B fragt zuerst -> B bekommt den Arbeitsstand von A
#      danach ist der Merker WEG
#      Sitzung A fragt spaeter -> bekommt nichts
#    Der Arbeitsstand der einen landet vollstaendig in der anderen, samt deren
#    Auftrag — und liest sich beim Empfaenger wie der eigene.
#
# ⭐ DIE REGEL DAHINTER: was GETAN WERDEN MUSS ist projektweit (`OPEN`,
#    `COMPACT-FAELLIG`, `sync-stand`), wer es GERADE TAT ist sitzungsbezogen
#    (`UEBERGABE`, `mind-all.lock`).
#
# ⚠ FALL 4 IST DIE GEGENPROBE ZUM RUECKFALL: ein Merker aus einer Fassung vor
#   v5.61.0 traegt keine Kennung und wird weiterhin vom ersten Leser genommen.
#   Das ist Absicht — sonst laege er fuer immer — und endlich.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PS="$R/hooks/prompt-submit.sh"
SS="$R/hooks/session-start.sh"
GRUEN=0; ROT=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pruef() { if [ "$2" = "$3" ]; then GRUEN=$((GRUEN+1)); echo "  [ok ] $1"
  else ROT=$((ROT+1)); echo "  [ROT] $1 (erwartet '$2', war '$3')"; fi; }

# shellcheck disable=SC1090
. "$R/hooks/lib.sh" 2>/dev/null

P="$TMP/proj"; mkdir -p "$P/.claude-mind/rescued"
printf '## Auftrag\nDEN UMBAU VON SITZUNG A ZU ENDE BRINGEN\n' > "$P/.claude-mind/rescued/a_RESUME.md"
printf '## Auftrag\nDIE MESSUNG VON SITZUNG B\n'               > "$P/.claude-mind/rescued/b_RESUME.md"

lege() {  # lege <sid|""> <resume-datei>
  local ziel="$P/.claude-mind/rescued/UEBERGABE"
  [ -n "$1" ] && ziel="$ziel-$1"
  printf 'ts=x\nresume=%s/.claude-mind/rescued/%s\n' "$P" "$2" > "$ziel"
}
ruf() {  # ruf <sid> -> Ausgabe von prompt-submit
  printf '{"cwd":"%s","session_id":"%s","prompt":"hi"}' "$P" "$1" \
    | CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PROJECT_DIR="$P" bash "$PS" 2>/dev/null
}
ruf_start() {  # ruf_start <sid> -> Ausgabe von session-start
  printf '{"cwd":"%s","session_id":"%s","source":"startup"}' "$P" "$1" \
    | CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PROJECT_DIR="$P" bash "$SS" 2>/dev/null
}
sauber() { rm -f "$P/.claude-mind/rescued/UEBERGABE"* 2>/dev/null; }

echo "=== 1) Der Pfad traegt die Kennung ==="
pruef "mind_uebergabe_pfad haengt die Kennung an" \
  "$P/.claude-mind/rescued/UEBERGABE-SITZUNG-A" \
  "$(mind_uebergabe_pfad "$P" "SITZUNG-A")"
pruef "⛔ ohne Kennung: nosession, nicht leer" \
  "$P/.claude-mind/rescued/UEBERGABE-nosession" \
  "$(mind_uebergabe_pfad "$P" "")"
pruef "⛔ Sonderzeichen fliegen raus (Dateiname)" \
  "$P/.claude-mind/rescued/UEBERGABE-abc123" \
  "$(mind_uebergabe_pfad "$P" 'a/b\\c*1 2 3')"

echo
echo "=== 2) ⛔ DER FALL: B holt sich NICHT den Arbeitsstand von A ==="
sauber; lege "SITZUNG-A" a_RESUME.md
B=$(ruf "SITZUNG-B")
pruef "B bekommt NICHTS von A" "0" "$(printf '%s' "$B" | grep -c 'SITZUNG A ZU ENDE')"
pruef "⭐ und A's Merker liegt noch" "ja" \
  "$([ -f "$P/.claude-mind/rescued/UEBERGABE-SITZUNG-A" ] && echo ja || echo nein)"
A=$(ruf "SITZUNG-A")
pruef "⭐ A bekommt ihren eigenen Arbeitsstand" "1" \
  "$(printf '%s' "$A" | grep -c 'SITZUNG A ZU ENDE')"
pruef "   ... und danach ist ihr Merker verbraucht" "nein" \
  "$([ -f "$P/.claude-mind/rescued/UEBERGABE-SITZUNG-A" ] && echo ja || echo nein)"

echo
echo "=== 3) ⭐ Zwei Uebergaben nebeneinander stoeren sich nicht ==="
sauber; lege "SITZUNG-A" a_RESUME.md; lege "SITZUNG-B" b_RESUME.md
A=$(ruf "SITZUNG-A")
pruef "A bekommt A" "1" "$(printf '%s' "$A" | grep -c 'SITZUNG A ZU ENDE')"
pruef "⛔ A bekommt NICHT B" "0" "$(printf '%s' "$A" | grep -c 'MESSUNG VON SITZUNG B')"
B=$(ruf "SITZUNG-B")
pruef "B bekommt B" "1" "$(printf '%s' "$B" | grep -c 'MESSUNG VON SITZUNG B')"

echo
echo "=== 4) ⚠ RUECKFALL: ein Merker OHNE Kennung (vor v5.61.0) ==="
sauber; lege "" a_RESUME.md
B=$(ruf "SITZUNG-B")
pruef "wird vom ersten Leser genommen (Absicht, endlich)" "1" \
  "$(printf '%s' "$B" | grep -c 'SITZUNG A ZU ENDE')"
# ⛔ GEGENPROBE: liegt die EIGENE daneben, gewinnt sie — der Rueckfall
#    ueberstimmt nie den richtigen Merker.
sauber; lege "" b_RESUME.md; lege "SITZUNG-A" a_RESUME.md
A=$(ruf "SITZUNG-A")
pruef "⭐ die eigene schlaegt den namenlosen Merker" "1" \
  "$(printf '%s' "$A" | grep -c 'SITZUNG A ZU ENDE')"
pruef "   ... und der namenlose liegt noch" "ja" \
  "$([ -f "$P/.claude-mind/rescued/UEBERGABE" ] && echo ja || echo nein)"

echo
echo "=== 5) session-start.sh haelt sich an dieselbe Trennung ==="
sauber; lege "SITZUNG-A" a_RESUME.md
S=$(ruf_start "SITZUNG-B")
pruef "B bekommt beim Start NICHTS von A" "0" \
  "$(printf '%s' "$S" | grep -c 'SITZUNG A ZU ENDE')"
pruef "⭐ und A's Merker liegt noch" "ja" \
  "$([ -f "$P/.claude-mind/rescued/UEBERGABE-SITZUNG-A" ] && echo ja || echo nein)"

echo
echo "  $GRUEN gruen · $ROT rot"
[ "$ROT" -eq 0 ]
