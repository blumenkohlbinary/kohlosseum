#!/usr/bin/env bash
# test_unterordner_bestand.sh — v5.106.0 (Etappe 14 §1): im Rollen-Aufbau gehoeren die
# CLAUDE.md und Rules der Roster-Unterordner zum Bestand von mind-claudemd, mind-rules,
# mind-update und zum Snapshot.
#
# Anlass: Creator (Doro, 14.09.2026) — sieben Unterordner mit eigener CLAUDE.md und Rules,
# der Dauerkontext von sieben Arbeiter-Sitzungen; in keinem Bericht ein Unterordner (0/0/0).
#
# Aufruf:  CLAUDE_PLUGIN_ROOT=<paket> bash tests/test_unterordner_bestand.sh
set -u
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
# shellcheck disable=SC1090
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh" 2>/dev/null || { echo "lib.sh nicht ladbar" >&2; exit 2; }

OK=0; ROT=0
janein() { if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  [ok ] %s\n' "$1"
           else ROT=$((ROT+1)); printf '  [ROT] %s — erwartet %s, bekommen %s\n' "$1" "$2" "$3"; fi; }

# Fixture: Wurzel mit Roster (Spalte Ordner), zwei Roster-Unterordner (einer mit Leerzeichen),
# ein Unterordner mit CLAUDE.md, der NICHT im Roster steht.
W=$(mktemp -d)/wurzel; mkdir -p "$W/.claude/rules" "$W/Creator Idee/.claude/rules" "$W/Skript/.claude/rules" "$W/Fremd"
printf '# Wurzel\n' > "$W/CLAUDE.md"; printf '# r\n' > "$W/.claude/rules/eins.md"
cat > "$W/.claude/rules/rollen.md" <<'EOF'
# Rollen

| Rolle | Name | sessionId | Tut | Ordner |
|---|---|---|---|---|
| **manager** | **B** | `x` | liest | `./` |
| **arbeiter** | **F** | noch offen | Idee | `Creator Idee/` |
| **arbeiter** | **G** | noch offen | Skript | `Skript/` |
| **arbeiter** | **L** | noch offen | Schnitt | `Schnitt/` |

## Wem was gehoert

| Bereich | Eigentuemer |
|---|---|
| `CLAUDE.md` | **B** |
EOF
printf '# Idee\n' > "$W/Creator Idee/CLAUDE.md"; printf '# i1\n' > "$W/Creator Idee/.claude/rules/i1.md"; printf '# i2\n' > "$W/Creator Idee/.claude/rules/i2.md"
printf '# Skript\n' > "$W/Skript/CLAUDE.md"; printf '# s1\n' > "$W/Skript/.claude/rules/s1.md"
printf '# Fremd\n' > "$W/Fremd/CLAUDE.md"

echo "== 1  mind_rollen_ordner: die Spalte Ordner des Rosters =="
O=$(mind_rollen_ordner "$W")
janein "zwei vorhandene Roster-Ordner (Schnitt/ existiert nicht, ./ ist die Wurzel)" 2 "$(printf '%s\n' "$O" | grep -c .)"
janein "   Ordner mit Leerzeichen dabei" ja "$(printf '%s\n' "$O" | grep -q '/Creator Idee$' && echo ja || echo nein)"
janein "   Fremd/ (CLAUDE.md, aber nicht im Roster) NICHT dabei" nein "$(printf '%s\n' "$O" | grep -q '/Fremd$' && echo ja || echo nein)"
janein "   ohne rollen.md: rc 1" 1 "$(mind_rollen_ordner "$W/Fremd" >/dev/null 2>&1; echo $?)"

echo "== 2  ohne Spalte Ordner: jeder direkte Unterordner mit CLAUDE.md =="
W2=$(mktemp -d)/w2; mkdir -p "$W2/.claude/rules" "$W2/A" "$W2/B" "$W2/C"
printf '| Rolle | Name | sessionId | Tut |\n|---|---|---|---|\n| manager | X | y | z |\n' > "$W2/.claude/rules/rollen.md"
printf 'a\n' > "$W2/A/CLAUDE.md"; printf 'b\n' > "$W2/B/CLAUDE.md"
janein "A und B (C hat keine CLAUDE.md)" 2 "$(mind_rollen_ordner "$W2" | grep -c .)"

echo "== 3  mind_unterordner_kontext: CLAUDE.md und Rules der Roster-Ordner =="
K=$(mind_unterordner_kontext "$W")
janein "fuenf Dateien: 2 CLAUDE.md + 3 Rules" 5 "$(printf '%s\n' "$K" | grep -c .)"
janein "   Fremd/CLAUDE.md nicht dabei" nein "$(printf '%s\n' "$K" | grep -q 'Fremd' && echo ja || echo nein)"
janein "   ohne Rollen-Aufbau: leer" 0 "$(mind_unterordner_kontext "$W/Fremd" 2>/dev/null | grep -c .)"

echo "== 4  mind_snapshot sichert sie mit =="
S=$(cd "$W" && mind_snapshot "$W" "pre-files" 2>/dev/null)
janein "Snapshot angelegt" ja "$([ -n "$S" ] && [ -d "$S" ] && echo ja || echo nein)"
janein "   Creator Idee/CLAUDE.md unter project/" ja "$([ -f "$S/project/Creator Idee/CLAUDE.md" ] && echo ja || echo nein)"
janein "   Skript/.claude/rules/s1.md unter project/" ja "$([ -f "$S/project/Skript/.claude/rules/s1.md" ] && echo ja || echo nein)"
janein "   Fremd/CLAUDE.md NICHT gesichert (nicht im Roster)" nein "$([ -f "$S/project/Fremd/CLAUDE.md" ] && echo ja || echo nein)"

echo "== 5  Text-Gate: die drei Skills kennen den Unterordner-Bestand =="
for s in mind-claudemd mind-rules mind-update; do
  janein "$s nennt mind_unterordner_kontext" ja "$(grep -q 'mind_unterordner_kontext' "$CLAUDE_PLUGIN_ROOT/skills/$s/SKILL.md" && echo ja || echo nein)"
done
janein "mind-update: Roster-Rules im PROJECT_RULES" ja "$(grep -q 'PROJECT_RULES=$(ls .claude/rules/\*.md 2>/dev/null; mind_unterordner_kontext' "$CLAUDE_PLUGIN_ROOT/skills/mind-update/SKILL.md" && echo ja || echo nein)"

rm -rf "$(dirname "$W")" "$(dirname "$W2")"
echo
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
