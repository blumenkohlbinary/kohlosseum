#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Die teuren Skills pruefen das Kontingent, BEVOR sie starten (v5.163.0, Etappe 65 §3).
#
# ⛔ Nutzer 29.10.2026: „in zukunft soll mind nicht laufen wenn kontigent an der grenze ist — sollen die vorher
#    pruefen". Geplant in PLAN-kontingent-sperre.md, bis 5.162.0 nie gebaut: ein Messlauf kostete 32,8 Mio Tokens.
# Gegen 5.162.0 sind alle Abschnitte rot (die Funktion gibt es dort nicht).
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$R"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
P="$TMP/projekt mit leer"; mkdir -p "$P/.claude-mind"
export CLAUDE_CODE_SESSION_ID="aaaa1111-0000-0000-0000-00000000beef"
K() { ( . "$R/hooks/lib.sh"; unset MIND_KONTINGENT_MAX; mind_kontingent_pruefen "$P" "$@" >/dev/null 2>&1; echo $? ); }
ST() { ( . "$R/hooks/lib.sh"; mind_kontingent_pruefen "$P" "$@" >/dev/null 2>&1; echo "${MIND_KONTINGENT_STAND:-leer}" ); }

echo "=== 1) unter und ueber der Schwelle (Vorgabe 80) ==="
pruef "5 % / 6 %: darf starten" "$(K mind-all '' 5 6)" "0"
pruef "  ... Stand ok" "$(ST mind-all '' 5 6)" "ok"
pruef "85 % (5h): startet nicht" "$(K mind-all '' 85 6)" "1"
pruef "Woche 80 % genau: startet nicht" "$(K mind-all '' 10 80)" "1"
pruef "79 %: darf" "$(K mind-all '' 79 79)" "0"
pruef "mit Prozentzeichen" "$(K mind-all '' 5% 90%)" "1"
pruef "Regler 90: 85 % darf" "$( ( . "$R/hooks/lib.sh"; MIND_KONTINGENT_MAX=90 mind_kontingent_pruefen "$P" mind-all '' 85 6 >/dev/null 2>&1; echo $? ) )" "0"
M=$( ( . "$R/hooks/lib.sh"; mind_kontingent_pruefen "$P" mind-all '' 85 6 2>&1 ) )
pruef "Meldung nennt die Werte" "$(printf '%s\n' "$M" | grep -c '85%.*6%')" "1"

echo "=== 2) ⛔ nicht messbar heisst: es startet nichts ==="
pruef "stehengebliebener Platzhalter" "$(K mind-all '' '<5h>' '<woche>')" "3"
pruef "unbekannt" "$(K mind-cleaner '' unbekannt 5)" "3"
pruef "nur ein Wert" "$(K mind-learnings '' 5)" "3"
# v5.174.0 (Etappe 67 N2c): Ritas Lauf 30.10.2026 — get_usage listete das 5-h-Fenster nicht, 0 wurde eingesetzt
# v5.175.0 (Anton 31.10.2026): fehlt NUR das 5-h-Fenster, zaehlt die Woche allein — sichtbar, nie still
pruef "5-h-Fenster fehlt, Woche 23 %: darf" "$(K mind-all '' fehlt 23)" "0"
M=$( ( . "$R/hooks/lib.sh"; mind_kontingent_pruefen "$P" mind-all '' fehlt 23 2>&1 ) )
pruef "   ... und sagt es sichtbar" "$(printf '%s\n' "$M" | grep -c '5-h-Fenster nicht gemeldet, nur Woche geprueft')" "1"
pruef "5-h-Fenster fehlt, Woche 85 %: startet nicht" "$(K mind-all '' fehlt 85)" "1"
pruef "Woche fehlt: startet nicht" "$(K mind-all '' 23 fehlt)" "3"
M=$( ( . "$R/hooks/lib.sh"; mind_kontingent_pruefen "$P" mind-all '' 23 fehlt 2>&1 ) )
pruef "   ... und die Meldung sagt: fehlt ist nicht 0" "$(printf '%s\n' "$M" | grep -c 'fehlt ist nicht 0')" "1"
pruef "beide fehlen: startet nicht" "$(K mind-all '' fehlt fehlt)" "3"
pruef "der Kopftext verbietet die 0 in allen vier Skills" \
  "$(grep -l 'nie `0` einsetzen' "$R"/skills/mind-{all,cleaner,learnings,update}/SKILL.md | wc -l | tr -d ' ')" "4"

