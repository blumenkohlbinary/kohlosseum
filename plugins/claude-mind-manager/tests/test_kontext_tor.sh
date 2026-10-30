#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # v5.114.0: Fixtures unter einem Pfad MIT Leerzeichen
# KONTEXT-TOR (v5.26.0) — seit v5.158.0 die Pruefliste A1–D10 (A2->R1, A3->B5, C1->C7, C2->C7b).
#
# ⛔ DER ANLASS, woertlich vom Nutzer am 30.08.2026:
#    "ueberall es wird immer mehr es darf nicht sein — fuehre was ein wo der
#     Context durch laeuft: ist es irgendwo schon, ist es selbsterklaerend,
#     ist es im Code schon erklaert."
#    Das Plugin arbeitete bis dahin nur RUECKWAERTS. Es gab kein Tor beim
#    HINEINschreiben — deshalb waechst alles.
#
# ⭐ FALL 4 IST DER WICHTIGSTE DER GANZEN SAMMLUNG, und er steht gegen den
#    Auftrag. "Alle Regeln hart formuliert, keine Ausnahmen" darf die
#    ⚠-VORBEHALTE nicht fressen: `⚠ Beide Schwellen sind GERATEN, nicht
#    gemessen` ist keine weiche Regel, sondern eine HARTE Aussage ueber einen
#    SCHWACHEN Beleg — und genau das unterscheidet diesen Bestand von einer
#    Sammlung Behauptungen. Ein Detektor, der sie meldet, macht ihn schlechter.
#
# ⭐ FALL 8 IST DIE LEHRE AUS DEM BAU und haette zweimal Stunden gekostet:
#    `sys.stdout = io.TextIOWrapper(...)` am Modulkopf war BEDINGUNGSLOS. Wer
#    stdout selbst einhuellt und dann importiert, haengt ZWEI Wrapper an
#    denselben Puffer; einer wird eingesammelt, schliesst den Puffer, und jedes
#    weitere print() bricht — NACH der letzten erfolgreichen Ausgabe, also an
#    der falschen Stelle. Zweimal am 30.08.2026 gemessen.
#
# ⛔ WAS DIESE SAMMLUNG NICHT PRUEFT: ob eine Antwort RICHTIG ist. A1 und C2
#    sind Bedeutungsfragen. Das Tor erzwingt eine Antwort, nicht die richtige —
#    dieselbe Ehrlichkeit wie bei der Agent-Quittung (v5.19.0).
#
# Aufruf:  CLAUDE_PLUGIN_ROOT=<paket> bash tests/test_kontext_tor.sh
set -u
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
TOR="$CLAUDE_PLUGIN_ROOT/references/cleaner_tor.py"
[ -f "$TOR" ] || { echo "fehlt: $TOR" >&2; exit 2; }
command -v cygpath >/dev/null 2>&1 && W=cygpath || W=echo
w() { if [ "$W" = cygpath ]; then cygpath -w "$1"; else echo "$1"; fi; }
TORW="$(w "$TOR")"

