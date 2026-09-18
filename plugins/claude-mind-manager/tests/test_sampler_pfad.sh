#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
# =============================================================================
#  SAMPLER-PFAD JE SITZUNG  (NEU v5.126.0, Etappe 38 §2 — Z271, Z445, Z498)
# =============================================================================
#
# ⛔ WOZU. Bis v5.125.0 stand der Live-Auszug fest unter /tmp/mind_update_session.json
#    (mind-compact: /tmp/mind_compact_data.json, mind-session-log: /tmp/session-slice.jsonl).
#    Zwei gleichzeitige Sitzungen ueberschrieben sich (Creator 16.09.2026), und die
#    Agent-Sandbox erreichte /tmp nicht (17./18.09.2026, memory-Agent, wiederholt).
#    Jetzt: <projekt>/.claude-mind/sampler/<name>.<sid>.<ext> — im Projekt, je Sitzung.
#
# ⛔ Gegen 5.125.0: mind_sampler_pfad fehlt (alle Faelle rot); die drei Skill-Texte
#    nennen /tmp fest.
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

T=$(mktemp -d "${TMPDIR:-/tmp}/Mind Sampler XXXXXX") || exit 2
P="$T/proj mit leer"; mkdir -p "$P/.claude-mind"
D="$P/.claude-mind/sampler"

echo "=============================================================================="
echo "  zwei Sitzungskennungen -> zwei Dateien, keine ueberschreibt die andere"
echo "=============================================================================="
A=$(CLAUDE_CODE_SESSION_ID="1be7f7a8-88a7-4842-99ac-56140694935c" mind_sampler_pfad "$P" mind-update)
B=$(CLAUDE_CODE_SESSION_ID="7d7660fd-e367-4451-a759-5ea604ab6140" mind_sampler_pfad "$P" mind-update)
janein "Sitzung A: <proj>/.claude-mind/sampler/mind-update.1be7f7a8.json" "$D/mind-update.1be7f7a8.json" "$A"
janein "Sitzung B: eigene Datei, gleicher Name, andere Kennung" "$D/mind-update.7d7660fd.json" "$B"
janein "   ... die beiden Pfade sind verschieden" ja "$([ "$A" != "$B" ] && echo ja || echo nein)"
janein "Ordner .claude-mind/sampler ist angelegt" ja "$([ -d "$D" ] && echo ja || echo nein)"
printf 'A\n' > "$A"; printf 'B\n' > "$B"
janein "beide schreiben: beide Dateien da, Inhalt getrennt" "A B" "$(cat "$A" "$B" | tr '\n' ' ' | sed 's/ $//')"
janein "Name mit Endung bleibt (session-slice.jsonl)" "$D/session-slice.1be7f7a8.jsonl" "$(CLAUDE_CODE_SESSION_ID=1be7f7a8-x mind_sampler_pfad "$P" session-slice.jsonl)"
janein "Name mit Endung .txt (range_stats.txt)" "$D/range_stats.1be7f7a8.txt" "$(CLAUDE_CODE_SESSION_ID=1be7f7a8-x mind_sampler_pfad "$P" range_stats.txt)"
janein "ohne Name: session.<sid>.json" "$D/session.1be7f7a8.json" "$(CLAUDE_CODE_SESSION_ID=1be7f7a8-x mind_sampler_pfad "$P")"
janein "leere Kennung -> unbekannt (fail-safe, im Namen sichtbar)" "$D/mind-update.unbekannt.json" "$(CLAUDE_CODE_SESSION_ID= mind_sampler_pfad "$P" mind-update)"
janein "Name mit Pfadtrenner wird nicht uebernommen (session)" "$D/session.1be7f7a8.json" "$(CLAUDE_CODE_SESSION_ID=1be7f7a8-x mind_sampler_pfad "$P" "../x")"
janein "Pfad liegt IM Projekt (Agent-Sandbox erreicht ihn), nicht unter /tmp" nein "$(case "$A" in /tmp/*) echo ja ;; *) echo nein ;; esac)"

echo
echo "=============================================================================="
echo "  Aufraeumen: nur die eigene Kennung"
echo "=============================================================================="
CLAUDE_CODE_SESSION_ID="1be7f7a8-88a7-4842-99ac-56140694935c" mind_sampler_pfad "$P" mind-compact >/dev/null
printf 'C\n' > "$D/mind-compact.1be7f7a8.json"
_N=$(CLAUDE_CODE_SESSION_ID="1be7f7a8-88a7-4842-99ac-56140694935c" mind_sampler_aufraeumen "$P")
janein "Sitzung A raeumt auf: 2 Dateien weg (mind-update + mind-compact)" 2 "$_N"
janein "   ... Sitzung B unberuehrt" "B" "$(cat "$B" 2>/dev/null)"
janein "   ... Sitzung A hat keine Datei mehr" 0 "$(ls "$D"/*.1be7f7a8.* 2>/dev/null | wc -l | tr -d ' ')"
_N=$(CLAUDE_CODE_SESSION_ID="7d7660fd-x" mind_sampler_aufraeumen "$P")
janein "Sitzung B raeumt auf: 1 weg, Ordner danach entfernt" "1 nein" "$_N $([ -d "$D" ] && echo ja || echo nein)"
janein "Aufraeumen ohne Ordner: rc 0, still" 0 "$(mind_sampler_aufraeumen "$P" >/dev/null 2>&1; echo $?)"

echo
echo "=============================================================================="
echo "  die Leser sind nachgezogen — kein fester /tmp-Pfad mehr"
echo "=============================================================================="
janein "mind-update: SESSION_SAMPLE_BASH aus mind_sampler_pfad" ja "$(grep -q '^SESSION_SAMPLE_BASH=$(mind_sampler_pfad "\$PROJ" mind-update)' "$WURZEL/skills/mind-update/SKILL.md" && echo ja || echo nein)"
janein "mind-update: raeumt am Ende auf" ja "$(grep -q '^mind_sampler_aufraeumen "\$PROJ"' "$WURZEL/skills/mind-update/SKILL.md" && echo ja || echo nein)"
janein "mind-compact: EXTRACT_JSON_BASH aus mind_sampler_pfad + Aufraeumen" 2 "$(grep -c 'mind_sampler_pfad "\$PROJ" mind-compact\|^mind_sampler_aufraeumen "\$PROJ"' "$WURZEL/skills/mind-compact/SKILL.md")"
janein "mind-session-log: Slice und range_stats je Sitzung + Aufraeumen" 3 "$(grep -c 'mind_sampler_pfad "\$PROJ" session-slice.jsonl\|mind_sampler_pfad "\$PROJ" range_stats.txt\|^mind_sampler_aufraeumen "\$PROJ"' "$WURZEL/skills/mind-session-log/SKILL.md")"
janein "kein Skill nennt /tmp/mind_update_session.json, /tmp/mind_compact_data.json, /tmp/session-slice.jsonl als Pfad" 0 "$(grep -lE '^[A-Z_]+="/tmp/(mind_update_session\.json|mind_compact_data\.json|session-slice\.jsonl)"' "$WURZEL"/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
janein "pre-compact.sh schreibt ohnehin je Sitzung (RESCUE_DIR/<ts>_<sid>), kein fester Pfad" 0 "$(grep -c '"/tmp/[a-z_]*\.json"' "$WURZEL/hooks/pre-compact.sh")"

rm -rf "$T"
echo
echo "=============================================================================="
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
