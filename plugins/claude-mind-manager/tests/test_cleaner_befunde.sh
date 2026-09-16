#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
# Etappe 23 (v5.115.0) — acht Cleaner-Befunde aus Veras erstem 5.113.1-Lauf (Zustellplan, 16.09.2026)
#   §1 Sonde --auswerten ohne Merker (--seit / --datei, alle paths-Rules)
#   §2 Audit 5a: Memory „nicht messbar (kein Git)" mit Beleg aus Datei-Zeiten
#   §3 Memory-Dateien sind nie HOOK-KANDIDAT (Zitierung ist kein Aufruf-Anker)
#   §4 RULE-PATHS bei schon gesetztem paths: -> BLEIBT (paths gesetzt), nur Sonde
#   §5 Plan: ZEIGER je Dateipaar EINE Zeile + Anlage; --anwenden wie bisher
#   §6 „laedt beim Start" gegen „laedt bei Beruehrung" (paths:) — Bilanz und Bestandsaufnahme
#   §7 cleaner_belege: Projektgrenze und ganzes Wort (Zustellplans rollen.md: 4 fremde Treffer)
#   §8 DOCS-Zug aus dem Memory: Indexzeile auf docs/, kein Stub, Topic weg
# Jeder Fall gegen 5.114.0 rot (Gegenprobe in der NACH).
set -u
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
REF="$CLAUDE_PLUGIN_ROOT/references"
unset MIND_DEBUG_DIR   # nie in den echten Debug-Ordner schreiben
OK=0; ROT=0
janein() { if [ "$2" = "$3" ]; then OK=$((OK+1)); printf '  [ok ] %s\n' "$1"
           else ROT=$((ROT+1)); printf '  [ROT] %s — erwartet %s, bekommen %s\n' "$1" "$2" "$3"; fi; }
PY=python; command -v python >/dev/null 2>&1 || PY=python3
w() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
m() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

echo "== §1  Sonde --auswerten ohne Merker =="
P=$(mktemp -d); mkdir -p "$P/.claude/rules" "$P/.claude-mind"
printf -- '---\npaths: ["a.py"]\n---\n# A\n\n⛔ NIE `a.py` ohne Test.\n' > "$P/.claude/rules/a.md"
printf -- '---\npaths: ["b.py"]\n---\n# B\n\n⛔ NIE `b.py` ohne Test.\n' > "$P/.claude/rules/b.md"
printf -- '---\nglobs: ["c.py"]\n---\n# C\n\nLaedt beim Start.\n' > "$P/.claude/rules/c.md"
LOG="$P/lade.log"; PM=$(m "$P")
printf '2026-09-16 10:00:00\tsession_start\t%s/.claude/rules/c.md\tsid1\n2026-09-16 10:05:00\tpath_glob_match\t%s/.claude/rules/a.md\tsid1\n' "$PM" "$PM" > "$LOG"
A=$($PY "$(w "$REF/cleaner_paths_sonde.py")" --auswerten "$(w "$P")" --seit "2026-09-16 09:00:00" --log "$(w "$LOG")" 2>&1); RC=$?
janein "ohne Merker, --seit: rc 0 (paths filtert)" 0 "$RC"
janein "   ... beide paths-Rules gemessen, globs-Rule nicht" ja "$(printf '%s\n' "$A" | grep -q 'a.md' && printf '%s\n' "$A" | grep -q 'b.md' && ! printf '%s\n' "$A" | grep -q '^  c.md' && echo ja || echo nein)"
janein "   ... a.md: Grund path_glob_match, b.md: nicht geladen" ja "$(printf '%s\n' "$A" | grep 'a.md' | grep -q 'path_glob_match' && printf '%s\n' "$A" | grep 'b.md' | grep -q 'FILTERT' && echo ja || echo nein)"
janein "   ... Bestands-Urteil nennt 2 von 2 und das Nachladen" ja "$(printf '%s\n' "$A" | grep -q 'URTEIL: paths: FILTERT .2 von 2 Rules nicht beim Start, 1 bei Dateiberuehrung nachgeladen.' && echo ja || echo nein)"
janein "   ... Satz fuer kontext-anlegen.md nennt Rules und Nachladen" ja "$(printf '%s\n' "$A" | grep -q 'Satz fuer kontext-anlegen.md: `paths:` filtert — gemessen .*, 2 Rules, Nachladen bei Dateiberuehrung .1.' && echo ja || echo nein)"
printf '2026-09-16 10:06:00\tsession_start\t%s/.claude/rules/b.md\tsid1\n' "$PM" >> "$LOG"
janein "b.md laedt mit session_start -> rc 1 (filtert NICHT)" 1 "$($PY "$(w "$REF/cleaner_paths_sonde.py")" --auswerten "$(w "$P")" --seit "2026-09-16 09:00:00" --log "$(w "$LOG")" >/dev/null 2>&1; echo $?)"
janein "--datei a.md: nur diese Rule, rc 0" 0 "$($PY "$(w "$REF/cleaner_paths_sonde.py")" --auswerten "$(w "$P")" --datei a.md --log "$(w "$LOG")" >/dev/null 2>&1; echo $?)"
janein "   ... --seit nach allen Zeilen: NOCH NICHT MESSBAR rc 3" 3 "$($PY "$(w "$REF/cleaner_paths_sonde.py")" --auswerten "$(w "$P")" --seit "2026-09-17 00:00:00" --log "$(w "$LOG")" >/dev/null 2>&1; echo $?)"
rm -f "$P/.claude/rules/a.md" "$P/.claude/rules/b.md"
janein "ohne Merker und ohne paths-Rule: rc 2 mit Hinweis" 2 "$($PY "$(w "$REF/cleaner_paths_sonde.py")" --auswerten "$(w "$P")" --log "$(w "$LOG")" >/dev/null 2>&1; echo $?)"
rm -rf "$P"

