#!/usr/bin/env bash
# COMPACT-FAELLIG ist ENTFALLEN (v5.65.0) — diese Sammlung haelt fest, dass er
# WEG ist und wo seine Zusicherungen geblieben sind.
#
# ⛔ NUTZER-ENTSCHEIDUNG 10.09.2026, woertlich: "die sollen garnicht mehr tokens
#    messen das soll komplett raus ea nervt ihr seit zu bloed zum messrn".
#    Der Merker entstand AUSSCHLIESSLICH token-getriggert (`mind-all` 2.96a,
#    `[ "$_MTOK" -ge "$_MSCHW" ]`) — nachgesehen, nicht geglaubt: es gab keinen
#    zweiten Entstehungsweg. Mit der Token-Messung faellt er mit.
#
# ⚠ DER PREIS STEHT IM CODE UND HIER: dies war das EINZIGE, was je um eine
#   Kompaktierung gebeten hat. Ab jetzt bittet niemand. Folgenlos, solange die
#   Auto-Kompaktierung scharf ist (`env-vars.md`: seit 23.08.2026, drei
#   Messwerte bei ~966 000 aus zwei Projekten). Waere sie aus, feuert
#   `pre-compact.sh` nie — dann gibt es keine Chat-Rettung, kein RESUME,
#   keinen Arbeitsstand.
#
# ⛔ WO DIE ZUSICHERUNGEN GEBLIEBEN SIND — keine faellt still weg
#    (`autonom-arbeiten.md`: verliert ein Prueffall sein ZIEL, ist das eine
#    LUECKE, bis die Zusicherung anderswo steht):
#
#    | war (v5.7.5 – v5.64.0)              | ist                               |
#    |-------------------------------------|-----------------------------------|
#    | Merker da -> Meldung nennt /compact | ⛔ gegenstandslos — Abschnitt 1+2  |
#    |                                     |   sichern zu, dass es ihn nicht   |
#    |                                     |   mehr gibt.                      |
#    | kein Zaehler, kein Notausgang       | ⛔ gegenstandslos seit v5.55.0.    |
#    | stop.sh blockt NICHT                | ⭐ BLEIBT — Abschnitt 4, als       |
#    |                                     |   Rueckbau-Sperre.                |
#    | pre-compact verbraucht den Merker   | ⭐ umgekehrt — Abschnitt 5: er     |
#    |                                     |   fasst ihn nicht mehr an und      |
#    |                                     |   rettet trotzdem alles.          |
#    | v5.50.0: liegt ZUGLEICH eine        | ⭐ Abschnitt 3. Sie existierte,    |
#    | Sync-Schuld, muss sie MIT in die    |   weil dieser Block mit `exit 0`  |
#    | COMPACT-Meldung                     |   ausstieg und die Schuld-Meldung |
#    |                                     |   150 Zeilen tiefer NIE erreicht  |
#    |                                     |   wurde. Jetzt gibt es nur noch   |
#    |                                     |   EINEN Weg — und der traegt sie. |
#    | "nur der Mensch loest /compact aus" | ⭐ Abschnitt 6: der Satz stand nur |
#    |                                     |   im Meldungstext und waere sonst |
#    |                                     |   ersatzlos verschwunden. Er ist  |
#    |                                     |   in `mind-all` Step 2.96b.       |
#
# ⭐ GEGENPROBE GEGEN DEN ALTEN STAND ist Pflicht, sonst ist gruen nur
#    Schweigen. Abschnitt 1, 2 und 5 sind gegen v5.64.0 ROT:
#      CLAUDE_PLUGIN_ROOT=<alter-stand> bash tests/test_compact_faellig.sh
#
# Aufruf:  CLAUDE_PLUGIN_ROOT=<paket> bash tests/test_compact_faellig.sh
set -u
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { echo "CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 2; }
H="$CLAUDE_PLUGIN_ROOT/hooks"
MA="$CLAUDE_PLUGIN_ROOT/skills/mind-all/SKILL.md"
OK=0; ROT=0

janein() { # name erwartung(ja|nein) ist(ja|nein)
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; OK=$((OK+1))
  else echo "  [ROT] $1 — erwartet '$2', bekommen '$3'"; ROT=$((ROT+1)); fi
}

neu_projekt() { local d; d=$(mktemp -d); mkdir -p "$d/.claude-mind/rescued"; printf '%s' "$d"; }

# Eine ALTLAST aus v5.64.0: die Datei liegt noch, niemand liest sie mehr.
altlast() { printf 'ts=2026-09-10 12:00:00\ntokens=772345\n' \
  > "$1/.claude-mind/rescued/COMPACT-FAELLIG"; }

prompt_lauf() { # projekt
  printf '{"session_id":"s","transcript_path":"","prompt":"hi","cwd":"%s"}' "$1" \
    | CLAUDE_PROJECT_DIR="$1" bash "$H/prompt-submit.sh" 2>/dev/null
}
stop_lauf() { # projekt
  printf '{"session_id":"s","transcript_path":"","stop_hook_active":false,"cwd":"%s"}' "$1" \
    | CLAUDE_PROJECT_DIR="$1" bash "$H/stop.sh" 2>/dev/null
}

echo "=== 1) ⛔ Der Merker wird nicht mehr ANGELEGT ==="
# ⛔ Gezaehlt wird die SCHREIBFORM (Umleitung auf den Pfad), nicht die Nennung.
#   Ein Kommentar, der sagt "hier stand die Erzeugung", ist keine Erzeugung.
#   Dieselbe Verwechslung ist in diesem Projekt viermal aufgetreten.
janein "mind-all legt COMPACT-FAELLIG nicht mehr an" "0" \
  "$(grep -c '> "\$PROJ/.claude-mind/rescued/COMPACT-FAELLIG"' "$MA")"
# ⛔ ZWEI PUNKTE, NICHT DREI. Die erste Fassung schrieb `ts=%s..ntokens=` und
#   verlangte damit `\n` PLUS ein weiteres `n` — sie konnte nie treffen und war
#   ein FALSCHES GRUEN. Aufgefallen nur, weil der Nachbarfall mit demselben
#   Fehler rot wurde: dort war die Erwartung "ja". Klasse
#   `instrument-misst-nichts`, im eigenen Prueffall.
janein "mind-all schreibt kein tokens= mehr in sync-stand" "0" \
  "$(grep -cE "^ *printf 'ts=%s..tokens=" "$MA")"
# ⭐ POSITIVKONTROLLE: die Datei muss es geben und sie muss den Merker, den es
#   noch gibt, weiterhin schreiben. Sonst waere die Sammlung gruen, weil sie
#   ins Leere liest.
janein "⭐ mind-all schreibt sync-stand weiterhin" "ja" \
  "$([ "$(grep -c 'rescued/sync-stand"' "$MA")" -ge 1 ] && echo ja || echo nein)"
janein "⭐ und zwar mit umfang= und ungepruef=" "ja" \
  "$(grep -qE "umfang=%s..ungepruef=" "$MA" && echo ja || echo nein)"

echo
echo "=== 2) ⛔ Der Merker wird nicht mehr GELESEN ==="
janein "prompt-submit.sh liest COMPACT-FAELLIG nicht mehr" "0" \
  "$(grep -c '_CFA=' "$H/prompt-submit.sh")"
janein "prompt-submit.sh misst keine Tokens mehr" "0" \
  "$(grep -c 'mind_kontext_tokens "' "$H/prompt-submit.sh")"

echo
echo "=== 3) ⭐ Die ZUSICHERUNG aus v5.50.0 — jetzt auf dem einzigen Weg ==="
# Eine Altlast-Datei darf nichts mehr bewirken; gemeldet wird die SCHULD, und
# die Meldung traegt Grund und ungepruefte Bereiche.
P=$(neu_projekt); altlast "$P"
printf 'path=%s/x_chat.md\ngrund=teilsync\nungepruef=memory,rules\n' "$P" \
  > "$P/.claude-mind/rescued/OPEN"
printf 'x\n' > "$P/x_chat.md"
O=$(prompt_lauf "$P")
printf '%s' "$O" | grep -q 'Mind Manager' && A=ja || A=nein
janein "es wird ueberhaupt gemeldet" ja "$A"
printf '%s' "$O" | grep -qi 'teilsync' && A=ja || A=nein
janein "⭐ der GRUND steht in der Meldung" ja "$A"
printf '%s' "$O" | grep -q 'memory,rules' && A=ja || A=nein
janein "⭐ die UNGEPRUEFTEN Bereiche stehen darin" ja "$A"
printf '%s' "$O" | grep -qi 'Kompaktierung steht aus' && A=ja || A=nein
janein "⛔ und NICHT mehr die Kompaktierungs-Bitte" nein "$A"
rm -rf "$P"

echo
echo "=== 4) ⛔ stop.sh blockt niemanden — Rueckbau-Sperre ==="
P=$(neu_projekt); altlast "$P"
S=$(stop_lauf "$P")
printf '%s' "$S" | grep -q '"decision"' && A=ja || A=nein
janein "stop.sh blockt NICHT" nein "$A"
janein "stop.sh gibt gar kein JSON aus" "0" "$(grep -c 'jq -nc' "$H/stop.sh")"
rm -rf "$P"

echo
echo "=== 5) ⭐ pre-compact.sh fasst den Merker nicht mehr an ==="
# ⛔ Die Umkehrung des alten Falls 11. Wichtig, weil ein Aufraeumer fuer eine
#   Datei, die niemand anlegt, eine Spur waere, die einen Merker behauptet.
janein "pre-compact loescht COMPACT-FAELLIG nicht mehr" "0" \
  "$(grep -c 'rm -f "\$RESCUE_DIR/COMPACT-FAELLIG"' "$H/pre-compact.sh")"
# ⭐ POSITIVKONTROLLE: er rettet trotzdem. Ohne sie waere "0" auch dann gruen,
#   wenn der ganze Hook kaputt ist.
janein "⭐ pre-compact rettet weiterhin den Chat" "ja" \
  "$(grep -q '_chat.md' "$H/pre-compact.sh" && echo ja || echo nein)"
janein "⭐ und legt weiterhin UEBERGABE an" "ja" \
  "$(grep -q 'UEBERGABE' "$H/pre-compact.sh" && echo ja || echo nein)"

echo
echo "=== 6) ⭐ Die WAHRHEIT, die nur im geloeschten Text stand ==="
# ⛔ "Eine Kompaktierung kann niemand ausloesen ausser dem Menschen" stand
#   AUSSCHLIESSLICH im Meldungstext von COMPACT-FAELLIG. Ohne diesen Umzug
#   waere sie ersatzlos verschwunden — und der naechste Lauf versucht es
#   selbst und meldet danach faelschlich Erfolg.
janein "mind-all sagt: nicht ausloesbar" "ja" \
  "$(grep -qi 'nicht ausloesbar' "$MA" && echo ja || echo nein)"
janein "mind-all sagt: nur der Mensch" "ja" \
  "$(grep -qi 'Nur der Mensch tippt sie\|nur der Mensch' "$MA" && echo ja || echo nein)"
janein "⛔ und NICHT 'kommt von selbst'" "ja" \
  "$(grep -q 'nicht.*umformulieren zu' "$MA" && echo ja || echo nein)"

echo
echo "  $OK gruen · $ROT rot"
[ "$ROT" -eq 0 ]
