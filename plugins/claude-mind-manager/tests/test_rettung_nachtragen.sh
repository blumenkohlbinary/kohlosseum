#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Das Netz: Rettungen, die OPEN nicht nennt, werden nachgetragen (v5.143.0, Etappe 53 §2).
#
# ⛔ Am 01.10.2026 fand die Luecke nur Noras Gegenzaehlung VON HAND: `mind_rettungen` (liest
#    OPEN) sagte 2, `mind_rettungen_ungelesen` (liest die Zeitstempel) sagte 3. Diese Sammlung
#    haelt fest, dass der Skill die Gegenzaehlung jetzt selbst macht — und dass er dabei
#    nichts doppelt eintraegt, nichts Altes hineinzieht und nicht schweigt, wenn er blind ist.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$R/hooks/lib.sh"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

# --- 0 · VAKUUM-WAECHTER ----------------------------------------------------
pruef "mind_rettungen_nachtragen ist definiert" "$(type -t mind_rettungen_nachtragen 2>/dev/null)" "function"
[ "$(type -t mind_rettungen_nachtragen 2>/dev/null)" = "function" ] || { echo "  Gegenstand fehlt"; echo "  $ok gruen · $((rot)) rot"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
neu() { local d="$TMP/$1 mit leer"; mkdir -p "$d/.claude-mind/rescued"; printf '%s' "$d"; }
rettung() { : > "$1/.claude-mind/rescued/$2_chat.md"; : > "$1/.claude-mind/rescued/$2_RESUME.md"; }
eintraege() { grep -c '^path=' "$1/.claude-mind/rescued/OPEN" 2>/dev/null || echo 0; }

echo "=== 1) ⛔ die Lage vom 01.10.: eine Rettung, die OPEN nicht nennt ==="
P=$(neu f1)
printf 'ts=20261001-194600\nutc=2026-10-01T17:46:00Z\n' > "$P/.claude-mind/rescued/letzter-sync"
rettung "$P" "20261001-204719-394-654a7fa0"          # NACH letzter-sync -> ungelesen
AUS=$(mind_rettungen_nachtragen "$P" 2>&1); RC=$?
pruef "rc 0 (ein Netz bricht keinen Lauf ab)" "$RC" "0"
pruef "⛔ jetzt steht sie in OPEN"           "$(eintraege "$P")" "1"
pruef "   ... mit grund=nachgetragen"        "$(grep -c '^grund=nachgetragen$' "$P/.claude-mind/rescued/OPEN")" "1"
pruef "   ... samt RESUME"                   "$(grep -c '^resume=.*_RESUME.md$' "$P/.claude-mind/rescued/OPEN")" "1"
pruef "   ... und es wird GEMELDET"          "$(printf '%s' "$AUS" | grep -c 'NACHGETRAGEN: 20261001-204719-394-654a7fa0_chat.md')" "1"

echo "=== 2) idempotent: der zweite Lauf traegt nichts doppelt ein ==="
mind_rettungen_nachtragen "$P" >/dev/null 2>&1
pruef "weiterhin genau EIN Eintrag" "$(eintraege "$P")" "1"

echo "=== 3) ⛔ dieselbe Datei, ANDERE Pfad-Schreibweise in OPEN — kein Doppel ==="
# Der Hook schreibt den Pfad, wie er ihn bildete; die Ratsche bildet ihn neu. Ein Pfadvergleich
# truege jede Rettung doppelt ein. Verglichen wird der NAME.
P=$(neu f3)
printf 'ts=20261001-194600\nutc=2026-10-01T17:46:00Z\n' > "$P/.claude-mind/rescued/letzter-sync"
rettung "$P" "20261002-211739-831-654a7fa0"
printf 'path=/c/irgendwie/anders/geschrieben/20261002-211739-831-654a7fa0_chat.md\n' > "$P/.claude-mind/rescued/OPEN"
mind_rettungen_nachtragen "$P" >/dev/null 2>&1
pruef "kein zweiter Eintrag fuer denselben Namen" "$(eintraege "$P")" "1"

echo "=== 4) eine Rettung VOR dem letzten Sync wird nicht hineingezogen ==="
P=$(neu f4)
printf 'ts=20261002-120000\nutc=2026-10-02T10:00:00Z\n' > "$P/.claude-mind/rescued/letzter-sync"
rettung "$P" "20261001-204719-394-654a7fa0"          # VOR letzter-sync -> gelesen
mind_rettungen_nachtragen "$P" >/dev/null 2>&1
pruef "nichts nachgetragen" "$(eintraege "$P")" "0"

echo "=== 5) ⚠ ohne letzter-sync ist die Gegenzaehlung blind — und SAGT das ==="
P=$(neu f5)
rettung "$P" "20261001-204719-394-654a7fa0"
AUS=$(mind_rettungen_nachtragen "$P" 2>&1); RC=$?
pruef "rc 0"                                   "$RC" "0"
pruef "nichts nachgetragen (es weiss es nicht)" "$(eintraege "$P")" "0"
pruef "⛔ aber es MELDET, dass es blind ist"    "$(printf '%s' "$AUS" | grep -c 'NICHT PRUEFBAR')" "1"

echo "=== 6) ohne Argument: rc 2, nicht stilles Nichtstun ==="
mind_rettungen_nachtragen "" >/dev/null 2>&1; pruef "rc 2" "$?" "2"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