echo "== §7  cleaner_belege: Projektgrenze und ganzes Wort =="
P=$(mktemp -d); mkdir -p "$P/Zustellplan/.claude/rules" "$P/Debug"
printf -- '---\ndescription: r\n---\n# Rollen\n\n⛔ NIE ohne den manager handeln.\n' > "$P/Zustellplan/.claude/rules/rollen.md"
PZ=$(m "$P/Zustellplan")
{ printf '{"ts": "2026-09-15 10:00", "projekt": "%s", "klasse": "sonstiges", "kurz": "rollen vertauscht", "lauf": "x"}\n' "C:/CD/KOHLEKTIV/Plugin - Entwicklung/Claude Mind Manager"
  printf '{"ts": "2026-09-15 11:00", "projekt": "%s", "klasse": "sonstiges", "kurz": "rollen nicht gelesen", "lauf": "x"}\n' "C:/CD/KOHLEKTIV/APP - Palvedo"
  printf '{"ts": "2026-09-15 12:00", "projekt": "%s", "klasse": "sonstiges", "kurz": "Kontrollen fehlen", "lauf": "x"}\n' "C:/CD/KOHLEKTIV/APP - Palvedo"
  printf '{"ts": "2026-09-15 13:00", "projekt": "%s", "klasse": "sonstiges", "kurz": "rollen im Roster falsch", "lauf": "x"}\n' "$PZ"
} > "$P/Debug/index.jsonl"
cat > "$P/belege.py" <<'PYEOF'
import io, os, sys
sys.path.insert(0, os.environ["REF"])
import cleaner_belege as bel
p = os.path.join(os.environ["PZ"], ".claude", "rules", "rollen.md")
u, g, z = bel.urteile(p, os.path.join(os.environ["PD"], "index.jsonl"), os.environ["PZ"])
print("eigene=%s fremd=%s" % (z["verstoesse"], z.get("fremd")))
u2, g2, z2 = bel.urteile(p, os.path.join(os.environ["PD"], "index.jsonl"))
print("ohne_projekt=%s" % z2["verstoesse"])
PYEOF
B=$(REF="$(w "$REF")" PZ="$PZ" PD="$(m "$P/Debug")" $PY "$(w "$P/belege.py")" 2>&1)
janein "rollen.md im Zustellplan: 1 eigener Verstoss, 2 fremde (Kontrollen trifft NICHT)" ja "$(printf '%s\n' "$B" | grep -q 'eigene=1 fremd=2' && echo ja || echo nein)"
janein "   ... ohne Projektgrenze: 3 (ganzes Wort — nicht 4 wie bei 5.114.0)" ja "$(printf '%s\n' "$B" | grep -q 'ohne_projekt=3' && echo ja || echo nein)"
rm -rf "$P"

