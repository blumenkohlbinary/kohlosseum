#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"
# Der Abschluss von /mind-all laeuft als GETRENNTE Prozesse — wie im echten Lauf (v5.152.0, Etappe 58).
#
# ⛔ GEMESSEN 29.10.2026 am Paket 5.151.0: 2.96a, 2.96a-R, der Merker-Block und 2.96 waren vier eigene
#    bash-Fences, also vier eigene Bash-Aufrufe. `SYNC_LIEF`, `UMFANG`, `UNGEPRUEFT` setzte der erste,
#    lasen die anderen — dort waren sie leer. Ohne Handuebertrag durch das Modell: kein `sync-stand`,
#    kein `letzter-sync`, `OPEN` blieb. Der Reparatur-Zaehler begann je Aufruf bei 0, die Meldung nach
#    Pass 2 kam nie. Die bisherigen Prueffaelle greppten nur den TEXT und sahen das nicht.
# ⭐ Hier wird das Skript in FRISCHEN Prozessen gefahren, ohne eine einzige uebertragene Variable.
#    Stub nur fuer die Bilanz (eigene Prueffaelle) — Gegenstand ist die Prozessgrenze.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
A="$R/skills/mind-all/bloecke/step2.96-abschluss.sh"
pruef "Gegenstand: step2.96-abschluss.sh liegt im Paket" "$([ -f "$A" ] && echo ja || echo nein)" "ja"
[ -f "$A" ] || { echo "  $ok gruen · $rot rot"; exit 1; }

ST="$TMP/stub wurzel"; mkdir -p "$ST"
cp -r "$R/hooks" "$R/references" "$R/skills" "$ST/" 2>/dev/null
mv "$ST/hooks/lib.sh" "$ST/hooks/lib_echt.sh"
cat > "$ST/hooks/lib.sh" <<'EOF'
. "${BASH_SOURCE[0]%/*}/lib_echt.sh"
mind_lauf_voll()        { cat "$PROJ/stub-voll" 2>/dev/null || echo teil; }
mind_umfang_bilden()    { echo "5/5 skills 4/4 agents 5/5 bestand 5/5 abdeckung 5/5 echt"; }
mind_ungepruef_bilden() { :; }
mind_teilsync_meldung() { echo "$*" > "$PROJ/stub-meldung"; }
EOF

lage() {  # Projekt mit Lauf L1 (Startzeile in der Quittung), zwei offenen Rettungen, beide eingelesen
  local d="$TMP/$1 mit leer" x; mkdir -p "$d/.claude-mind/rescued"
  printf '{"ts":"2026-10-29 19:00:00","ereignis":"start","skill":"mind-all","lauf":"L1-abc"}\n' \
    > "$d/.claude-mind/schritt-quittung.jsonl"
  for x in files claudemd memory rules update; do printf 'skill=mind-%s|L1-abc\n' "$x"; done \
    > "$d/.claude-mind/analyzed-scopes"   # alle fuenf liefen — sonst ist das Urteil `nein`, nicht `teil`
  printf 'compactions=2\n' > "$d/.claude-mind/rescued/OPEN"
  for x in A B; do
    : > "$d/.claude-mind/rescued/2026102${x}_chat.md"; : > "$d/.claude-mind/rescued/2026102${x}_RESUME.md"
    printf 'path=%s\nresume=%s\nts=2026102%s\ngrund=x\n' "$d/.claude-mind/rescued/2026102${x}_chat.md" \
      "$d/.claude-mind/rescued/2026102${x}_RESUME.md" "$x" >> "$d/.claude-mind/rescued/OPEN"
  done
  printf '%s\n' 2026102A_chat.md 2026102B_chat.md > "$d/.claude-mind/rescued/OPEN.gelesen-L1-abc"
  printf '%s' "$d"
}
# Ein Aufruf wie im Lauf: frische bash, cwd = Projekt, KEINE uebertragene Variable
abschluss() { ( cd "$1" && env -u PROJ -u LAUF -u SYNC_LIEF -u UMFANG -u UNGEPRUEFT -u SCOPES_FILE \
  CLAUDE_PLUGIN_ROOT="$ST" MIND_LOG_FILE="$TMP/log" bash "$ST/skills/mind-all/bloecke/step2.96-abschluss.sh" \
  > "$1/aus.txt" 2>&1 ); }
da() { [ -e "$1" ] && echo da || echo fehlt; }

