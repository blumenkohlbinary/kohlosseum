#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# VERTRAG: der PFLICHTSCHRITTE-Kasten und die mind_schritt_start-Zeile nennen DIESELBEN
# Schritte — in jedem SKILL.md, das beides hat (v5.145.0, Etappe 55 §2, Veras Befund M-A).
#
# ⛔ WAS GEMESSEN WURDE (Zustellplan, zwei Laeufe 11./12.10.2026, am Quellbaum nachgesehen):
#    `cleaner_tor` stand in vier Kaesten (mind-claudemd, mind-files, mind-memory, mind-rules,
#    mind-update) und in KEINER Startzeile. Folge: quittiert, aber nie erwartet — er erschien
#    als „zusaetzlich" statt als erfuellter Pflichtschritt, und FEHLT konnte ihn nie melden.
# ⭐ Das ist kein Wort, nach dem man greppen koennte, sondern eine ZUSICHERUNG, die alle
#    Dateien derselben Art einhalten muessen (CLAUDE.md, ALLBETROFFENHEIT: Vertraege).
#    Deshalb liest der Prueffall JEDEN Skill, auch die, die heute stimmen.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ok=0; rot=0; n=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

kasten() {  # Namen zwischen der Zeile PFLICHTSCHRITTE und dem schliessenden Fence
  tr -d '\r' < "$1" | awk '/^PFLICHTSCHRITTE$/{f=1; next} f && /^```/{exit} f && NF && $1 !~ /^[(]/{print $1}' | sort -u
}
startzeile() {  # Namen ab dem dritten Wort der ersten mind_schritt_start "$PROJ"-Zeile
  tr -d '\r' < "$1" | grep -m1 '^mind_schritt_start "\$PROJ"' \
    | awk '{for(i=4;i<=NF;i++) print $i}' | sort -u
}

for f in "$R"/skills/*/SKILL.md; do
  s=$(basename "$(dirname "$f")")
  K=$(kasten "$f"); Z=$(startzeile "$f")
  [ -n "$K" ] || continue
  n=$((n+1))
  nur_k=$(comm -23 <(printf '%s\n' "$K") <(printf '%s\n' "$Z") | tr '\n' ' ' | sed 's/ $//')
  nur_z=$(comm -13 <(printf '%s\n' "$K") <(printf '%s\n' "$Z") | tr '\n' ' ' | sed 's/ $//')
  pruef "$s: jeder Kasten-Eintrag steht in der Startzeile" "${nur_k:-keiner}" "keiner"
  pruef "$s: die Startzeile erwartet nichts, was der Kasten nicht nennt" "${nur_z:-keiner}" "keiner"
done

# --- Gegenrichtung (v5.146.0, Etappe 56 §3): jeder ERWARTETE Schritt hat einen AUFRUF ----------
# ⛔ `mind_debug_write` stand in mind-memory im Kasten und in der Startzeile, aufgerufen wurde es
#    nirgends — erwartet, nie gelaufen. Gemessen 28.10.2026: neun solche Stellen in sieben Skills,
#    darunter `cleaner_duplikate` in mind-rules (Noras FEHLT, Palvedo 20.09.2026).
# Ein Aufruf ist: `<name>.py` · `<name>` an Befehlsstelle · `mind_schritt <name>` · der Name in
# der Liste einer `for`-Schleife (mind-denkstufe quittiert so) — jeweils in einem bash-Block,
# ohne Kommentarzeilen und ohne die Startzeile selbst.
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
TMPA="$(mktemp -d)"
cat > "$TMPA/aufruf.py" <<'PYEOF'
import io, re, sys
t = io.open(sys.argv[1], encoding="utf-8").read().replace("\r\n", "\n")
z = t.split("\n"); code = []; i = 0
while i < len(z):
    if z[i].startswith("```bash"):
        j = i + 1
        while j < len(z) and not z[j].startswith("```"):
            if not z[j].lstrip().startswith("#") and not z[j].startswith("mind_schritt_start "):
                code.append(z[j])
            j += 1
        i = j
    i += 1
c = "\n".join(code)
m = re.search(r'^mind_schritt_start "\$PROJ" \S+ ?(.*)$', t, re.M)
fehlt = []
for n in (m.group(1).split() if m else []):
    e = re.escape(n)
    if not (re.search(r"\b%s\.py\b" % e, c) or re.search(r"(^|[\s;(|&$])%s(\s|$|\))" % e, c, re.M)
            or re.search(r"mind_schritt\s+%s\b" % e, c)
            or re.search(r"^\s*for \w+ in [^;\n]*\b%s\b" % e, c, re.M)):
        fehlt.append(n)
print(" ".join(fehlt))
PYEOF
for f in "$R"/skills/*/SKILL.md; do
  s=$(basename "$(dirname "$f")")
  ohne=$("$PY" "$(win "$TMPA/aufruf.py")" "$(win "$(skill_text_datei "$R" "$s")")" | tr -d '\r')
  pruef "$s: jeder erwartete Schritt wird im Skill aufgerufen" "${ohne:-keiner}" "keiner"
done
rm -rf "$TMPA"

# ⛔ VAKUUM-WAECHTER: findet die Sammlung keinen Kasten, ist sie gruen, ohne gemessen zu haben.
#    Heute tragen zehn Skills einen Kasten; weniger als acht heisst: das Format hat sich
#    geaendert und der Vertrag wird nicht mehr gelesen.
pruef "mindestens acht Skills mit Kasten gelesen" "$([ "$n" -ge 8 ] && echo ja || echo "nein ($n)")" "ja"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
