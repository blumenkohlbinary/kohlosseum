#!/usr/bin/env bash
# Prueffaelle fuer die fuenf neuen lib.sh-Funktionen (v5.11.0).
#
# ⛔ Jede Zusicherung greift auf einen RUECKGABEWERT zu, nie auf Berichtstext.
# Zu jedem Positivfall steht ein Negativfall -- eine Funktion, die immer
# dasselbe liefert, muss hier rot werden.

WURZEL="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck disable=SC1091
. "$WURZEL/hooks/lib.sh" 2>/dev/null || { echo "lib.sh nicht ladbar: $WURZEL"; exit 1; }

OK=0; ROT=0
ja() { if [ "$2" = "$3" ]; then echo "  [ok ] $1"; OK=$((OK+1));
       else echo "  [ROT] $1 -> '$2', erwartet '$3'"; ROT=$((ROT+1)); fi; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

echo "=== 1 - mind_pfad_lebt: die Tilde (der Fehler, der Zeilen loeschte) ==="

# REPRODUKTION des alten Verhaltens: so hat der Skill geprueft.
if [ -e "~/.claude/rules/autonom-arbeiten.md" ]; then ALT="gefunden"; else ALT="DEAD"; fi
ja "alte Pruefung meldet die Tilde-Datei als tot (Repro)" "$ALT" "DEAD"

if [ -e "$HOME/.claude/rules/autonom-arbeiten.md" ]; then
  if mind_pfad_lebt "~/.claude/rules/autonom-arbeiten.md"; then N="lebt"; else N="DEAD"; fi
  ja "NEU: dieselbe Datei wird gefunden" "$N" "lebt"
else
  echo "  [uebersprungen] autonom-arbeiten.md liegt hier nicht"
fi

# NEGATIV: eine Tilde-Datei, die es WIRKLICH nicht gibt, muss tot bleiben.
# Ohne diesen Fall waere ein `return 0` gruen.
if mind_pfad_lebt "~/.claude/rules/gibt-es-nicht-4711.md"; then N="lebt"; else N="DEAD"; fi
ja "NEGATIV: erfundene Tilde-Datei bleibt tot" "$N" "DEAD"

# Absolute und relative Pfade unveraendert
printf 'x\n' > "$TMP/da.md"
if mind_pfad_lebt "$TMP/da.md"; then N="lebt"; else N="DEAD"; fi
ja "absoluter Pfad lebt weiter" "$N" "lebt"
if mind_pfad_lebt "$TMP/weg.md"; then N="lebt"; else N="DEAD"; fi
ja "NEGATIV: absoluter Pfad ohne Datei bleibt tot" "$N" "DEAD"

echo
echo "=== 2 - mind_classify_path: die alten Klassen bleiben ==="
ja "Markdown-Link -> SKIP"      "$(mind_classify_path '[n](../x.md)')"        "SKIP"
ja "Slash-Command -> SKIP"      "$(mind_classify_path '/mind-all')"           "SKIP"
ja "Web-Adresse -> SKIP"        "$(mind_classify_path 'github.com/a/b')"      "SKIP"
ja "Platzhalter -> SKIP"        "$(mind_classify_path 'src/<name>.py')"       "SKIP"
ja "NEGATIV: /etc bleibt UNSURE" "$(mind_classify_path '/etc')"               "UNSURE"
ja "NEGATIV: echter Pfad -> CHECK" "$(mind_classify_path 'hooks/lib.sh')"     "CHECK"
ja "Tilde-Pfad -> CHECK"        "$(mind_classify_path '~/.claude/rules/a.md')" "CHECK"

echo
echo "=== 3 - ⛔ mind_sync_frisch ist ENTFALLEN (v5.65.0) ==="
# ⛔ HIER STANDEN SECHS FAELLE ueber den ZUWACHS seit dem Sync. Sie haben ihr
#    ZIEL verloren: ohne `tokens=` im Merker konnte die Funktion nur noch EINE
#    Antwort geben, und ihr einziger Aufrufer (die Token-Mahnung) ist mit
#    entfallen. Nutzer-Entscheidung 10.09.2026.
#
# ⭐ WOHIN DIE TRAGENDE ZUSICHERUNG GING: "ein TEILSYNC ist kein Sync" stand
#    nie in ihr — sie reichte `mind_sync_voll` nur weiter. Das entscheidet
#    heute `mind_sync_voll` allein, abgesichert in `tests/test_teilsync.sh`.
# ⚠ WAS WIRKLICH AUFHOERT: der `sync-stand` loest sich nicht mehr selbst auf.
#   Verbraucht wird er von `pre-compact.sh` — der Zustand von v5.7.0 bis
#   v5.10.0. Die Auto-Kompaktierung ist seit 23.08.2026 wieder scharf, der
#   Verbraucher laeuft also von selbst.
# ⛔ UMGEKEHRT STATT GELOESCHT — gegen den alten Stand ROT.
if type mind_sync_frisch >/dev/null 2>&1; then N="definiert"; else N="weg"; fi
ja "mind_sync_frisch ist nicht mehr definiert"  "$N" "weg"
S="$TMP/sync-stand"
printf 'ts=x\numfang=5/5 skills 4/4 agents\n' > "$S"
if mind_sync_voll "$S"; then N="voll"; else N="teil"; fi
ja "⭐ was BLEIBT: mind_sync_voll urteilt weiter"  "$N" "voll"
printf 'ts=x\numfang=5/5 skills 0/4 agents\n' > "$S"
if mind_sync_voll "$S"; then N="voll"; else N="teil"; fi
ja "⭐ und erkennt den Teilsync"                   "$N" "teil"

echo
echo "=== 4 - mind_zeilenenden: Anteil, nicht Zeilenzahl ==="
printf 'a\nb\nc\n'       > "$TMP/lf.txt"
printf 'a\r\nb\r\nc\r\n' > "$TMP/crlf.txt"
ja "reine LF-Datei"   "$(mind_zeilenenden "$TMP/lf.txt")"   "0/3"
ja "reine CRLF-Datei" "$(mind_zeilenenden "$TMP/crlf.txt")" "3/3"

V=$(mind_zeilenenden "$TMP/lf.txt")
cp "$TMP/lf.txt" "$TMP/nach.txt"
if mind_zeilenenden_gleich "$V" "$(mind_zeilenenden "$TMP/nach.txt")"; then N="gleich"; else N="gekippt"; fi
ja "unveraenderte Datei -> gleich"    "$N" "gleich"

# NEGATIV, der eigentliche Fall: gleiche ZEILENZAHL, gekippte Enden.
# Eine Zusicherung auf die Zeilenzahl waere hier gruen.
printf 'a\r\nb\r\nc\r\n' > "$TMP/nach.txt"
if mind_zeilenenden_gleich "$V" "$(mind_zeilenenden "$TMP/nach.txt")"; then N="gleich"; else N="gekippt"; fi
ja "LF->CRLF bei GLEICHER Zeilenzahl -> gekippt" "$N" "gekippt"

echo
echo "=================================="
echo "  $OK bestanden, $ROT rot"
[ "$ROT" -eq 0 ]