echo "== §2  Audit 5a: Memory nicht messbar (kein Git), Beleg aus Datei-Zeiten =="
P=$(mktemp -d); mkdir -p "$P/proj/.claude/rules" "$P/mem"
printf '# P\n' > "$P/proj/CLAUDE.md"
printf -- '---\ndescription: eine Lehre aus dem Projekt, vierzig Zeichen lang mindestens\ntype: feedback\n---\n# Lehre\n\nDie Messung stand vor dem Glauben, am 12.09.2026 gemessen.\n' > "$P/mem/lehre.md"
printf -- '---\ndescription: zweite Lehre, verweist auf die erste, vierzig Zeichen\ntype: feedback\n---\n# Zwei\n\nSiehe [[lehre]].\n' > "$P/mem/zwei.md"
printf -- '# Memory\n\n- [Lehre](lehre.md) — Messung vor Glauben\n' > "$P/mem/MEMORY.md"
cat > "$P/lauf.py" <<'PYEOF'
import os, sys
sys.path.insert(0, os.environ["REF"])
import cleaner_audit as audit, cleaner_duplikate as dup
dup._memory_dir = lambda heim, projekt=None: os.environ["MEM"]
audit.lauf(os.environ["PROJ"], "memory")
PYEOF
cat > "$P/audit.py" <<'PYEOF'
import os, subprocess, sys
# cleaner_audit haengt sich beim Import an sys.stdout.buffer — deshalb als Unterprozess, Ausgabe eingefangen
r = subprocess.run([sys.executable, os.environ["LAUF"]], capture_output=True)
t = r.stdout.decode("utf-8", "replace")
print("nichtmessbar=%d" % t.count("nicht messbar (kein Git)"))
print("beleg_lehre=%s" % ("ja" if "1 [[Verweis(e)]], Index ja" in t else "nein"))
print("beleg_zwei=%s" % ("ja" if "0 [[Verweis(e)]], Index NEIN" in t else "nein"))
PYEOF
A=$(REF="$(w "$REF")" MEM="$(w "$P/mem")" PROJ="$(w "$P/proj")" LAUF="$(w "$P/lauf.py")" $PY "$(w "$P/audit.py")" 2>&1)
janein "beide Memory-Dateien: nicht messbar (kein Git) statt Historie-Satz" ja "$(printf '%s\n' "$A" | grep -q 'nichtmessbar=2' && echo ja || echo nein)"
janein "   ... Beleg lehre: 1 Verweis, im Index" ja "$(printf '%s\n' "$A" | grep -q 'beleg_lehre=ja' && echo ja || echo nein)"
janein "   ... Beleg zwei: 0 Verweise, nicht im Index" ja "$(printf '%s\n' "$A" | grep -q 'beleg_zwei=ja' && echo ja || echo nein)"
rm -rf "$P"

echo "== §3/§4  Einordnung: Memory nie HOOK-KANDIDAT; paths gesetzt -> BLEIBT =="
P=$(mktemp -d); mkdir -p "$P/mem" "$P/proj/.claude/rules"
for f in a.py b.py c.py; do printf 'x\n' > "$P/proj/$f"; done
KORPUS='⛔ NIE `a.py` mit `python` starten ohne Test.