echo "=== 3) Notausgang, Kette, --quick ==="
pruef "--trotz-kontingent: darf, Stand trotz" "$(ST mind-all '--trotz-kontingent' 99 99)" "trotz"
mkdir -p "$P/.claude-mind/mind-all.lock"
pruef "Kette: mind-update ohne Werte darf" "$(K mind-update '' '<5h>' '<woche>')" "0"
pruef "⛔ Kette entbindet mind-all selbst NICHT (liegengebliebener Lock)" "$(K mind-all '' '<5h>' '<woche>')" "3"
rmdir "$P/.claude-mind/mind-all.lock"
pruef "mind-update --quick ohne Werte darf" "$(K mind-update '--quick' '<5h>' '<woche>')" "0"
pruef "⛔ --quick gilt nur fuer mind-update" "$(K mind-cleaner '--quick' '<5h>' '<woche>')" "3"

echo "=== 4) ⛔ mind_schritt_start: die vier teuren Skills nur nach der Pruefung ==="
S() { ( . "$R/hooks/lib.sh"; export MIND_KONTINGENT_PFLICHT=an MIND_SKILL_VERSION=x; "$@" >/dev/null 2>&1; echo $? ); }
for s in mind-all mind-update mind-cleaner mind-learnings; do
  pruef "$s ohne Pruefung: rc 1" "$(S mind_schritt_start "$P" "$s" a)" "1"
done
pruef "  ... keine Startzeile geschrieben" "$(grep -c '"skill":"mind-' "$P/.claude-mind/schritt-quittung.jsonl" 2>/dev/null || echo 0)" "0"
pruef "mind-files braucht sie nicht" "$(S mind_schritt_start "$P" mind-files a)" "0"
pruef "mind-all nach der Pruefung: rc 0" "$( ( . "$R/hooks/lib.sh"; export MIND_KONTINGENT_PFLICHT=an MIND_SKILL_VERSION=x; mind_kontingent_pruefen "$P" mind-all '' 5 6 >/dev/null 2>&1 && mind_schritt_start "$P" mind-all a >/dev/null 2>&1; echo $? ) )" "0"

echo "=== 5) die vier Kopf-Bloecke: Pruefung in DERSELBEN Bash, VOR mind_schritt_start ==="
for s in mind-all mind-update mind-cleaner mind-learnings; do
  pruef "$s" "$(awk '/^```bash/{b=1;k=0;next} /^```/{b=0;next} b&&/^mind_kontingent_pruefen /{k=1} b&&/^mind_schritt_start /{print (k?"ja":"nein");exit}' "$R/skills/$s/SKILL.md")" "ja"
done
pruef "mind-all-Text nennt get_usage" "$(grep -c 'mcp__ccd_session_mgmt__get_usage' "$R/skills/mind-all/SKILL.md")" "1"

echo "=== 6) der echte mind-all-Kopf mit stehengebliebenem Platzhalter startet NICHT ==="
KOPF="$TMP/kopf.sh"
awk '/^```bash/{b=1;buf="";next} /^```/{if(b&&buf~/mind_schritt_start /){printf "%s",buf;exit} b=0;next} b{buf=buf $0 "\n"}' "$R/skills/mind-all/SKILL.md" \
  | sed "s/'\$ARGUMENTS'/''/" > "$KOPF"
rm -f "$P/.claude-mind/schritt-quittung.jsonl"
A=$( cd "$P" && env MIND_KONTINGENT_PFLICHT=an CLAUDE_PROJECT_DIR="$P" bash "$KOPF" 2>&1 ); RC=$?
pruef "rc != 0" "$([ "$RC" -ne 0 ] && echo ja || echo nein)" "ja"
pruef "  ... aus dem richtigen Grund (nicht messbar)" "$(printf '%s
' "$A" | grep -c 'KONTINGENT NICHT MESSBAR')" "1"
pruef "  ... keine Startzeile" "$(grep -c '"skill":"mind-all"' "$P/.claude-mind/schritt-quittung.jsonl" 2>/dev/null || echo 0)" "0"
sed -i 's/"<5h>" "<woche>"/5 6/' "$KOPF"
( cd "$P" && env MIND_KONTINGENT_PFLICHT=an CLAUDE_PROJECT_DIR="$P" bash "$KOPF" >/dev/null 2>&1 )
pruef "Gegenprobe: mit Werten 5/6 startet derselbe Kopf" "$(grep -c '"skill":"mind-all"' "$P/.claude-mind/schritt-quittung.jsonl" 2>/dev/null || echo 0)" "1"
rm -rf "${P:?}/.claude-mind/mind-all.lock" 2>/dev/null

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
