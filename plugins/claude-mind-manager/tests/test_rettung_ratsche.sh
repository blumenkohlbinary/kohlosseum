#!/usr/bin/env bash
# =============================================================================
#  DIE ROTATIONS-RATSCHE — ungelesene Rettungen rotieren nicht  (NEU v5.86.0)
# =============================================================================
#
# ⛔ WOZU. Gemessen 11.09.2026 (docs/plugin/rettungen-messung.md): 17 Rettungen
#    in 6 Projekten, 7 ungeschuetzt UND nie eingespeist (3,9 MB), fuenf von sechs
#    Projekten auf genau KEEP=3. Liegt sync-stand, entsteht kein OPEN, und KEEP
#    raeumt die einzige Kopie des Gespraechs nach dem Sync ungelesen weg.
#
# ⭐ Antons vier Prueffaelle (Auftraege/nils-etappe-3.md, Entscheidung zu Punkt 1):
#      1  4 Rettungen, Merker zwischen 2 und 3 -> nur 1 und 2 rotieren
#      2  nie ein Sync (neues Projekt) -> nichts rotiert UND die Meldung feuert
#      3  Merker fehlt (Altbestand) -> Verhalten wie heute, byteweise
#      4  KEEP bleibt 3 — die Meldung ersetzt keine Grenze, sie macht sie sichtbar
#    Dazu: der Merker wird von NIEMANDEM verbraucht (pre-compact laesst ihn liegen).
# =============================================================================
set -u
WURZEL="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
H="$WURZEL/hooks"
export CLAUDE_PLUGIN_ROOT="$WURZEL"
[ -f "$H/lib.sh" ] || { echo "ABBRUCH: lib.sh fehlt"; exit 2; }
# shellcheck disable=SC1090
. "$H/lib.sh" >/dev/null 2>&1

OK=0; ROT=0
janein() {
  if [ "$2" = "$3" ]; then
    printf '    OK   %-60s ist=%s\n' "$1" "$3"; OK=$((OK + 1))
  else
    printf '    FEHL %-60s ist=%-14s soll=%s\n' "$1" "$3" "$2"; ROT=$((ROT + 1))
  fi
}

