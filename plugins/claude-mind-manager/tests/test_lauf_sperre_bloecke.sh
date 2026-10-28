#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Die Lauf-Sperre haelt ueber die Bloecke eines Laufs (v5.144.0, Etappe 56 §1).
#
# ⛔ WAS GEMESSEN WURDE (28.10.2026, im echten Werkzeug): jeder Code-Block eines SKILL.md
#    ist ein EIGENER Bash-Aufruf. Der unbedingte `trap 'mind_lauf_frei …' EXIT` aus Step 0
#    feuerte am Ende DIESES Blocks — im naechsten Aufruf war der Lock weg. Er schuetzte
#    nichts: weder die Abweisung eines zweiten Laufs noch die Regel „liegt der Lock, aendert
#    der Arbeiter keine Dauerkontext-Datei". Und die Identitaetspruefung aus v5.140.0
#    (Kopf-Lauf gegen Lock-Lauf) lief in jedem echten Lauf in ihren Ohne-Lock-Zweig.
# ⭐ Jeder Fall unten startet `bash` NEU — genau das ist der Gegenstand. Ein Test, der beide
#    Bloecke in EINER Shell faehrt, waere gegen den alten Stand gruen.
# ⛔ Die trap-Zeile und der Schlussblock werden AUS DEM SKILL.md gelesen, nicht abgeschrieben:
#    sonst prueft der Test seine eigene Kopie.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
S="$R/skills/mind-all/SKILL.md"
GB="${MIND_TEST_BASH:-bash}"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

# --- 0 · VAKUUM-WAECHTER ----------------------------------------------------
TRAPZ=$(grep -m1 "^trap .*mind_lauf_frei" "$S" | tr -d '\r')
pruef "Step 0 traegt eine trap-Zeile mit mind_lauf_frei" "$([ -n "$TRAPZ" ] && echo ja || echo nein)" "ja"
[ -n "$TRAPZ" ] || { echo "  Gegenstand fehlt"; echo "  $ok gruen · $rot rot"; exit 1; }
# Schlussblock = der bash-Fence, der `mind_lauf_frei "$PROJ" "${LAUF:-}"` enthaelt (Step 2.9)
SCHLUSS=$(awk '/^```bash/{f=1; b=""; next} /^```/{if(f && b ~ /mind_lauf_frei "\$PROJ" "\$\{LAUF:-\}"/){print b; exit} f=0; next} f{b=b $0 "\n"}' "$S" | tr -d '\r')
pruef "der Schlussblock (Step 2.9) ist auffindbar" "$([ -n "$SCHLUSS" ] && echo ja || echo nein)" "ja"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf '%s\n' "$TRAPZ"   > "$TMP/trap.sh"
printf '%s\n' "$SCHLUSS" > "$TMP/schluss.sh"
neu() { local d="$TMP/$1 mit leer"; mkdir -p "$d/.claude-mind/rescued"; printf '%s' "$d"; }
lock() { [ -d "$1/.claude-mind/mind-all.lock" ] && echo liegt || echo weg; }

# Ein Block wie im Werkzeug: frische bash, lib.sh, Sperre, trap aus dem SKILL.md, dann $3 als Ende.
block0() {  # $1 = Projekt, $2 = Lauf, $3 = Sitzung, $4 = rc am Blockende
  CLAUDE_PLUGIN_ROOT="$R" MIND_LOG_FILE="$1/log.txt" PROJ="$1" LAUF="$2" SID="$3" RC="$4" T="$TMP/trap.sh" \
    "$GB" -c 'source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
              mind_lauf_sperre "$PROJ" "$LAUF" "$SID" >/dev/null || exit 9
              . "$T"
              exit "$RC"' >/dev/null 2>&1
}

echo "=== 1) ⛔ zwei Bloecke hintereinander: nach Block 1 liegt der Lock NOCH ==="
P=$(neu f1)
block0 "$P" "lauf-A-123456789" "SITZUNG-A-123456789" 0
pruef "⛔ Lock liegt nach dem Ende von Block 1"  "$(lock "$P")" "liegt"
pruef "   ... und traegt den Lauf"              "$(cat "$P/.claude-mind/mind-all.lock/lauf" 2>/dev/null)" "lauf-A-123456789"
# Block 2: ein zweiter Lauf einer ANDEREN Sitzung wird abgewiesen
CLAUDE_PLUGIN_ROOT="$R" MIND_LOG_FILE="$P/log.txt" PROJ="$P" "$GB" -c \
  'source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"; mind_lauf_sperre "$PROJ" "lauf-B-987654321" "SITZUNG-B-987654321" >/dev/null' 2>/dev/null