⛔ MUST `b.py` vor jedem `git commit` pruefen.

⛔ NEVER `c.py` per `rm` loeschen.

MUST `a.py` mit `python` datieren.
'
printf -- "---\ndescription: eine Lehre mit Befehlen, vierzig Zeichen lang mindestens\ntype: feedback\n---\n# Lehre\n\n$KORPUS" > "$P/mem/lehre.md"
printf -- "---\ndescription: r\n---\n# R\n\n$KORPUS" > "$P/proj/.claude/rules/regel.md"
printf -- "---\ndescription: r\npaths: [\"a.py\", \"b.py\"]\n---\n# R\n\n$KORPUS" > "$P/proj/.claude/rules/gesetzt.md"
cat > "$P/ein.py" <<'PYEOF'
import os, sys
sys.path.insert(0, os.environ["REF"])
import cleaner_einordnung as ein
P = os.environ["P"]
m = ein.mit_skill(os.path.join(P, "mem", "lehre.md"))
r = ein.einordnen(os.path.join(P, "proj", ".claude", "rules", "regel.md"), os.path.join(P, "proj"))
g = ein.einordnen(os.path.join(P, "proj", ".claude", "rules", "gesetzt.md"), os.path.join(P, "proj"))
print("mem=%s|%s" % (m["vorschlag"], m.get("vorschlag_zusammen", "")))
print("rule=%s|%s" % (r["vorschlag"], ",".join(r["vorschlaege"])))
print("gesetzt=%s|%s" % (g["vorschlag"], ",".join(g["vorschlaege"])))
PYEOF
E=$(REF="$(w "$REF")" P="$(w "$P")" $PY "$(w "$P/ein.py")" 2>&1)
janein "Memory-Datei mit Befehlen: BLEIBT MEMORY, nicht HOOK-KANDIDAT" ja "$(printf '%s\n' "$E" | grep -q '^mem=BLEIBT MEMORY|$' && echo ja || echo nein)"
janein "   Gegenprobe: derselbe Text als Rule -> HOOK-KANDIDAT + RULE-PATHS" ja "$(printf '%s\n' "$E" | grep -q '^rule=HOOK-KANDIDAT|HOOK-KANDIDAT,RULE-PATHS$' && echo ja || echo nein)"
janein "paths: schon gesetzt -> BLEIBT (paths gesetzt), kein RULE-PATHS" ja "$(printf '%s\n' "$E" | grep -q '^gesetzt=HOOK-KANDIDAT|HOOK-KANDIDAT,BLEIBT .paths gesetzt.$' && echo ja || echo nein)"
rm -rf "$P"

echo "== §5  Plan: ZEIGER je Dateipaar eine Zeile + Anlage; --anwenden wie bisher =="
P=$(mktemp -d); mkdir -p "$P/proj/.claude-mind"
cat > "$P/plan.py" <<'PYEOF'
import os, sys
sys.path.insert(0, os.environ["REF"])
import cleaner_plan as cp
P = os.environ["P"]; proj = os.path.join(P, "proj")
gruppen = {"3": [("marke-%d" % i, "a.md + b.md" if i < 40 else "c.md + d.md") for i in range(50)]}
z = cp.zeilen_aus_gruppen(gruppen, proj)
plan = os.path.join(P, "plan.md")
cp.schreibe_plan(plan, z, proj, "projekt")
t = open(plan, encoding="utf-8").read()
anl = cp.anlage_pfad(plan)
at = open(anl, encoding="utf-8").read() if os.path.isfile(anl) else ""
print("zeilen=%d zeiger=%d" % (len(z), t.count("| ZEIGER |")))
print("anlage_marken=%d abschnitte=%d" % (at.count("\n- marke-"), at.count("\n## ")))
print("plan_nennt_anlage=%s" % ("ja" if os.path.basename(anl) in t else "nein"))
rc = cp.anwenden(plan, projekt=proj)
st = [x["status"] for x in cp.lies_plan(plan)]
print("rc=%d status=%s" % (rc, ",".join(sorted(set(st)))))
PYEOF
Z=$(REF="$(w "$REF")" P="$(w "$P")" $PY "$(w "$P/plan.py")" 2>&1)
janein "50 doppelte Marken in 2 Paaren -> 2 ZEIGER-Zeilen im Plan" ja "$(printf '%s\n' "$Z" | grep -q 'zeilen=2 zeiger=2' && echo ja || echo nein)"
janein "   ... Anlage traegt alle 50 Marken in 2 Abschnitten" ja "$(printf '%s\n' "$Z" | grep -q 'anlage_marken=50 abschnitte=2' && echo ja || echo nein)"
janein "   ... der Plan nennt die Anlage" ja "$(printf '%s\n' "$Z" | grep -q 'plan_nennt_anlage=ja' && echo ja || echo nein)"
janein "   --anwenden: ZEIGER nur gemeldet, rc 0 (wie bisher)" ja "$(printf '%s\n' "$Z" | grep -q 'rc=0 status=nur gemeldet' && echo ja || echo nein)"
rm -rf "$P"