echo "=== 1) Lauf voll: EIN Aufruf schreibt sync-stand + letzter-sync und tilgt die Schuld ==="
P=$(lage f1); echo voll > "$P/stub-voll"
abschluss "$P"
pruef "⛔ sync-stand geschrieben"                 "$(da "$P/.claude-mind/rescued/sync-stand")" "da"
pruef "   ... mit vollem umfang="                 "$(grep -c '^umfang=5/5 skills 4/4 agents' "$P/.claude-mind/rescued/sync-stand" 2>/dev/null)" "1"
pruef "⛔ letzter-sync geschrieben"               "$(da "$P/.claude-mind/rescued/letzter-sync")" "da"
pruef "⛔ OPEN getilgt (beide Rettungen eingelesen)" "$(da "$P/.claude-mind/rescued/OPEN")" "fehlt"
pruef "Schlusszeile nennt SYNC_LIEF=ja"           "$(grep -c 'ABSCHLUSS: SYNC_LIEF=ja' "$P/aus.txt")" "1"
pruef "kein Reparatur-Zaehler liegt"              "$(ls "$P/.claude-mind/"reparatur-pass-* 2>/dev/null | wc -l | tr -d ' ')" "0"

echo "=== 2) ⛔ Lauf teil: der Reparatur-Zaehler zaehlt UEBER die Aufrufe ==="
P=$(lage f2)
abschluss "$P"
pruef "Aufruf 1: Pass 1"                          "$(cat "$P/.claude-mind/reparatur-pass-L1-abc" 2>/dev/null)" "1"
pruef "   ... noch keine Meldung an den manager"  "$(da "$P/stub-meldung")" "fehlt"
pruef "   ... kein sync-stand"                    "$(da "$P/.claude-mind/rescued/sync-stand")" "fehlt"
pruef "   ... OPEN bleibt"                        "$(da "$P/.claude-mind/rescued/OPEN")" "da"
abschluss "$P"
pruef "⛔ Aufruf 2: Pass 2 (nicht wieder 1)"      "$(cat "$P/.claude-mind/reparatur-pass-L1-abc" 2>/dev/null)" "2"
pruef "⛔ nach Pass 2 geht die Meldung hinaus"     "$(da "$P/stub-meldung")" "da"
pruef "Schlusszeile nennt teil"                   "$(grep -c 'ABSCHLUSS: SYNC_LIEF=teil' "$P/aus.txt")" "1"

echo "=== 3) danach voll: Merker geschrieben, Zaehler weg ==="
echo voll > "$P/stub-voll"
abschluss "$P"
pruef "sync-stand geschrieben"                    "$(da "$P/.claude-mind/rescued/sync-stand")" "da"
pruef "Reparatur-Zaehler entfernt"                "$(da "$P/.claude-mind/reparatur-pass-L1-abc")" "fehlt"
pruef "OPEN getilgt"                              "$(da "$P/.claude-mind/rescued/OPEN")" "fehlt"

echo "=== 4) 2.95: der Befund kommt an, ein fehlender Abschnitt bricht ab ==="
L="$ST/skills/mind-all/bloecke/step2.95-liste.sh"
P="$TMP/f4 mit leer"; mkdir -p "$P/.claude-mind" "$TMP/dbg"
( cd "$P" && CLAUDE_PLUGIN_ROOT="$ST" MIND_LOG_FILE="$TMP/log" bash "$L" Handaufruf > "$P/aus.txt" 2>&1 ); RC=$?
pruef "ohne Abschnitt: rc 1"                      "$RC" "1"
pruef "   ... und sagt es"                        "$(grep -c 'fehlt oder ist leer' "$P/aus.txt")" "1"
printf '## Lauf\n\n### Probleme in diesem Lauf\n- (keine)\n' > "$P/.claude-mind/lauf-abschnitt.md"
printf '{"ts":"2026-10-29 19:00","projekt":"x","klasse":"sonstiges","kurz":"Prueffall-Befund","lauf":"L1"}\n' \
  > "$P/.claude-mind/lauf-befunde.jsonl"
( cd "$P" && CLAUDE_PLUGIN_ROOT="$ST" MIND_LOG_FILE="$TMP/log" MIND_DEBUG_DIR="$TMP/dbg" bash "$L" Handaufruf > "$P/aus.txt" 2>&1 ); RC=$?
pruef "mit Abschnitt: rc 0"                       "$RC" "0"
pruef "Abschnitt in listeverbesserungen.md"       "$(grep -c '^## Lauf' "$P/listeverbesserungen.md" 2>/dev/null)" "1"
pruef "⛔ der Befund steht im Debug-Ordner (wurde bis 5.151.0 vorher geleert)" \
  "$(grep -rl 'Prueffall-Befund' "$TMP/dbg" 2>/dev/null | wc -l | tr -d ' ' | sed 's/^[1-9][0-9]*$/ja/')" "ja"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
