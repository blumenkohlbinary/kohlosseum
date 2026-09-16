#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
# Etappe 22 (v5.116.0) — die Notbremse frisst keinen Lauf mehr, getippte Bloecke sind sichtbar.
#   Doros Creator-Lauf 16.09.2026 14:34-15:05 (5.112.0): Kopf-Block erst NACH Step 2.9 ->
#   analyzed-scopes schon .done -> kette=0 -> `: > "$q"` loeschte alle fuenf Skill-Bloecke
#   eines echten Laufs. Danach tippte sie die Quittung nach: fuenf Startzeilen 15:17:27-15:17:32,
#   39 Schritte in fuenf Sekunden. mind_schritt_bilanz las 39/39, mind_sync_voll rc 0.
#   Fixtures: ihre Datei (nur gelesen, kopiert) und Ritas echter Lauf 13.09. (3-9 min je Block).
#   §1 Notbremse: frische Bloecke bleiben, alte werden geleert, 600 Zeilen rotieren
#   §2 getippte Quittung -> FORMAL (nachgetippt), formal-<skill> in ungepruef, Regler MIND_SCHRITT_MIN_S
#   §3 Skill-Text: „wird nicht nachgetippt — der Block wird neu gefahren"
# Gegen 5.115.0: §1/§2 rot.
set -u
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
# shellcheck disable=SC1090
. "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh" >/dev/null 2>&1
FX="$(dirname "$0")/fixtures"
OK=0; ROT=0
janein() { if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  [ok ] %s\n' "$1"
           else ROT=$((ROT+1)); printf '  [ROT] %s — erwartet %s, bekommen %s\n' "$1" "$2" "$3"; fi; }
unset MIND_DEBUG_DIR MIND_SCHRITT_MIN_S
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); ALT=$(date -u -d '-3 days' +%Y-%m-%dT%H:%M:%SZ)
zeile_start() { printf '{"ereignis":"start","skill":"%s","erwartet":"verdichten","ts":"%s","code":"5.116.0","text":"5.116.0","versionsbruch":false}\n' "$1" "$2"; }
zeile_schritt() { printf '{"ereignis":"schritt","name":"%s","status":"gelaufen","bytes":50,"quelle":"datei","ts":"%s"}\n' "$1" "$2"; }

echo "== §1  Notbremse: frische Bloecke bleiben, alte werden geleert, 600 Zeilen rotieren =="
P=$(mktemp -d)/p; mkdir -p "$P/.claude-mind"; Q="$P/.claude-mind/schritt-quittung.jsonl"
{ zeile_start mind-all "$NOW"; for s in mind-files mind-claudemd mind-memory mind-rules mind-update; do zeile_start "$s" "$NOW"; zeile_schritt verdichten "$NOW"; done; } > "$Q"
_VOR=$(grep -c '' "$Q")
mind_schritt_start "$P" mind-files verdichten >/dev/null 2>&1   # kein analyzed-scopes: Einzelskill
janein "frische Bloecke (jetzt) + Einzelskill-Start: nichts weg, eine Zeile dazu" "$((_VOR + 1))" "$(grep -c '' "$Q")"
janein "   ... alle Startzeilen liegen noch (Kopf + fuenf + die neue = 7)" 7 "$(grep -c '"ereignis":"start","skill":"mind-' "$Q")"
{ zeile_start mind-all "$ALT"; for s in mind-files mind-claudemd; do zeile_start "$s" "$ALT"; zeile_schritt verdichten "$ALT"; done; } > "$Q"
mind_schritt_start "$P" mind-files verdichten >/dev/null 2>&1
janein "nur 3 Tage alte Bloecke + Einzelskill: geleert wie bisher (1 Zeile)" 1 "$(grep -c '' "$Q")"
# 600 Zeilen mit Kettenmarke: rotieren, der letzte Lauf (ab letzter mind-all-Startzeile) bleibt
: > "$Q"; i=0; while [ $i -lt 590 ]; do zeile_schritt "alt$i" "$ALT"; i=$((i+1)); done >> "$Q"
{ zeile_start mind-all "$NOW"; for s in mind-files mind-claudemd; do zeile_start "$s" "$NOW"; zeile_schritt verdichten "$NOW"; done; } >> "$Q"
printf 'run_started=%s\n' "$(date -u -d '-60 seconds' +%s)" > "$P/.claude-mind/analyzed-scopes"   # vor dem Kopf (§1 aus 5.113.0)
mind_schritt_start "$P" mind-memory verdichten >/dev/null 2>&1
janein "600 Zeilen in der Kette: rotiert — letzter Lauf da (mind-all-Kopf + 2 Bloecke + neue Zeile = 6)" 6 "$(grep -c '' "$Q")"
janein "   ... erste Zeile ist der mind-all-Kopf" ja "$(head -1 "$Q" | grep -q '"skill":"mind-all"' && echo ja || echo nein)"
janein "   ... keine der 590 alten Schrittzeilen mehr" 0 "$(grep -c '"name":"alt' "$Q")"
rm -rf "$(dirname "$P")"