echo "== §6  laedt beim Start gegen laedt bei Beruehrung =="
P=$(mktemp -d); mkdir -p "$P/proj/.claude/rules" "$P/home/.claude"
printf '# P\n' > "$P/proj/CLAUDE.md"
printf -- '---\npaths: ["x.py"]\n---\n# A\n\n⛔ NIE x.py ohne Test.\n' > "$P/proj/.claude/rules/a.md"
printf -- '---\ndescription: b\n---\n# B\n\n⛔ Laedt immer.\n' > "$P/proj/.claude/rules/b.md"
# shellcheck disable=SC1090
. "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh" >/dev/null 2>&1
B=$(HOME="$P/home" mind_kontext_bilanz "$P/proj" 2>/dev/null)
_SOLL=$(( $(wc -c < "$P/proj/CLAUDE.md") + $(wc -c < "$P/proj/.claude/rules/b.md") ))
janein "Zeile 1: BYTES ohne die paths-Rule, DATEIEN=2" ja "$(printf '%s\n' "$B" | head -1 | grep -q "DATEIEN=2 BYTES=$_SOLL" && echo ja || echo nein)"
janein "Zeile 3: BERUEHRUNG=1 mit den Bytes der paths-Rule" "BERUEHRUNG=1 BERUEHRUNG_B=$(wc -c < "$P/proj/.claude/rules/a.md")" "$(printf '%s\n' "$B" | sed -n 3p)"
janein "   --vergleichen nennt die Beruehrungs-Summe als nicht im Deckel" ja "$(HOME="$P/home" mind_kontext_bilanz "$P/proj" --vergleichen 2>/dev/null | grep -q 'laedt bei Beruehrung .paths:.: 1 Rule.s.' && echo ja || echo nein)"
BA=$($PY "$(w "$REF/bestandsaufnahme.py")" "$(w "$P/proj/.claude/rules")" 2>&1)
janein "bestandsaufnahme: zwei Summen (Start 1 Datei, Beruehrung 1 Datei)" ja "$(printf '%s\n' "$BA" | grep -q 'laedt beim START .*.1 Datei.en. ohne paths:' && printf '%s\n' "$BA" | grep -q 'laedt bei BERUEHRUNG .*.1 Datei.en. mit paths:' && echo ja || echo nein)"
rm -rf "$P"

