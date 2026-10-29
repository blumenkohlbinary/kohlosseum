#!/usr/bin/env bash
# tests/lib_test.sh — wird von JEDER Pruefsammlung gesourct (v5.114.0, Etappe 21 §1).
#
# ⛔ JEDES FIXTURE LIEGT UNTER EINEM PFAD MIT LEERZEICHEN. v5.113.0 kam mit 75/75 gruen
#    durch und brach an jedem echten Projektpfad: `mind_sync_voll` lehnte `*[[:space:]]*`
#    ab, und jedes Fixture lag unter `mktemp -d` ohne Leerzeichen. Alle Projekte hier
#    heissen `Plugin - Entwicklung`, `APP - Palvedo` (shell-windows.md: „zerlegt an jedem
#    Leerzeichen — `Plugin - Entwicklung` hat eins"). Die Pruefung muss die Falle
#    ENTHALTEN, sonst misst sie an ihr vorbei.
# ⭐ EIN Mechanismus: `mktemp -d` ohne Vorlage und Pythons `tempfile` nehmen $TMPDIR. Liegt
#    dort schon ein Pfad mit Leerzeichen (alle.sh setzt ihn fuer den ganzen Lauf), passiert
#    hier nichts; standalone legt jede Sammlung sich `<Temp>/Mind Test <pid>/` selbst an.
# ⚠ `cygpath -m` liefert `C:/…` — den Pfad verstehen Git-Bash UND python.exe; ein
#    MSYS-`/tmp/…` waere fuer python.exe kein Verzeichnis (shell-windows.md).
case "${TMPDIR:-}" in
  *" "*) ;;
  *)
    _MT_BASIS=$(cygpath -m "${TEMP:-${TMP:-/tmp}}" 2>/dev/null) || _MT_BASIS="${TMPDIR:-/tmp}"
    _MT="${_MT_BASIS%/}/Mind Test $$"
    mkdir -p "$_MT" 2>/dev/null && export TMPDIR="$_MT"
    # nur der leere Ordner wird am Ende entfernt — Fixtures raeumt jede Sammlung selbst
    trap 'rmdir "$_MT" 2>/dev/null' EXIT ;;
esac

# skill_text_datei <plugin-root> <skill>  -> Pfad einer Datei: SKILL.md + bloecke/*.sh aneinander (v5.152.0)
# ⭐ Seit Etappe 58 Hebel B steht der Code eines Skills in `skills/<s>/bloecke/*.sh`, der Text in
#    SKILL.md. Eine Zusicherung "der Code tut X" behaelt so ihr Ziel, egal auf welcher Seite er steht.
# ⚠ EINE feste Datei je Skill unter <Temp>/mind-skilltext/, bei jedem Aufruf neu geschrieben —
#    sie waechst nicht und braucht keinen trap (die Sammlungen setzen ihren eigenen).
skill_text_datei() {
  local d f
  d="$(cygpath -m "${TEMP:-${TMP:-/tmp}}" 2>/dev/null || printf '%s' "${TMPDIR:-/tmp}")/mind-skilltext"
  mkdir -p "$d" 2>/dev/null; f="$d/$2.md"
  cat "$1/skills/$2/SKILL.md" "$1/skills/$2/bloecke/"*.sh > "$f" 2>/dev/null \
    || cat "$1/skills/$2/SKILL.md" > "$f" 2>/dev/null
  printf '%s' "$f"
}
