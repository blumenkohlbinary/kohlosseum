#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# RATSCHE: kein bash-Block eines SKILL.md ruft eine mind_*-Funktion ohne eigenes `source lib.sh`
# (v5.146.0, Etappe 56 §7).
#
# ⛔ GEMESSEN (28.10.2026, Paket 5.145.0): jeder Code-Block eines Skills ist ein EIGENER
#    Bash-Aufruf. 49 von 81 Bloecken mit mind_*-Aufruf sourcten lib.sh nicht selbst — 34
#    davon ausfuehrbar, 15 Vorlagen mit Platzhaltern. Ein solcher Block ruft Funktionen, die in
#    seinem Prozess nicht existieren: `command not found`, rc 127, je nach Block still.
#    So war der Schlussblock von /mind-all tot (56 §1), und so entstanden sehr wahrscheinlich
#    viele der „von Hand nachgeholten" Schritte.
# ⚠ Was die Ratsche NICHT sieht: Variablen aus frueheren Bloecken ($SNAPSHOT, $LAUF, …).
#   Sie prueft nur, dass die FUNKTIONEN da sind.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Pruefskript: liest eine LISTENDATEI (Pfade mit Leerzeichen), gibt zwei Zeilen aus:
#   <Zahl der Bloecke mit mind_*-Aufruf>
#   <skill:zeile …> der Bloecke OHNE eigenes source, sonst `keiner`
cat > "$TMP/pruefe.py" <<'PYEOF'
import io, os, re, sys
RUF = re.compile(r"(^|[\s;(|&$!])_?mind_[a-z0-9_]+", re.M)
SRC = re.compile(r"(source|\.)\s+\"?\$CLAUDE_PLUGIN_ROOT/hooks/lib\.sh")
def bloecke(t):
    z = t.replace("\r\n", "\n").split("\n"); i = 0
    while i < len(z):
        if z[i].startswith("```bash"):
            j = i + 1
            while j < len(z) and not z[j].startswith("```"):
                j += 1
            yield i + 1, "\n".join(x for x in z[i + 1:j] if not x.lstrip().startswith("#"))
            i = j
        i += 1
n, ohne = 0, []
for f in [l.strip() for l in io.open(sys.argv[1], encoding="utf-8") if l.strip()]:
    s = os.path.basename(os.path.dirname(f))
    for nr, c in bloecke(io.open(f, encoding="utf-8").read()):
        if RUF.search(c):
            n += 1
            if not SRC.search(c):
                ohne.append("%s:%d" % (s, nr))
print(n)
print(" ".join(ohne) or "keiner")
PYEOF
# ⚠ Windows-Python schreibt CRLF auf stdout — das `\r` muss weg, sonst ist „81\r" keine Zahl
pruefe() { mapfile -t ERG < <("$PY" "$(win "$TMP/pruefe.py")" "$(win "$TMP/liste.txt")" | tr -d '\r'); }

for f in "$R"/skills/*/SKILL.md; do win "$f"; echo; done > "$TMP/liste.txt"
pruefe
pruef "Vakuum-Waechter: mindestens 60 Bloecke mit mind_*-Aufruf gelesen" \
  "$([ "${ERG[0]:-0}" -ge 60 ] 2>/dev/null && echo ja || echo "nein (${ERG[0]:-0})")" "ja"
pruef "⛔ kein Block mit mind_*-Aufruf ohne eigenes source" "${ERG[1]:-?}" "keiner"

# GEGENKONTROLLE: die Pruefung schlaegt an einem kaputten Block wirklich an
mkdir -p "$TMP/kaputt"; printf '```bash\nmind_schritt_bilanz "$PROJ"\n```\n' > "$TMP/kaputt/SKILL.md"
win "$TMP/kaputt/SKILL.md" > "$TMP/liste.txt"
pruefe
pruef "Gegenkontrolle: ein Block ohne source wird erkannt" "${ERG[1]:-?}" "kaputt:1"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