OK=0; ROT=0
janein() { if [ "$2" = "$3" ]; then echo "  [ok ] $1"; OK=$((OK+1))
           else echo "  [ROT] $1 — erwartet '$2', bekommen '$3'"; ROT=$((ROT+1)); fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# zaehlt die Treffer einer Frage in einem Dateilauf
n_von() { python "$TORW" --datei "$(w "$1")" 2>/dev/null \
          | grep -E "^  $2 " | awk '{print $2}'; }

echo "== 1/8  Selbsttest =="
janein "Selbsttest gruen" "0" "$(python "$TORW" --selbsttest >/dev/null 2>&1; echo $?)"
janein "ohne Argument -> Aufruffehler (rc 2)" "2" \
       "$(python "$TORW" >/dev/null 2>&1; echo $?)"
janein "--datei auf Nichtvorhandenes -> rc 2" "2" \
       "$(python "$TORW" --datei "$TMP/gibtsnicht.md" >/dev/null 2>&1; echo $?)"

echo "== 2/8  A1 Allgemeinwissen — Positiv UND Negativ =="
printf 'Python ist eine Programmiersprache.\n' > "$TMP/a1p.md"
printf '`jq` ist ein Werkzeug fuer JSON.\n'    > "$TMP/a1n.md"
janein "positiv: Definition ohne Projektmarke" "1" "$(n_von "$TMP/a1p.md" A1)"
janein "negativ: Definition MIT Code-Marke bleibt" "0" "$(n_von "$TMP/a1n.md" A1)"

echo "== 3/8  A2 Bestandszahl ohne Zaehlbefehl =="
printf 'Das Plugin hat 5 Hooks.\n' > "$TMP/a2p.md"
printf 'Das Plugin hat 5 Hooks, gemessen 27.08.2026.\n' > "$TMP/a2n.md"
janein "positiv: Zahl ohne Beleg" "1" "$(n_von "$TMP/a2p.md" R1)"
janein "negativ: dieselbe Zahl MIT Beleg" "0" "$(n_von "$TMP/a2n.md" R1)"

echo "== 4/8  ⭐ C1 hart formulieren — OHNE die Vorbehalte zu fressen =="
printf 'Man sollte vorher sichern.\n' > "$TMP/c1p.md"
janein "positiv: weiches Gebot wird gemeldet" "1" "$(n_von "$TMP/c1p.md" C7)"
# ⛔ DIE ZUSICHERUNG, DIE GEGEN DEN AUFTRAG STEHT.
printf '⚠ Beide Schwellen sind geraten, man kann sie korrigieren.\n' > "$TMP/c1v.md"
janein "⭐ EVIDENZ-VORBEHALT wird NIE gemeldet" "0" "$(n_von "$TMP/c1v.md" C7)"
printf 'Der Betrag ist nicht gemessen, man kann ihn nur schaetzen.\n' > "$TMP/c1v2.md"
janein "⭐ 'nicht gemessen' wird NIE gemeldet" "0" "$(n_von "$TMP/c1v2.md" C7)"
# ⛔ ⛔ befreit NICHT — der gemischte Fall gehoert gehaertet.
printf '⛔ Moeglichst nicht loeschen.\n' > "$TMP/c1m.md"
janein "⛔ befreit NICHT: gemischter Fall wird gemeldet" "1" "$(n_von "$TMP/c1m.md" C7)"
# ⭐ NEBENSATZ ist keine Regel — sonst waren beide echten Treffer Fehlalarme.
printf 'Er lieferte den Befund, den der Agent finden sollte.\n' > "$TMP/c1nb.md"
janein "⭐ Nebensatz (Modalverb am Ende) ist keine Regel" "0" "$(n_von "$TMP/c1nb.md" C7)"

echo "== 5/8  A3 Historie, C2 unspezifisch =="
printf 'Hier stand bis 27.08. eine andere Zahl.\n' > "$TMP/a3p.md"
printf 'Bis v5.20.2 stand hier NIE kuerzen — das gilt nicht mehr.\n' > "$TMP/a3n.md"
janein "A3 positiv: Rueckblick" "1" "$(n_von "$TMP/a3p.md" B5)"
janein "A3 negativ: Rueckblick MIT geltendem Gebot bleibt" "0" "$(n_von "$TMP/a3n.md" B5)"
printf 'NIE unvorsichtig sein.\n' > "$TMP/c2p.md"
printf 'NIE mit Edit auf Z:/daten schreiben.\n' > "$TMP/c2n.md"
janein "C2 positiv: Gebot ohne Handlung" "1" "$(n_von "$TMP/c2p.md" C7b)"
janein "C2 negativ: Gebot MIT Pfad" "0" "$(n_von "$TMP/c2n.md" C7b)"

echo "== 6/8  Fences und Tabellen zaehlen nicht =="
{ printf 'Python ist eine Programmiersprache.\n'
  printf '```\nBash ist eine Shell.\n```\n'
  printf '| Ruby ist eine Sprache | x |\n'; } > "$TMP/fence.md"
janein "nur die freie Zeile zaehlt" "1" "$(n_von "$TMP/fence.md" A1)"

echo "== 7/8  Memory-Deckel — Ampel gegen die GRENZE 5, nicht gegen Ladungen =="
mk_mem() { d="$TMP/mem$1"; mkdir -p "$d"; i=0
  while [ $i -lt "$1" ]; do i=$((i+1))
    printf -- '---\nname: t%d\ndescription: "%s"\nmetadata:\n  type: project\n---\n\nInhalt.\n' \
      "$i" "Eine ausreichend lange Beschreibung, die klar sagt worum es geht $i" \
      > "$d/t$i.md"
  done; echo "$d"; }
D5="$(mk_mem 5)";  D30="$(mk_mem 30)"
janein "5 Dateien -> gruen (rc 0)" "0" \
       "$(python "$TORW" --memory "$(w "$D5")" >/dev/null 2>&1; echo $?)"
janein "30 Dateien -> ROT (rc 1)" "1" \
       "$(python "$TORW" --memory "$(w "$D30")" >/dev/null 2>&1; echo $?)"
# ⛔ Die AMPELZEILE, nicht das Wort. Erste Fassung zaehlte Vorkommen von "ROT"
#    und erwartete 1 — der Bericht nennt es aber zweimal (Ampel + Handlungs-
#    anweisung). Die Zahl war nie die Aussage; gemeint ist "die Ampel steht auf
#    ROT". Dieselbe Umstellung wie bei test_leitplanke.sh (v5.25.0): auf die
#    Form, die die Aussage traegt, statt auf einen Zaehler.
janein "30 Dateien: die AMPEL steht auf ROT" "1" \
       "$(python "$TORW" --memory "$(w "$D30")" 2>/dev/null \
          | grep -cE '^  30 Topic-Dateien +-> +ROT')"
janein "Regler wirkt: MAX_GELB=40 macht 30 zu gelb" "0" \
       "$(MIND_MEMORY_MAX_GRUEN=35 MIND_MEMORY_MAX_GELB=40 \
          python "$TORW" --memory "$(w "$D30")" >/dev/null 2>&1; echo $?)"
# schwache description wird gemeldet — der WIRKSAMERE Hebel
printf -- '---\nname: kurz\ndescription: "zu kurz"\n---\n\nx\n' > "$D5/kurz.md"
janein "zu kurze description wird gemeldet" "1" \
       "$(python "$TORW" --memory "$(w "$D5")" 2>/dev/null | grep -c 'zu kurz')"
janein "--memory auf Nichtvorhandenes -> rc 2" "2" \
       "$(python "$TORW" --memory "$TMP/gibtsnicht" >/dev/null 2>&1; echo $?)"

echo "== 8/8  ⭐ stdout-Regression + verweist statt nachzubauen + schreibt nichts =="
# ⭐ Der Fehler, der zweimal zuschlug: aufrufendes Skript huellt stdout ein,
#    importiert dann das Modul -> zwei Wrapper, ein Puffer, Absturz.
cat > "$TMP/wrap.py" <<'PYEOF'
import io, sys, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
sys.path.insert(0, os.environ["REFS"])
import cleaner_tor
print("ueberlebt")
PYEOF
janein "⭐ Import nach eigener stdout-Umhuellung stuerzt NICHT ab" "ueberlebt" \
       "$(REFS="$(w "$CLAUDE_PLUGIN_ROOT/references")" \
          python "$(w "$TMP/wrap.py")" 2>/dev/null | tail -1)"
echo "== v5.158.0: Pruefliste A1–D10 und zeilenweise =="
printf 'Python ist eine Programmiersprache.\nMan sollte vorher sichern.\n' > "$TMP/zw.md"
_ZW=$(python "$TORW" --datei "$(w "$TMP/zw.md")" 2>/dev/null)
janein "die Ausgabe hat einen Abschnitt je Zeile" "1" "$(printf '%s' "$_ZW" | grep -c '── je Zeile')"
janein "  ... Z1 traegt A1, Z2 traegt C7" "2" "$(printf '%s' "$_ZW" | grep -cE '^  Z(1 +A1|2 +C7) ')"
for k in A2 A3 B4 B6 C8 C9 D10 W1; do
  janein "  Frage $k wird als Urteil/Zeiger genannt" "1" "$(printf '%s' "$_ZW" | grep -cE "^  ▸ $k ")"
done
_Q=$(python "$TORW" --text "Man sollte vorher sichern." 2>/dev/null)
janein "W1 (Wohin) steht in der Liste (v5.172.0)" "1" "$(grep -c '^| \*\*W1\*\* | Wohin gehoert es?' "$CLAUDE_PLUGIN_ROOT/references/kontext-tor.md")"
janein "   ... und alle fuenf Skills haengen :W1= an die Quittung" "5" "$(grep -l ':D10:D1=<bremse>/<anleitung>/<beleg>/<unbestimmt>:W1=' "$CLAUDE_PLUGIN_ROOT"/skills/mind-{claudemd,files,memory,rules,update}/SKILL.md | wc -l | tr -d ' ')"
janein "die Quittung traegt die neuen Kuerzel" "1" "$(printf '%s' "$_Q" | grep -c 'tor=<datei>:A1/A2/A3:B4/B5/B6:C7/C8/C9:D10')"

# A1 (Code, andere Datei), B4, C8, D10 werden NICHT nachgebaut — sie werden GENANNT (werkzeuge-zuerst.md)
janein "verweist auf cleaner_duplikate statt es nachzubauen" "1" \
       "$(python "$TORW" --datei "$(w "$TMP/a1p.md")" 2>/dev/null \
          | grep -c 'cleaner_duplikate.py --bereich')"   # v5.158.0: C8 nennt es zusaetzlich mit --widersprueche
janein "verweist auf cleaner_grenzen" "1" \
       "$(python "$TORW" --datei "$(w "$TMP/a1p.md")" 2>/dev/null \
          | grep -c 'cleaner_grenzen.py')"
# ⛔ Es schreibt NICHTS — dieselbe Zusicherung wie v0_schreibt_nichts.py
VOR="$(find "$TMP" -type f | sort | xargs md5sum 2>/dev/null | md5sum)"
python "$TORW" --datei "$(w "$TMP/a1p.md")" >/dev/null 2>&1
python "$TORW" --memory "$(w "$D5")"        >/dev/null 2>&1
NACH="$(find "$TMP" -type f | sort | xargs md5sum 2>/dev/null | md5sum)"
janein "⛔ schreibt NICHTS auf die Platte" "$VOR" "$NACH"

echo
echo "  $OK gruen, $ROT rot"
[ "$ROT" -eq 0 ] || exit 1
exit 0