echo "== §2  getippte Quittung: Doros Datei -> fuenf FORMAL, Ritas -> keins =="
P=$(mktemp -d)/p; mkdir -p "$P/.claude-mind"; cp "$FX/schritt-quittung_getippt_creator_2026-09-16.jsonl" "$P/.claude-mind/schritt-quittung.jsonl"
_B=$(mind_schritt_bilanz "$P" --alle 2>/dev/null)
janein "Doro 16.09.: FORMAL=5" ja "$(printf '%s\n' "$_B" | grep -q '^  FORMAL=5$' && echo ja || echo nein)"
janein "   ... vier ueber den Start-Abstand (< 60 s), einer ueber 8 Schritte in 1 s" ja "$([ "$(printf '%s\n' "$_B" | grep -c 'nachgetippt; MIND_SCHRITT_MIN_S=60')" = 4 ] && printf '%s\n' "$_B" | grep -q 'mind-files (8 Schritte in 1 s — nachgetippt)' && echo ja || echo nein)"
janein "   ... mind_ungepruef_bilden traegt alle fuenf formal-<skill>" 5 "$(mind_ungepruef_bilden "$P" 2>/dev/null | tr ',' '\n' | grep -c '^formal-mind-')"
janein "   ... der Lauf ist damit teil (mind_lauf_voll)" teil "$(mind_lauf_voll "$P" "" 4 2>/dev/null)"
janein "   Regler: MIND_SCHRITT_MIN_S=1 -> der Start-Abstand greift nicht mehr, vier Bloecke bleiben ueber >= 5 Schritte in 10 s FORMAL" ja "$(MIND_SCHRITT_MIN_S=1 mind_schritt_bilanz "$P" --alle 2>/dev/null | grep -q '^  FORMAL=4$' && echo ja || echo nein)"
cp "$FX/schritt-quittung_echt_mindmanager_2026-09-13.jsonl" "$P/.claude-mind/schritt-quittung.jsonl"
_R=$(mind_schritt_bilanz "$P" --alle 2>/dev/null)
janein "Rita 13.09. (echter Lauf, 3-9 min je Block): kein FORMAL" nein "$(printf '%s\n' "$_R" | grep -q 'FORMAL' && echo ja || echo nein)"
rm -rf "$(dirname "$P")"

echo "== §4  v5.118.0 (Etappe 26 §1): Kopf -> Snapshot (Zeitabstand) -> Skill: rc 0 =="
# Veras Zustellplan-Lauf 22:41: run_started= kam 12 s nach dem Kopf -> mind-files brach ab.
P=$(mktemp -d)/p; mkdir -p "$P/.claude-mind"; Q="$P/.claude-mind/schritt-quittung.jsonl"
zeile_start mind-all "$(date -u -d '-30 seconds' +%Y-%m-%dT%H:%M:%SZ)" > "$Q"
printf 'run_started=%s\n' "$(date -u -d '-15 seconds' +%s)" > "$P/.claude-mind/analyzed-scopes"   # 15 s NACH dem Kopf (Snapshot-Dauer)
janein "Kopf 30 s alt, run_started 15 s spaeter: mind-files rc 0" 0 "$(mind_schritt_start "$P" mind-files verdichten >/dev/null 2>&1; echo $?)"
janein "   mind_kopf_epoch liefert die Sekunde des Kopfes" ja "$([ "$(mind_kopf_epoch "$P")" = "$(date -u -d "$(head -1 "$Q" | sed -n 's/.*"ts":"\([^"]*\)".*/\1/p')" +%s)" ] && echo ja || echo nein)"
janein "   Gegenprobe: Kopf 2 h alt (voriger Lauf), run_started jetzt -> rc 1" 1 "$(zeile_start mind-all "$(date -u -d '-2 hours' +%Y-%m-%dT%H:%M:%SZ)" > "$Q"; printf 'run_started=%s\n' "$(date -u +%s)" > "$P/.claude-mind/analyzed-scopes"; mind_schritt_start "$P" mind-claudemd verdichten >/dev/null 2>&1; echo $?)"
janein "mind-all Step 0 schreibt run_started aus dem Kopf (mind_kopf_epoch)" ja "$(grep -q 'echo "run_started=$(mind_kopf_epoch "$PROJ")"' "$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md" && echo ja || echo nein)"
rm -rf "$(dirname "$P")"

echo "== §3  Skill-Text =="
n=0; for s in mind-files mind-claudemd mind-memory mind-rules mind-update mind-all; do grep -q 'Eine geloeschte oder leere Schritt-Quittung wird nicht nachgetippt' "$CLAUDE_PLUGIN_ROOT/skills/$s/SKILL.md" && n=$((n+1)); done
janein "die fuenf Skills und mind-all sagen: nicht nachtippen, Block neu fahren" 6 "$n"

echo
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
