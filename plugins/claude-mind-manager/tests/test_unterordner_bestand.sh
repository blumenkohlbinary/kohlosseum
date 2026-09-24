#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
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

echo "== 6  v5.109.0: jedes fork hat eigenes Memory — mind_memory_dirs / memory_pfade =="
# HOME und USERPROFILE auf ein Wegwerf-Heim: Slugs wie Claude Code (cygpath -w, alles Nicht-
# Alphanumerische -> '-'). Drei Memory-Verzeichnisse: Wurzel, Creator Idee, Skript (leer).
H2=$(mktemp -d); export HOME="$H2" USERPROFILE="$(cygpath -w "$H2" 2>/dev/null || printf '%s' "$H2")"
# ⛔ v5.133.0 (Etappe 44 §2): die FUNKTION statt einer Kopie der Regel (sed ersetzt byteweise)
sl() { hash_project_dir "$1"; }
for o in "$W" "$W/Creator Idee" "$W/Skript"; do mkdir -p "$H2/.claude/projects/$(sl "$o")/memory"; done
printf -- '---\nname: w\ndescription: Wurzelwissen fuer alle, ausreichend lang beschrieben hier\n---\nW.\n' > "$H2/.claude/projects/$(sl "$W")/memory/wurzel.md"
printf '# Index\n' > "$H2/.claude/projects/$(sl "$W")/memory/MEMORY.md"
printf -- '---\nname: i\ndescription: Ideenwissen der Idee-Sitzung, ausreichend lang beschrieben\n---\nI.\n' > "$H2/.claude/projects/$(sl "$W/Creator Idee")/memory/idee.md"
MD=$(mind_memory_dirs "$W")
janein "zwei Verzeichnisse mit Inhalt (Skript ist leer und zaehlt nicht)" 2 "$(printf '%s\n' "$MD" | grep -c .)"
janein "   das Wurzel-Memory zuerst" ja "$(printf '%s\n' "$MD" | head -1 | grep -q "$(sl "$W")/memory" && echo ja || echo nein)"
janein "   das Memory von Creator Idee dabei" ja "$(printf '%s\n' "$MD" | grep -q "$(sl "$W/Creator Idee")/memory" && echo ja || echo nein)"
janein "   ohne Rollen-Aufbau: hoechstens eines" ja "$([ "$(mind_memory_dirs "$W/Fremd" | grep -c .)" -le 1 ] && echo ja || echo nein)"
PYQ="$CLAUDE_PLUGIN_ROOT/references"
janein "Python memory_pfade: dieselben zwei" 2 "$(python -c "import sys; sys.path.insert(0, r'$(cygpath -w "$PYQ" 2>/dev/null || printf '%s' "$PYQ")'); from learnings_quellen import memory_pfade; print(len(memory_pfade(r'$(cygpath -w "$W" 2>/dev/null || printf '%s' "$W")')))" 2>/dev/null)"
janein "Python rollen_ordner: zwei Roster-Ordner, Fremd nicht" 2 "$(python -c "import sys; sys.path.insert(0, r'$(cygpath -w "$PYQ" 2>/dev/null || printf '%s' "$PYQ")'); from learnings_quellen import rollen_ordner; o=rollen_ordner(r'$(cygpath -w "$W" 2>/dev/null || printf '%s' "$W")'); print(len(o) if not any('Fremd' in x for x in o) else 'Fremd')" 2>/dev/null)"
# Snapshot sichert die Unterordner-Memorys unter memory-unterordner/<ordner>/
S2=$(cd "$W" && mind_snapshot "$W" "pre-memory" 2>/dev/null)
janein "Snapshot: Wurzel-Memory unter memory/" ja "$([ -f "$S2/memory/wurzel.md" ] && echo ja || echo nein)"
janein "   Idee-Memory unter memory-unterordner/Creator Idee/ (nicht unter memory/)" ja "$([ -f "$S2/memory-unterordner/Creator Idee/idee.md" ] && [ ! -f "$S2/memory/idee.md" ] && echo ja || echo nein)"
janein "   MANIFEST nennt den Rueckweg" ja "$(grep -q 'memory-unterordner/Creator Idee <- ' "$S2/MANIFEST" 2>/dev/null && echo ja || echo nein)"
# cleaner_audit: beide Verzeichnisse im Bestand, Anzeige memory[<ordner>]/
A=$(python -c "import sys; sys.path.insert(0, r'$(cygpath -w "$PYQ" 2>/dev/null || printf '%s' "$PYQ")'); import cleaner_audit as ca; ds=ca.dateien(r'$(cygpath -w "$W" 2>/dev/null || printf '%s' "$W")', 'memory'); print('|'.join(ca._nm(x) for x in ds))" 2>/dev/null)
janein "cleaner_audit --nur memory: wurzel.md als memory/, idee.md als memory[…]/, kein MEMORY.md" ja "$(printf '%s' "$A" | grep -q 'memory/wurzel.md' && printf '%s' "$A" | grep -q 'memory\[.*\]/idee.md' && ! printf '%s' "$A" | grep -q 'MEMORY.md' && echo ja || echo "nein ($A)")"
rm -rf "$H2"

echo "== 5  Text-Gate: die drei Skills kennen den Unterordner-Bestand =="
for s in mind-claudemd mind-rules mind-update; do
  janein "$s nennt mind_unterordner_kontext" ja "$(grep -q 'mind_unterordner_kontext' "$CLAUDE_PLUGIN_ROOT/skills/$s/SKILL.md" && echo ja || echo nein)"
done
janein "mind-update: Roster-Rules im PROJECT_RULES" ja "$(grep -q 'PROJECT_RULES=$(ls .claude/rules/\*.md 2>/dev/null; mind_unterordner_kontext' "$CLAUDE_PLUGIN_ROOT/skills/mind-update/SKILL.md" && echo ja || echo nein)"
janein "mind-memory: MEMORY_DIRS aus mind_memory_dirs, nie ueber Slugs mergen" ja "$(grep -q 'MEMORY_DIRS=$(mind_memory_dirs' "$CLAUDE_PLUGIN_ROOT/skills/mind-memory/SKILL.md" && grep -q 'NIE ueber Slugs hinweg' "$CLAUDE_PLUGIN_ROOT/skills/mind-memory/SKILL.md" && echo ja || echo nein)"
janein "mind-update: memory-Agent bekommt alle Verzeichnisse" ja "$(grep -q 'ALLE Verzeichnisse aus `mind_memory_dirs' "$CLAUDE_PLUGIN_ROOT/skills/mind-update/SKILL.md" && echo ja || echo nein)"
janein "mind-cleaner: memory im Rollen-Aufbau = alle Slugs" ja "$(grep -q 'ALLE Slugs: Wurzel + je Roster-Ordner' "$CLAUDE_PLUGIN_ROOT/skills/mind-cleaner/SKILL.md" && echo ja || echo nein)"

rm -rf "$(dirname "$W")" "$(dirname "$W2")"
echo
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