echo "== §8  DOCS-Zug aus dem Memory: Indexzeile auf docs/, kein Stub, Topic weg =="
P=$(mktemp -d); MEM="$P/home/.claude/projects/slug/memory"; mkdir -p "$MEM" "$P/proj/docs" "$P/proj/.claude-mind"
printf '# P\n' > "$P/proj/CLAUDE.md"
INHALT='Die Zahl 42 Zeilen gilt fuer `werk.py`.\n\nEine lange Herleitung, die nur erklaert und im Dauerkontext nichts verloren hat, Satz um Satz.\n\nGemessen am 12.09.2026 an drei Dateien.\n'
printf -- "---\ndescription: Herleitung zur Zahl 42 und zu werk.py, vierzig Zeichen lang\ntype: reference\n---\n# Herleitung 42\n\n$INHALT" > "$MEM/herleitung.md"
printf -- "# Herleitung 42\n\n$INHALT" > "$P/proj/docs/herleitung.md"
printf -- '# Memory\n\n- [Herleitung 42](herleitung.md) — warum 42\n- [Anderes](anderes.md) — bleibt\n' > "$MEM/MEMORY.md"
printf -- '---\ndescription: anderes Thema, vierzig Zeichen lang mindestens\ntype: feedback\n---\n# Anderes\n\nBleibt.\n' > "$MEM/anderes.md"
PLAN="$P/plan.md"
printf '# Cleaner-Plan test — %s (--nur memory)\n\n| # | Klasse | Datei | Ziel | Gates | Rueckweg | Status |\n|---|---|---|---|---|---|---|\n| 1 | DOCS | %s | docs/herleitung.md | ZEIGER | Snapshot | offen |\n' "$(m "$P/proj")" "$(m "$MEM/herleitung.md")" > "$PLAN"
A=$($PY "$(w "$REF/cleaner_plan.py")" --anwenden "$(w "$PLAN")" --projekt "$(w "$P/proj")" 2>&1); RC=$?
janein "--anwenden rc 0, Zeile angewendet" ja "$([ "$RC" = 0 ] && grep -q '| angewendet |' "$PLAN" && echo ja || echo nein)"
janein "   ... Topic ist WEG (kein Stub)" nein "$([ -f "$MEM/herleitung.md" ] && echo ja || echo nein)"
janein "   ... Indexzeile zeigt direktiv auf docs/herleitung.md" ja "$(grep -q '^- .Herleitung 42..*proj/docs/herleitung.md. — umgezogen nach docs, lies zuerst `.*docs/herleitung.md`' "$MEM/MEMORY.md" && echo ja || echo nein)"
janein "   ... die andere Indexzeile bleibt" ja "$(grep -q '^- .Anderes..anderes.md.' "$MEM/MEMORY.md" && echo ja || echo nein)"
janein "   ... Snapshot haelt das Topic unter memory/" 1 "$(ls "$P/proj/.claude-mind/snapshots/"*_pre-cleaner-plan/memory/herleitung.md 2>/dev/null | wc -l | tr -d ' ')"
janein "   ... die Ausgabe nennt memory_gates als naechsten Schritt" ja "$(printf '%s\n' "$A" | grep -q 'memory_gates.py' && echo ja || echo nein)"
# Gegenprobe: Ziel fehlt -> GEBROCHEN, Topic bleibt
printf -- "---\ndescription: zweite Herleitung, vierzig Zeichen lang mindestens\ntype: reference\n---\n# Zwei\n\nInhalt zwei mit \`zwei.py\`.\n" > "$MEM/zwei.md"
printf '# Cleaner-Plan test — %s (--nur memory)\n\n| # | Klasse | Datei | Ziel | Gates | Rueckweg | Status |\n|---|---|---|---|---|---|---|\n| 1 | DOCS | %s | docs/zwei.md | ZEIGER | Snapshot | offen |\n' "$(m "$P/proj")" "$(m "$MEM/zwei.md")" > "$PLAN"
$PY "$(w "$REF/cleaner_plan.py")" --anwenden "$(w "$PLAN")" --projekt "$(w "$P/proj")" >/dev/null 2>&1; RC=$?
janein "Ziel fehlt: rc 1, GEBROCHEN, Topic bleibt" ja "$([ "$RC" = 1 ] && grep -q 'GEBROCHEN' "$PLAN" && [ -f "$MEM/zwei.md" ] && echo ja || echo nein)"
rm -rf "$P"

echo
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
