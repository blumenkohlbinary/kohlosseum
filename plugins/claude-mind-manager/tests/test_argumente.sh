#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
# =============================================================================
#  ARGUMENTE DER QUITTUNGS-SCHREIBER + STEMPEL-PFLICHT  (NEU v5.125.0, Etappe 37 §1/§3)
# =============================================================================
#
# ⛔ WOZU. Ritas /mind-all vom 18.09.2026 22:29 (voll, rc 0) liess zwei Fehler STILL durch:
#
#   §1  `mind_agent_dispatch "$PROJ" "<bereich>"` — Argumente vertauscht — lief mit rc 0,
#       `bereich` war der Projektpfad, und `_mind_quittung_pfad "<bereich>"` legte im cwd
#       vier Streuner-Ordner an (claude-md/ custom-context/ memory/ rules/, je
#       .claude-mind/agent-quittung.jsonl). Aufgefallen erst in der Bilanz (DISPATCH=0 bei
#       ERGEBNIS=8). Jetzt weist EINE Hilfsfunktion (_mind_args_pruefen) vor jedem Schreiber
#       ab: unbekannter Bereich, Pfadtrenner im Namen, Projekt kein Verzeichnis -> rc 2,
#       nichts geschrieben, kein Ordner.
#   §3  der mind-all-Kopf-Block stand ohne MIND_SKILL_VERSION da (text:unbekannt) — ein
#       VERSIONSBRUCH fuer mind-all konnte so nie feuern. Jetzt: fuer jeden Skill, den das
#       Plugin unter skills/<skill>/SKILL.md fuehrt, ist ein fehlender Stempel rc 1, KEINE
#       Startzeile; freie Namen (Prueffaelle, fremde Skills) wie bisher.
#
# ⛔ Gegen 5.124.0 gefahren: 23 von 35 rot — §1 18 (rc 0, Ordner entstanden, keine Meldung),
#    §3 5 (Startzeile mit text:unbekannt, STEMPEL-Hinweis in der Bilanz, alle zehn rc 0).
# =============================================================================
set -u
WURZEL="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIB="$WURZEL/hooks/lib.sh"
export CLAUDE_PLUGIN_ROOT="$WURZEL"

OK=0; ROT=0
janein() {
  if [ "$2" = "$3" ]; then
    printf '    OK   %-64s ist=%s\n' "$1" "$3"; OK=$((OK + 1))
  else
    printf '    FEHL %-64s ist=%-12s soll=%s\n' "$1" "$3" "$2"; ROT=$((ROT + 1))
  fi
}
[ -f "$LIB" ] || { echo "ABBRUCH: $LIB fehlt"; exit 2; }
# shellcheck disable=SC1090
. "$LIB" >/dev/null 2>&1

T=$(mktemp -d "${TMPDIR:-/tmp}/Mind Arg XXXXXX") || exit 2
P="$T/proj mit leer"; mkdir -p "$P/.claude-mind"
cd "$T" || exit 2     # der cwd, in dem 18.09. die Streuner entstanden
Q="$P/.claude-mind/agent-quittung.jsonl"
S="$P/.claude-mind/schritt-quittung.jsonl"
streuner() { ls -d claude-md custom-context memory rules 4 mind-files "$1" 2>/dev/null | wc -l | tr -d ' '; }

