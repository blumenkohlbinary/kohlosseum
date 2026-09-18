#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
# =============================================================================
#  bestandsaufnahme.py am BREITEN Projektbaum  (NEU v5.126.0, Etappe 38 §3 — Z431–Z444)
# =============================================================================
#
# ⛔ WOZU. Palvedo meldete den KeyError (795x `ergebnis.md` in Unterordnern) VIERMAL
#    (14.–15.09.2026), Zustellplan einmal mit `--ordner <wurzel>` (`…_chat.md`, Zeile 262,
#    `werte[n]`), und am 16.09. hiess es „reproduziert sich nur bei breiterem Baum".
#    v5.107.0 (8c84d6a) hatte den Schluessel schon auf den RELATIVEN Pfad gestellt —
#    gemessen 19.09.2026 an genau diesem Fixture: 5.106.0 KeyError 'b.md' in vier von
#    fuenf Aufrufformen, 5.107.0/5.124.0/Quellbaum in allen fuenf rc 0. Der vierte
#    Palvedo-Lauf (15.09. 22:49) lief noch auf 5.105.0 (Versionssprung 5.105.0 -> 5.112.0
#    MITTEN in der Sitzung, Z442); der Satz vom 16.09. war eine Folgerung aus einem
#    Lauf, der den breiten Baum gar nicht angefasst hatte (`.claude/rules`).
#    Diese Sammlung haelt den breiten Baum fest, damit ein Rueckfall auffaellt.
# =============================================================================
set -u
WURZEL="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BA="$WURZEL/references/bestandsaufnahme.py"
[ -f "$BA" ] || { echo "ABBRUCH: $BA fehlt"; exit 2; }

OK=0; ROT=0
janein() {
  if [ "$2" = "$3" ]; then
    printf '    OK   %-64s ist=%s\n' "$1" "$3"; OK=$((OK + 1))
  else
    printf '    FEHL %-64s ist=%-12s soll=%s\n' "$1" "$3" "$2"; ROT=$((ROT + 1))
  fi
}

T=$(mktemp -d "${TMPDIR:-/tmp}/Mind Baum XXXXXX") || exit 2
F="$T/proj mit leer"; mkdir -p "$F/.claude/rules" "$F/.claude-mind/rescued" "$F/src/tief"
i=1; while [ $i -le 795 ]; do mkdir -p "$F/laeufe/l$i"; printf '# e\n\nText %d.\n' "$i" > "$F/laeufe/l$i/ergebnis.md"; i=$((i+1)); done
printf '# r\n\nNIE x ohne Sicherung.\n' > "$F/.claude/rules/a.md"
printf -- '---\npaths: ["src/**"]\n---\n# b\n\nText.\n' > "$F/.claude/rules/b.md"
printf '# chat\n\nBeitrag.\n' > "$F/.claude-mind/rescued/20260903-224028_chat.md"
printf '# wurzel\n' > "$F/ergebnis.md"
printf '# a\n' > "$F/src/a.md"; printf '# a\n' > "$F/src/tief/a.md"
FW=$(cygpath -w "$F" 2>/dev/null || printf '%s' "$F")
OUT="$T/out.txt"

lauf() { PYTHONIOENCODING=utf-8 python "$BA" "$@" > "$OUT" 2>&1; echo "$? $(grep -c KeyError "$OUT") $(grep -oE 'BESTANDSAUFNAHME  \([0-9]+ Dateien' "$OUT" | grep -oE '[0-9]+')"; }

echo "=============================================================================="
echo "  795x ergebnis.md + rescued/_chat.md + Wurzel-ergebnis.md: rc 0, kein KeyError, 801 Dateien"
echo "=============================================================================="
janein "--ordner <wurzel> (Windows-Pfad)" "0 0 801" "$(lauf --ordner "$FW")"
janein "<wurzel> positional" "0 0 801" "$(lauf "$FW")"
janein "--ordner . aus dem Projekt heraus" "0 0 801" "$(cd "$F" && lauf --ordner .)"
janein "--ordner <msys-pfad>" "0 0 801" "$(lauf --ordner "$F")"
janein "--ordner <wurzel>/.claude/rules (enger Scope, 2 Dateien)" "0 0 2" "$(lauf --ordner "$F/.claude/rules")"
janein "gleichnamige Dateien bleiben getrennt: 795 Zeilen laeufe/…/ergebnis.md" 795 "$(lauf --ordner "$FW" >/dev/null; grep -c 'laeufe/l[0-9]*/ergebnis.md' "$OUT")"
janein "Schluessel ist der relative Pfad (src/a.md UND src/tief/a.md)" 2 "$(grep -c '^  src/\(tief/\)\?a.md ' "$OUT")"
janein "Datei mit paths: zaehlt als BERUEHRUNG (1 Datei)" ja "$(grep -q '(1 Datei(en) mit paths:' "$OUT" && echo ja || echo nein)"

rm -rf "$T"
echo
echo "=============================================================================="
echo "  $OK ok, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
