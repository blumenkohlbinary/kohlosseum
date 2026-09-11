#!/usr/bin/env bash
# =============================================================================
#  UNTERORDNER-AUFBAU — das Projekt ist der Ordner mit dem Roster  (NEU v5.80.0)
# =============================================================================
#
# ⛔ WOZU. Nutzer-Frage 11.09.2026 (Creator: 9 Chats in 9 Unterordnern): "alle 9
#    chats wenn ich da compact mache dann auch beim mind sync chat landen".
#    Gemessen: CLAUDE_PROJECT_DIR im Unterordner IST der Unterordner — Rettung,
#    OPEN, Lock, Herzschlag lagen in neun getrennten .claude-mind/.
#
# ⭐ Die Prueffaelle aus dem Auftrag (nils-unterordner-aufbau.md §7):
#      1  Kompaktierung im Unterordner -> OPEN liegt in der WURZEL, mit sid=
#      2  Rollen-Gate aus dem Unterordner findet den Roster -> sync still, andere laut
#      4  ⛔ OHNE Roster: alles wie heute — byteweise gegen die alte Zeile
#      5  Bilanz: hier nur der Wurzel-Teil (der Rest kommt mit v5.82.0)
#    Prueffall 3 (/mind-all sieht beide Rettungen) braucht cwd= -> v5.81.0.
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

T=$(mktemp -d "${TMPDIR:-/tmp}/uoXXXXXX") || exit 2
R="$T/Creator"; A="$R/Creator Idee"; B="$R/Creator Mind Sync"
mkdir -p "$R/.claude/rules" "$A" "$B"
MGR="11111111-aaaa-4aaa-8aaa-111111111111"
ARB="22222222-bbbb-4bbb-8bbb-222222222222"
SYN="33333333-cccc-4ccc-8ccc-333333333333"
{
  echo '# Rollen'; echo
  echo '| Rolle | Name | sessionId | Tut |'; echo '|---|---|---|---|'
  echo "| **manager** | **Anton** | \`$MGR\` | liest |"
  echo "| **arbeiter** | **Nils** | \`$ARB\` | baut |"
  echo "| **sync** | **Rita** | \`$SYN\` | faehrt |"
} > "$R/.claude/rules/rollen.md"

echo "=============================================================================="
echo "  1) mind_projekt_wurzel — der Begriff"
echo "=============================================================================="
janein "Unterordner -> Wurzel mit Roster" "$R" "$(mind_projekt_wurzel "$A")"
janein "zweiter Unterordner -> dieselbe Wurzel" "$R" "$(mind_projekt_wurzel "$B")"
janein "die Wurzel selbst -> sie selbst" "$R" "$(mind_projekt_wurzel "$R")"
janein "mit Schraegstrich am Ende -> ohne" "$R" "$(mind_projekt_wurzel "$A/")"
WIN=$(printf '%s' "$A" | sed 's#/#\\#g')
janein "⚠ Windows-Form (Backslashes) -> Wurzel mit Schraegstrichen" "$R" "$(mind_projekt_wurzel "$WIN")"
janein "Vorgabe aus CLAUDE_PROJECT_DIR" "$R" "$(CLAUDE_PROJECT_DIR="$A" mind_projekt_wurzel)"
janein "leerer Start -> pwd (einen leeren Start gibt es nicht)" "$(cd "$T" && pwd)" "$(cd "$T" && CLAUDE_PROJECT_DIR="" mind_projekt_wurzel "")"
# $HOME zaehlt nie
FH="$T/home"; mkdir -p "$FH/.claude/rules" "$FH/proj/sub"; : > "$FH/.claude/rules/rollen.md"
janein "⛔ ~/.claude/rules/rollen.md macht HOME NICHT zum Projekt" "$FH/proj/sub" "$(HOME="$FH" mind_projekt_wurzel "$FH/proj/sub")"

echo
echo "=============================================================================="
echo "  4) ⛔ OHNE Roster: byteweise wie heute — gegen die ALTE Zeile gefahren"
echo "=============================================================================="
N="$T/kein roster/unter"; mkdir -p "$N"
for start in "$N" "$N/" "$(printf '%s' "$N" | sed 's#/#\\#g')" "relativ/pfad" "C:/nix/da"; do
  alt="${start:-$(pwd)}"                          # die Zeile von v5.79.0
  neu=$(mind_projekt_wurzel "$start")
  janein "unveraendert: '$(printf '%s' "$start" | cut -c1-30)'" "$alt" "$neu"
done

echo
echo "=============================================================================="
echo "  1b) Kompaktierung im Unterordner -> Rettung und OPEN in der WURZEL"
echo "=============================================================================="
P="$A/t.jsonl"; : > "$P"
for i in $(seq 1 30); do
  printf '{"type":"user","message":{"content":[{"type":"text","text":"Frage %d"}]}}\n' "$i" >> "$P"
  printf '{"type":"assistant","message":{"content":[{"type":"text","text":"Antwort %d. Entscheidung: Weg A."}],"usage":{"input_tokens":2,"cache_read_input_tokens":1000,"cache_creation_input_tokens":3,"output_tokens":9}}}\n' "$i" >> "$P"
done
export CLAUDE_PROJECT_DIR="$A"
printf '{"hook_event_name":"PreCompact","cwd":"%s","session_id":"%s","transcript_path":"%s","trigger":"auto"}' \
  "$A" "$ARB" "$P" | bash "$H/pre-compact.sh" >/dev/null 2>&1