echo "=============================================================================="
echo "  §1  vertauschte / ungueltige Argumente -> rc 2, nichts geschrieben, kein Ordner"
echo "=============================================================================="
_R=$(mind_agent_dispatch "$P" "claude-md" 2>&1 >/dev/null); _RC=$?
janein "mind_agent_dispatch <projekt> <bereich> (vertauscht): rc 2" 2 "$_RC"
janein "   ... kein Streuner-Ordner im cwd" 0 "$(streuner x)"
janein "   ... keine Quittung geschrieben" nein "$([ -f "$Q" ] && echo ja || echo nein)"
janein "   ... Meldung nennt die richtige Aufrufform" ja "$(printf '%s\n' "$_R" | grep -q 'mind_agent_dispatch <bereich> \[projekt\]' && echo ja || echo nein)"
janein "mind_agent_dispatch foo (unbekannter Bereich): rc 2" 2 "$(mind_agent_dispatch foo "$P" >/dev/null 2>&1; echo $?)"
janein "   ... Meldung nennt die erlaubte Menge" ja "$(mind_agent_dispatch foo "$P" 2>&1 >/dev/null | grep -q 'claude-md memory rules custom-context project-scanner' && echo ja || echo nein)"
janein "mind_agent_dispatch claude-md <projekt> (richtig): rc 0, eine Zeile" 1 "$(mind_agent_dispatch claude-md "$P" >/dev/null 2>&1; grep -c '"dispatch"' "$Q" 2>/dev/null)"
janein "mind_agent_dispatch project-scanner (der eine Nicht-Sync-Bereich): rc 0" 0 "$(mind_agent_dispatch project-scanner "$P" >/dev/null 2>&1; echo $?)"
janein "mind_agent_dispatch memory <kein-verzeichnis>: rc 2" 2 "$(mind_agent_dispatch memory "$T/gibt es nicht" >/dev/null 2>&1; echo $?)"
janein "   ... und der Ordner ist NICHT entstanden (kein mkdir -p ausserhalb)" nein "$([ -d "$T/gibt es nicht" ] && echo ja || echo nein)"
janein "mind_agent_quittung_start 4 <projekt> (vertauscht): rc 2" 2 "$(mind_agent_quittung_start 4 "$P" >/dev/null 2>&1; echo $?)"
janein "   ... kein Ordner '4' im cwd" 0 "$(streuner x)"
janein "mind_agent_quittung_start <projekt> vier (keine Zahl): rc 2" 2 "$(mind_agent_quittung_start "$P" vier >/dev/null 2>&1; echo $?)"
janein "mind_agent_quittung_start <projekt> 4 (richtig): rc 0" 0 "$(mind_agent_quittung_start "$P" 4 >/dev/null 2>&1; echo $?)"
janein "mind_agent_ergebnis <projekt> --datei f memory (vertauscht): rc 2" 2 "$(mind_agent_ergebnis "$P" --datei "$P/x" memory >/dev/null 2>&1; echo $?)"
mind_agent_dispatch memory "$P" >/dev/null 2>&1   # v5.126.0: ergebnis braucht den dispatch (Ziel gleich)
janein "mind_agent_ergebnis memory 5 <projekt> (Zahlform, bekannt): rc 0, bytes:0" 1 "$(mind_agent_ergebnis memory 5 "$P" >/dev/null 2>&1; grep -c '"ergebnis","bereich":"memory","bytes":0' "$Q")"
janein "mind_agent_uebersprungen custom-context 0 <kein-verzeichnis>: rc 2" 2 "$(mind_agent_uebersprungen custom-context 0 "$T/nein" >/dev/null 2>&1; echo $?)"
janein "mind_agent_uebersprungen rules 0 <projekt>: weiter rc 1 (nur custom-context)" 1 "$(mind_agent_uebersprungen rules 0 "$P" >/dev/null 2>&1; echo $?)"
janein "mind_schritt_start mind-files <projekt> a (vertauscht): rc 2" 2 "$(mind_schritt_start mind-files "$P" a >/dev/null 2>&1; echo $?)"
janein "   ... kein Ordner 'mind-files' im cwd, keine Schritt-Quittung" "0 nein" "$(streuner x) $([ -f "$S" ] && echo ja || echo nein)"
janein "mind_schritt <projekt> gelaufen 5 a (vertauscht): rc 2" 2 "$(mind_schritt "$P" gelaufen 5 a >/dev/null 2>&1; echo $?)"
janein "mind_schritt a gelaufen 5 <kein-verzeichnis>: rc 2" 2 "$(mind_schritt a gelaufen 5 "$T/nein" >/dev/null 2>&1; echo $?)"
janein "mind_schritt_start <projekt> x a (freier Name, richtig): rc 0" 0 "$(mind_schritt_start "$P" x a >/dev/null 2>&1; echo $?)"
janein "mind_schritt a gelaufen 5 <projekt> (richtig): rc 0" 0 "$(mind_schritt a gelaufen 5 "$P" >/dev/null 2>&1; echo $?)"
janein "ohne Projekt-Argument (Vorgabe mind_projekt_wurzel): rc 0 wie bisher" 0 "$(cd "$P" && mind_agent_dispatch rules >/dev/null 2>&1; echo $?)"
janein "mind_ungepruef_bilden nutzt dieselbe Menge (_MIND_SYNC_BEREICHE, keine zweite Liste)" 1 "$(grep -c 'for _b in \$_MIND_SYNC_BEREICHE' "$LIB")"
janein "Skill-Texte zeigen die Reihenfolge <bereich> <projekt> weiterhin ausdruecklich" ja "$(grep -q 'mind_agent_dispatch "<bereich>" "\$PROJ"' "$WURZEL/skills/mind-update/SKILL.md" && echo ja || echo nein)"