pruef "⛔ ein fremder zweiter Lauf wird abgewiesen (rc 1)" "$?" "1"
pruef "   ... und der Lock gehoert weiter Lauf A" "$(cat "$P/.claude-mind/mind-all.lock/lauf" 2>/dev/null)" "lauf-A-123456789"

echo "=== 2) Abbruch IN Step 0 (rc != 0): der trap gibt frei ==="
P=$(neu f2)
block0 "$P" "lauf-A-123456789" "SITZUNG-A-123456789" 1
pruef "Lock weg nach Abbruch" "$(lock "$P")" "weg"

echo "=== 3) der Schlussblock (Step 2.9) gibt frei — in EIGENER bash, ohne geerbte Variablen ==="
P=$(neu f3)
block0 "$P" "lauf-A-123456789" "SITZUNG-A-123456789" 0
# die Kopfzeile, aus der der Schlussblock die eigene Lauf-ID liest
printf '{"ereignis":"start","skill":"mind-all","lauf":"lauf-A-123456789","ts":"2026-10-28T10:00:00Z"}\n' \
  > "$P/.claude-mind/schritt-quittung.jsonl"
: > "$P/.claude-mind/analyzed-scopes"
( cd "$P" && env -u PROJ -u LAUF -u SCOPES_FILE CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PROJECT_DIR="$P" \
    MIND_LOG_FILE="$P/log.txt" "$GB" "$TMP/schluss.sh" >/dev/null 2>&1 )
pruef "⛔ Lock weg nach dem Schlussblock"           "$(lock "$P")" "weg"
pruef "⛔ analyzed-scopes nach .done umbenannt"     "$([ -f "$P/.claude-mind/analyzed-scopes.done" ] && [ ! -f "$P/.claude-mind/analyzed-scopes" ] && echo ja || echo nein)" "ja"

echo "=== 4) GEGENKONTROLLE: der Schlussblock raeumt einem FREMDEN Lauf nichts weg ==="
P=$(neu f4)
block0 "$P" "lauf-B-987654321" "SITZUNG-B-987654321" 0
printf '{"ereignis":"start","skill":"mind-all","lauf":"lauf-A-123456789","ts":"2026-10-28T10:00:00Z"}\n' \
  > "$P/.claude-mind/schritt-quittung.jsonl"
( cd "$P" && env -u PROJ -u LAUF -u SCOPES_FILE CLAUDE_PLUGIN_ROOT="$R" CLAUDE_PROJECT_DIR="$P" \
    MIND_LOG_FILE="$P/log.txt" "$GB" "$TMP/schluss.sh" >/dev/null 2>&1 )
pruef "fremder Lock bleibt liegen" "$(lock "$P")" "liegt"

echo "=== 5) ⭐ liegengebliebener Lock der EIGENEN Sitzung: sofort uebernommen ==="
# Sonst sperrte sich eine Sitzung nach einem abgebrochenen Lauf zwei Stunden selbst aus —
# das waere der Preis dafuer, dass der Lock jetzt wirklich haelt.
P=$(neu f5)
block0 "$P" "lauf-A-123456789" "SITZUNG-A-123456789" 0
block0 "$P" "lauf-A2-23456789" "SITZUNG-A-123456789" 0
pruef "dieselbe Sitzung bekommt die Sperre" "$(cat "$P/.claude-mind/mind-all.lock/lauf" 2>/dev/null)" "lauf-A2-23456789"
pruef "   ... und das wird GELOGGT"         "$(grep -c 'eigenen Sitzung' "$P/log.txt" 2>/dev/null)" "1"

echo "=== 6) GEGENKONTROLLE: 'unbekannt' auf beiden Seiten ist KEIN Treffer ==="
P=$(neu f6)
block0 "$P" "lauf-A-123456789" "unbekannt" 0
CLAUDE_PLUGIN_ROOT="$R" MIND_LOG_FILE="$P/log.txt" PROJ="$P" "$GB" -c \
  'source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"; mind_lauf_sperre "$PROJ" "lauf-C-111111111" "unbekannt" >/dev/null' 2>/dev/null
pruef "abgewiesen wie bisher (rc 1)" "$?" "1"

echo "=== 7) die Uebernahme eines VERWAISTEN Locks schreibt die Sitzung mit ==="
P=$(neu f7)
mkdir -p "$P/.claude-mind/mind-all.lock"; printf 'alt' > "$P/.claude-mind/mind-all.lock/lauf"; echo 1 > "$P/.claude-mind/mind-all.lock/ts"
block0 "$P" "lauf-D-444444444" "SITZUNG-D-444444444" 0
pruef "sid steht im uebernommenen Lock" "$(cat "$P/.claude-mind/mind-all.lock/sid" 2>/dev/null)" "SITZUNG-D-444444444"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