T=$(mktemp -d "${TMPDIR:-/tmp}/rrXXXXXX") || exit 2
transkript() {  # $1 = Datei
  : > "$1"
  for i in 1 2 3 4 5 6 7 8; do
    printf '{"type":"user","message":{"content":[{"type":"text","text":"Frage %d"}]}}\n' "$i" >> "$1"
    printf '{"type":"assistant","message":{"content":[{"type":"text","text":"Antwort %d. Entscheidung: Weg A."}],"usage":{"input_tokens":2,"cache_read_input_tokens":1000,"cache_creation_input_tokens":3,"output_tokens":9}}}\n' "$i" >> "$1"
  done
}
kompaktiere() {  # $1 = Projekt, $2 = sid — ein PreCompact mit KEEP=1
  printf '{"hook_event_name":"PreCompact","cwd":"%s","session_id":"%s","transcript_path":"%s","trigger":"auto"}' \
    "$1" "$2" "$1/t.jsonl" | MIND_RESCUE_KEEP_COUNT=1 CLAUDE_PROJECT_DIR="$1" bash "$H/pre-compact.sh" >/dev/null 2>&1
}
rettung() {  # $1 = Projekt, $2 = ts (JJJJMMTT-HHMMSS): eine alte Rettung hinlegen
  printf '# Geretteter Chat\n\n- Quelle: x\n\n## [1] USER\nalt\n' > "$1/.claude-mind/rescued/${2}_chat.md"
}
zaehle() { ls "$1"/.claude-mind/rescued/*_chat.md 2>/dev/null | wc -l | tr -d ' '; }

echo "=============================================================================="
echo "  1) 4 Rettungen, Merker zwischen 2 und 3 -> nur 1 und 2 rotieren (KEEP=1)"
echo "=============================================================================="
P="$T/eins"; mkdir -p "$P/.claude-mind/rescued"; transkript "$P/t.jsonl"
rettung "$P" 20260901-100000; rettung "$P" 20260902-100000
rettung "$P" 20260903-100000; rettung "$P" 20260904-100000
printf 'ts=20260902-120000\n' > "$P/.claude-mind/rescued/letzter-sync"
# sync-stand liegt -> kein OPEN, also kein OPEN-Schutz: nur die Ratsche traegt
printf 'ts=2026-09-02 12:00:00\numfang=5/5 skills 4/4 agents\nungepruef=\n' > "$P/.claude-mind/rescued/sync-stand"
janein "ungelesen VOR der Kompaktierung: 3 und 4" "2" "$(mind_rettungen_ungelesen "$P" | grep -c .)"
kompaktiere "$P" "S1"
janein "nach der Kompaktierung liegen 3 Rettungen (3, 4, neu)" "3" "$(zaehle "$P")"
janein "   Rettung 1 ist weg" "nein" "$([ -f "$P/.claude-mind/rescued/20260901-100000_chat.md" ] && echo ja || echo nein)"
janein "   Rettung 2 ist weg" "nein" "$([ -f "$P/.claude-mind/rescued/20260902-100000_chat.md" ] && echo ja || echo nein)"
janein "   ⭐ Rettung 3 (juenger als der Sync) ist DA" "ja" "$([ -f "$P/.claude-mind/rescued/20260903-100000_chat.md" ] && echo ja || echo nein)"
janein "   ⭐ Rettung 4 ist DA" "ja" "$([ -f "$P/.claude-mind/rescued/20260904-100000_chat.md" ] && echo ja || echo nein)"
janein "   kein OPEN entstanden (sync-stand lag) — der Schutz kam allein von der Ratsche" "nein" "$([ -f "$P/.claude-mind/rescued/OPEN" ] && echo ja || echo nein)"
janein "⛔ der Merker wird von pre-compact NICHT verbraucht" "20260902-120000" "$(mind_letzter_sync "$P")"

echo
echo "=============================================================================="
echo "  3) Merker FEHLT (Altbestand) -> Verhalten wie heute: KEEP=1 laesst nur die neue"
echo "=============================================================================="
P3="$T/drei"; mkdir -p "$P3/.claude-mind/rescued"; transkript "$P3/t.jsonl"
rettung "$P3" 20260901-100000; rettung "$P3" 20260902-100000
rettung "$P3" 20260903-100000; rettung "$P3" 20260904-100000
printf 'ts=2026-09-02 12:00:00\numfang=5/5 skills 4/4 agents\nungepruef=\n' > "$P3/.claude-mind/rescued/sync-stand"
kompaktiere "$P3" "S3"
janein "ohne Merker: nur die neue Rettung bleibt (wie v5.85.0)" "1" "$(zaehle "$P3")"
janein "   und es entsteht auch kein Merker (rescued/ gab es schon)" "nein" "$([ -f "$P3/.claude-mind/rescued/letzter-sync" ] && echo ja || echo nein)"
janein "   mind_rettungen_ungelesen ohne Merker: Rueckgabe 1, keine Ausgabe" "1|" "$(u=$(mind_rettungen_ungelesen "$P3"); echo "$?|$u")"

echo
echo "=============================================================================="
echo "  2) NIE ein Sync (neues Projekt) -> nichts rotiert UND die Meldung feuert"
echo "=============================================================================="
P2="$T/zwei"; mkdir -p "$P2"; transkript "$P2/t.jsonl"
kompaktiere "$P2" "S2"          # rescued/ entsteht hier zum ersten Mal
janein "neues Projekt bekommt den Merker ts=0" "0" "$(mind_letzter_sync "$P2")"
# OPEN raeumen, wie es ein Teilsync/.stale taete — der Schutz muss von der Ratsche kommen
rm -f "$P2/.claude-mind/rescued/OPEN"
sleep 1; kompaktiere "$P2" "S2"; rm -f "$P2/.claude-mind/rescued/OPEN"
sleep 1; kompaktiere "$P2" "S2"; rm -f "$P2/.claude-mind/rescued/OPEN"
janein "drei Kompaktierungen bei KEEP=1 -> alle drei Rettungen liegen noch" "3" "$(zaehle "$P2")"
janein "alle drei gelten als ungelesen" "3" "$(mind_rettungen_ungelesen "$P2" | grep -c .)"
# der Backstop in prompt-submit: > KEEP (hier 1) -> Meldung. Als FREMDE Sitzung S9: wer
# selbst kompaktiert hat, bekommt bei der ersten Nachricht die UEBERGABE, nicht die Meldung.
AUS=$(printf '{"hook_event_name":"UserPromptSubmit","cwd":"%s","session_id":"S9","prompt":"hallo"}' "$P2" \
  | MIND_RESCUE_KEEP_COUNT=1 CLAUDE_PROJECT_DIR="$P2" bash "$H/prompt-submit.sh" 2>/dev/null)
janein "⭐ prompt-submit meldet '3 Rettungen ungelesen'" "ja" "$(printf '%s' "$AUS" | grep -q '3 Rettungen ungelesen' && echo ja || echo nein)"
janein "   ... nennt 'Sync faellig'" "ja" "$(printf '%s' "$AUS" | grep -q 'Sync faellig' && echo ja || echo nein)"
AUS2=$(printf '{"hook_event_name":"UserPromptSubmit","cwd":"%s","session_id":"S9","prompt":"hallo"}' "$P2" \
  | MIND_RESCUE_KEEP_COUNT=1 CLAUDE_PROJECT_DIR="$P2" bash "$H/prompt-submit.sh" 2>/dev/null)
janein "   zweite Nachricht, gleicher Stand: still" "nein" "$(printf '%s' "$AUS2" | grep -q 'ungelesen' && echo ja || echo nein)"
janein "   ⛔ nichts geloescht — die Meldung ist keine Grenze" "3" "$(zaehle "$P2")"
# ein VOLLER Sync schreibt den Merker (Step 2.96a) — danach ist nichts mehr ungelesen
printf 'ts=%s\n' "$(date +%Y%m%d-%H%M%S)" > "$P2/.claude-mind/rescued/letzter-sync"
sleep 1
janein "nach einem vollen Sync: 0 ungelesen" "0" "$(mind_rettungen_ungelesen "$P2" | grep -c .)"

echo
echo "=============================================================================="
echo "  4) KEEP bleibt 3 — Vorgabe unveraendert; Schwellen des Backstops"
echo "=============================================================================="
janein "pre-compact: RESCUE_KEEP Vorgabe 3" "ja" "$(grep -q 'RESCUE_KEEP="\${MIND_RESCUE_KEEP_COUNT:-3}"' "$H/pre-compact.sh" && echo ja || echo nein)"
janein "prompt-submit: Backstop ab KEEP oder 5 MB, und er loescht nicht" "ja" \
  "$(grep -q '_UB" -gt 5000000' "$H/prompt-submit.sh" && ! grep -A40 'BACKSTOP der Rotations-Ratsche' "$H/prompt-submit.sh" | grep -q 'rm -f "\$_f"' && echo ja || echo nein)"
janein "mind-all Step 2.96a schreibt letzter-sync nur bei SYNC_LIEF=ja" "ja" \
  "$(grep -q '\[ "\$SYNC_LIEF" = "ja" \] && printf .ts=%s' "$WURZEL/skills/mind-all/SKILL.md" && echo ja || echo nein)"

rm -rf "$T"
echo
echo "=============================================================================="
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