echo
echo "=============================================================================="
echo "  §1b (v5.126.0, Etappe 38 §1)  mind_agent_ergebnis verlangt den dispatch desselben Laufs"
echo "=============================================================================="
# 03.09./13.09./18.09.2026: dispatch vergessen, Ergebnisse geschrieben, DISPATCH=0 bei ERGEBNIS=n —
# erst die Bilanz sah es. Gegen 5.125.0: die drei Abweisungen rot (rc 0, Zeile geschrieben).
P2="$T/proj zwei"; mkdir -p "$P2/.claude-mind"; Q2="$P2/.claude-mind/agent-quittung.jsonl"
printf 'x\n' > "$P2/erg.md"
_E=$(mind_agent_ergebnis memory --datei "$P2/erg.md" "$P2" 2>&1 >/dev/null); _RC=$?
janein "ergebnis ohne jede Quittung: rc 2, nichts geschrieben" "2 nein" "$_RC $([ -f "$Q2" ] && echo ja || echo nein)"
janein "   ... Meldung: dispatch fehlt, Agent erneut MIT Quittung" ja "$(printf '%s\n' "$_E" | grep -q 'dispatch fehlt' && printf '%s\n' "$_E" | grep -q 'MIT Quittung' && echo ja || echo nein)"
mind_agent_quittung_start "$P2" 4 >/dev/null 2>&1
janein "ergebnis nach Start, ohne dispatch: rc 2" 2 "$(mind_agent_ergebnis memory --datei "$P2/erg.md" "$P2" >/dev/null 2>&1; echo $?)"
mind_agent_dispatch rules "$P2" >/dev/null 2>&1
janein "dispatch fuer ANDEREN Bereich (rules) zaehlt nicht fuer memory: rc 2" 2 "$(mind_agent_ergebnis memory --datei "$P2/erg.md" "$P2" >/dev/null 2>&1; echo $?)"
janein "   ... Zahlform ebenso: rc 2" 2 "$(mind_agent_ergebnis memory 5 "$P2" >/dev/null 2>&1; echo $?)"
janein "   ... keine ergebnis-Zeile in der Quittung" 0 "$(grep -c '"ereignis":"ergebnis"' "$Q2")"
mind_agent_dispatch memory "$P2" >/dev/null 2>&1
janein "dispatch memory, dann ergebnis memory: rc 0, eine ergebnis-Zeile" "0 1" "$(mind_agent_ergebnis memory --datei "$P2/erg.md" "$P2" >/dev/null 2>&1; echo "$? $(grep -c '"ereignis":"ergebnis","bereich":"memory"' "$Q2")")"
mind_agent_quittung_start "$P2" 4 >/dev/null 2>&1     # neuer Lauf: der alte dispatch zaehlt nicht mehr
janein "neuer Lauf (neue Start-Zeile): alter dispatch zaehlt nicht, rc 2" 2 "$(mind_agent_ergebnis memory --datei "$P2/erg.md" "$P2" >/dev/null 2>&1; echo $?)"
janein "Skill-Text mind-update nennt die Folge (dispatch fehlt)" ja "$(grep -q 'ergebnis ohne dispatch\|dispatch fehlt' "$WURZEL/skills/mind-update/SKILL.md" && echo ja || echo nein)"

echo
echo "=============================================================================="
echo "  §3  MIND_SKILL_VERSION muss in DERSELBEN Bash stehen wie mind_schritt_start"
echo "=============================================================================="
rm -f "$S"
( unset MIND_SKILL_VERSION; mind_schritt_start "$P" mind-all a >/dev/null 2>&1 ); _RC=$?
janein "mind-all ohne Stempel: rc 1" 1 "$_RC"
janein "   ... KEINE Startzeile geschrieben (kein text:unbekannt mehr)" 0 "$([ -f "$S" ] && grep -c '"start"' "$S" || echo 0)"
janein "   ... Bilanz --alle meldet KEINEN STEMPEL-UNGELESEN-Hinweis" 0 "$(mind_schritt_bilanz "$P" --alle 2>/dev/null | grep -c 'STEMPEL UNGELESEN')"
janein "   ... Meldung nennt den Kopf-Block in EINER Bash" ja "$( (unset MIND_SKILL_VERSION; mind_schritt_start "$P" mind-all a 2>&1 >/dev/null) | grep -q 'STEMPEL FEHLT' && echo ja || echo nein)"
_N=0; for sk in "$WURZEL"/skills/*/SKILL.md; do sk=$(basename "$(dirname "$sk")"); ( unset MIND_SKILL_VERSION; mind_schritt_start "$P" "$sk" a >/dev/null 2>&1 ) || _N=$((_N + 1)); done
janein "alle Skills des Plugins ohne Stempel: jeder rc != 0" "$(ls -1 "$WURZEL"/skills/*/SKILL.md | wc -l | tr -d ' ')" "$_N"
janein "mind-all MIT Stempel (dieselbe Bash): rc 0, Startzeile text=<stempel>" 1 "$( (export MIND_SKILL_VERSION="$(basename "$WURZEL")"; mind_schritt_start "$P" mind-all a >/dev/null 2>&1); grep -c "\"skill\":\"mind-all\".*\"text\":\"$(basename "$WURZEL")\"" "$S")"
janein "freier Name ohne Stempel (kein skills/<name>/SKILL.md): rc 0 wie bisher" 0 "$( (unset MIND_SKILL_VERSION; mind_schritt_start "$P" fremd a >/dev/null 2>&1; echo $?) )"
janein "alle zehn Skill-Texte: MIND_SKILL_VERSION und mind_schritt_start im SELBEN Codeblock" 10 \
  "$(for sk in "$WURZEL"/skills/*/SKILL.md; do awk '/^```bash/{b=1;v=0;s=0;next} /^```/{if(b&&v&&s){print "ja";exit} b=0;next} b&&/^MIND_SKILL_VERSION=/{v=1} b&&/^mind_schritt_start /{s=1}' "$sk"; done | grep -c ja)"

cd / && rm -rf "$T"
echo
echo "=============================================================================="
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