janein "OPEN liegt in der Wurzel" "1" "$(ls "$R/.claude-mind/rescued/OPEN" 2>/dev/null | wc -l | tr -d ' ')"
janein "Rettung liegt in der Wurzel" "1" "$(ls "$R"/.claude-mind/rescued/*_chat.md 2>/dev/null | wc -l | tr -d ' ')"
janein "⛔ im Unterordner liegt KEINE Rettung" "0" "$(ls "$A"/.claude-mind/rescued/*_chat.md 2>/dev/null | wc -l | tr -d ' ')"
janein "OPEN traegt sid= der Untersitzung" "ja" "$(grep -q "sid=$ARB" "$R/.claude-mind/rescued/OPEN" 2>/dev/null && echo ja || echo nein)"
janein "Herzschlag in der Wurzel" "ja" "$([ -f "$R/.claude-mind/hook-heartbeat" ] && echo ja || echo nein)"

echo
echo "=============================================================================="
echo "  2) Rollen-Gate aus dem Unterordner: die sync-Sitzung wird still, andere laut"
echo "=============================================================================="
# prompt-submit.sh aus dem Unterordner, einmal als arbeiter, einmal als sync
ruf_ps() {  # $1 = sid
  printf '{"hook_event_name":"UserPromptSubmit","cwd":"%s","session_id":"%s","prompt":"hallo"}' "$A" "$1" \
    | CLAUDE_PROJECT_DIR="$A" bash "$H/prompt-submit.sh" 2>/dev/null
}
AUS_ARB=$(ruf_ps "$ARB"); AUS_SYN=$(ruf_ps "$SYN")
janein "sync-Sitzung (Rita) sieht die Schuld-Mahnung" "ja" "$(printf '%s' "$AUS_SYN" | grep -qi 'OPEN\|Schuld\|mind-all' && echo ja || echo nein)"
janein "arbeiter (Nils) im Unterordner: Rollen-Gate greift, keine Schuld-Mahnung" "nein" "$(printf '%s' "$AUS_ARB" | grep -qi 'Schuld' && echo ja || echo nein)"
janein "Rollen-Gate direkt: Nils aus dem Unterordner -> still (rc 0)" "0" "$(bash "$H/rollen-gate.sh" "$ARB" "$(mind_projekt_wurzel "$A")" >/dev/null 2>&1; echo $?)"
janein "Rollen-Gate direkt: Rita -> laut (rc 1)" "1" "$(bash "$H/rollen-gate.sh" "$SYN" "$(mind_projekt_wurzel "$A")" >/dev/null 2>&1; echo $?)"

echo
echo "=============================================================================="
echo "  5) Bilanz aus dem Unterordner zaehlt die WURZEL (der eigene Teil: v5.82.0)"
echo "=============================================================================="
printf '# Wurzel\n\nEine Regel.\n' > "$R/CLAUDE.md"
LH="$T/leeres-home"; mkdir -p "$LH"     # ohne globale Dateien zaehlt nur die Wurzel
janein "mind_kontext_bilanz auf der Wurzel zaehlt CLAUDE.md + rollen.md = 2" "ja" \
  "$(HOME="$LH" mind_kontext_bilanz "$(mind_projekt_wurzel "$A")" 2>/dev/null | grep -q 'DATEIEN=2 ' && echo ja || echo nein)"
printf '# U\n' > "$A/CLAUDE.md"
janein "⚠ die eigenen Unterordner-Dateien zaehlt sie noch NICHT (v5.82.0)" "ja" \
  "$(HOME="$LH" mind_kontext_bilanz "$(mind_projekt_wurzel "$A")" 2>/dev/null | grep -q 'DATEIEN=2 ' && echo ja || echo nein)"

echo
echo "=============================================================================="
echo "  6) Eingebaut: alle Hooks und alle zehn Skills beziehen PROJ daraus"
echo "=============================================================================="
for h in prompt-submit session-start stop plan-modus pre-compact; do
  janein "hooks/$h.sh ruft mind_projekt_wurzel" "ja" "$(grep -q 'mind_projekt_wurzel' "$H/$h.sh" && echo ja || echo nein)"
done
janein "alle 10 SKILL.md setzen PROJ=\$(mind_projekt_wurzel)" "10" \
  "$(grep -l 'PROJ=$(mind_projekt_wurzel)' "$WURZEL"/skills/*/SKILL.md | wc -l | tr -d ' ')"
janein "⛔ kein Skill setzt PROJ mehr aus CLAUDE_PROJECT_DIR allein (nur als Rueckfall)" "0" \
  "$(grep -c '^PROJ="${CLAUDE_PROJECT_DIR' "$WURZEL"/skills/*/SKILL.md | grep -vc ':0$')"
janein "⛔ kein inline CLAUDE_PROJECT_DIR:-\$(pwd) mehr in den Skills" "0" \
  "$(grep -h 'CLAUDE_PROJECT_DIR:-$(pwd)}' "$WURZEL"/skills/*/SKILL.md | grep -vc 'mind_projekt_wurzel')"
janein "mind-files installiert nach \$PROJ, nicht nach \$CLAUDE_PROJECT_DIR" "0" \
  "$(grep -c '$CLAUDE_PROJECT_DIR/tools' "$WURZEL/skills/mind-files/SKILL.md")"

rm -rf "$T"
echo
echo "=============================================================================="
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
