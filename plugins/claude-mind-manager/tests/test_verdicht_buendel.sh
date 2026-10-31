#!/usr/bin/env bash
. "$(dirname "$0")/lib_test.sh"   # Fixtures unter einem Pfad MIT Leerzeichen
# VERDICHTEN als Buendel — `mind_verdicht_start` / `mind_verdicht_ende` (Etappe 68).
#
# ⛔ WOZU. Ritas /mind-all-Lauf (30.10.2026): VERDICHTEN kostete je Skill 5-7 Schritte der steuernden
#    Sitzung (bestands-pass.md von Hand lesen, Snapshot/Bilanz tippen, Auftrag formulieren, pruefen -
#    teils 3x -, anwenden, merken, Bilanz, Quittung). Jeder Schritt kostet den ganzen Verlauf (~280k).
#    Ziel: nach dem Kandidaten-Block hoechstens DREI Schritte — Agent · ende pruefen · ende anwenden.
#
# ⛔ GEGEN DEN ALTEN STAND ROT: vor v5.175 gibt es weder `mind_verdicht_start` noch `mind_verdicht_ende`
#    (Funktion fehlt -> jeder Aufruf scheitert) und keiner der fuenf Kandidaten-Bloecke kennt das Argument
#    `ende`. Die Sammlung ist dort nur rot — das ist ihr Sinn; sie prueft nicht das Verhalten von frueher.
# ⭐ Die Fixtures bilden den Agenten nach, indem sie `.nachher.md`/`.bericht.md` SELBST schreiben — der
#    Agent ist kein Teil dieser Pruefung, sein Vertrag (zwei Dateien) ist es.
set -u
R="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$R"
ok=0; rot=0
pruef() {   # <text> <ist> <soll>
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export MIND_LOG_FILE="$TMP/log"
# Funktionen laufen in einer Subshell wie in einem Block: eigener Prozess, nur Dateien ueberleben
L() { ( source "$R/hooks/lib.sh"; "$@" ); }
tropfen() { sed -n 's/.*"status":"\([^"]*\)".*/\1/p' "$1/.claude-mind/schritt-quittung.jsonl" 2>/dev/null | tail -1; }

# ---- Fixture: ein Projekt mit einer Rule, ein Deckel-Ausweis nennt einen Ueberholt-Kandidaten ----
bauen() {   # bauen <name> [crlf]  -> setzt P, X
  P="$TMP/projekt $1"; X="$P/.claude/rules/x.md"
  mkdir -p "$P/.claude-mind" "$P/.claude/rules" "$P/.claude/archiv"
  cat > "$X" <<'EOF'
# Regel x

⛔ NIE ohne Sicherung loeschen. Das ist am 21.08.2026 gemessen worden, als von sieben
Snapshots die alte Rotation null loeschte und die Sicherungen 32 MB gross wurden.

⚠ Die Rotation haelt nur drei Staende. Wer mehr will, setzt die Variable, aber nicht ohne Grund.

⭐ Der Aufruf ist `tools/rollback.py list`, und er zeigt beide Ablagen, die es gibt.

Ein erklaerender Satz ganz ohne Marke, der nur sagt, warum das alles so ist und wie es dazu kam,
dass dieser Absatz so lang geworden ist, obwohl er laengst in zwei Saetzen gesagt waere.

⛔ Deckel-Ausweis (03.10.2026): GETILGT 28.10.2026, Wortlaut in der Git-Historie dieser Datei.
EOF
  [ "${2:-}" = crlf ] && sed -i 's/$/\r/' "$X"
}
gut() {   # gut <Datei>  — der "Agent": kuerzt den Erklaersatz, behaelt alle Marken, benennt den Deckel-Ausweis
  cp "$X" "$1"
  python - "$1" <<'EOF'
import sys
p=sys.argv[1]; b=open(p,'rb').read(); n='\r\n' if b'\r\n' in b else '\n'
t=b.decode('utf-8').replace('\r\n','\n').split('\n')
out=[]
for z in t:
    if z.startswith('Ein erklaerender Satz'): out.append('Kurz: so kam es dazu.'); continue
    if z.startswith('dass dieser Absatz'): continue
    if z.startswith('⛔ Deckel-Ausweis'): out.append('Deckel-Ausweis (03.10.2026): GETILGT 28.10.2026, Archiv.'); continue
    out.append(z)
open(p,'wb').write(n.join(out).encode('utf-8'))
EOF
}
bericht() { printf 'entfernt: \xe2\x9b\x94 \xe2\x80\x9e\xe2\x9b\x94 Deckel-Ausweis (03.10.2026): GETILGT 28.10.2026, Wortlaut in der Git-Historie dieser Datei.\xe2\x80\x9c\n' > "$1"; }

echo "=== 1) start: Snapshot, Stand, Auftrag WOERTLICH, naechster Aufruf ==="
bauen eins
printf 'unantastbar: „Das ist am 21.08.2026 gemessen worden"\n' > "$P/.claude/archiv/x.stufe3.md"
OUT=$(cd "$P" && L mind_verdicht_start "$P" mind-rules "$X" 2>&1); RC=$?
pruef "start rc 0" "$RC" "0"
pruef "Snapshot pre-verdichten angelegt" "$(ls -d "$P/.claude-mind/snapshots/"*_pre-verdichten 2>/dev/null | wc -l | tr -d ' ')" "1"
ST="$P/.claude-mind/verdichten-mind-rules.stand"
pruef "Stand-Datei da" "$([ -f "$ST" ] && echo ja || echo nein)" "ja"
pruef "Stand traegt datei=" "$(sed -n 's/^datei=//p' "$ST")" "$X"
pruef "Stand traegt vorher=<Zahl>" "$(sed -n 's/^vorher=\([0-9][0-9]*\)$/ja/p' "$ST")" "ja"
pruef "Auftrag nennt die Datei" "$(printf '%s' "$OUT" | grep -cF "DATEI: $X")" "1"
pruef "Auftrag nennt ERGEBNIS-Pfad" "$(printf '%s' "$OUT" | grep -cF "verdichten-mind-rules.nachher.md")" "1"
pruef "Auftrag nennt BERICHT-Pfad" "$(printf '%s' "$OUT" | grep -cF "verdichten-mind-rules.bericht.md")" "1"
pruef "Auftrag: ALLCAPS-Verbote-Regel aus dem Kasten" "$(printf '%s' "$OUT" | grep -c 'ALLCAPS-Verbote')" "1"
pruef "Auftrag: 'keine eigenen Agenten'" "$(printf '%s' "$OUT" | grep -c 'KEINE eigenen Agenten')" "1"
pruef "Auftrag traegt den benannten Kandidaten (GETILGT-Zeile)" "$(printf '%s' "$OUT" | grep -c 'GETILGT 28.10.2026')" "1"
pruef "Auftrag traegt die Stufe-3-Zeile als NICHT anfassen" "$(printf '%s' "$OUT" | grep -c 'NICHT anfassen, byteweise erhalten: „Das ist am 21.08.2026')" "1"
pruef "naechster Aufruf woertlich: ende pruefen" "$(printf '%s' "$OUT" | grep -c 'ende pruefen')" "1"

echo "=== 2) ende pruefen mit GUTEM Ergebnis: gruen, Wortdiff GANZ auf stdout, naechster Aufruf ==="
gut "$P/.claude-mind/verdichten-mind-rules.nachher.md"; bericht "$P/.claude-mind/verdichten-mind-rules.bericht.md"
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-rules pruefen 2>&1); RC=$?
pruef "pruefen rc 0" "$RC" "0"
pruef "Wortdiff steht in der Ausgabe" "$(printf '%s' "$OUT" | grep -c -- '----- WORTDIFF -----')" "1"
pruef "Wortdiff traegt die Aenderung ([-...-]{+...+})" "$(printf '%s' "$OUT" | grep -c '{+Kurz:+}')" "1"
pruef "Wortdiff-Datei mit Zeitstempel im Namen" "$(ls "$P/.claude-mind/"verdichten-mind-rules.wortdiff.[0-9]*-[0-9]*.txt 2>/dev/null | wc -l | tr -d ' ')" "1"
pruef "naechster Aufruf woertlich: ende anwenden" "$(printf '%s' "$OUT" | grep -c 'ende anwenden')" "1"
pruef "die Datei ist NOCH unveraendert (pruefen schreibt nichts)" "$(cmp -s "$X" "$P/.claude-mind/verdichten-mind-rules.vorher.md" && echo ja || echo nein)" "ja"
pruef "Deponat traegt den Vorher-Fingerabdruck" "$(grep -c 'Vorher-Fassung  md5 ' "$P/.claude-mind/verdichten-mind-rules.txt")" "1"

echo "=== 3) ende anwenden: byteweise cp, Bilanz, Merker, Quittung gelaufen ==="
VOR=$(wc -c < "$X" | tr -d ' ')
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-rules anwenden 2>&1); RC=$?
pruef "anwenden rc 0" "$RC" "0"
pruef "Datei == Ergebnis (byteweise)" "$(cmp -s "$X" "$P/.claude-mind/verdichten-mind-rules.nachher.md" && echo ja || echo nein)" "ja"
pruef "Datei ist kleiner" "$([ "$(wc -c < "$X" | tr -d ' ')" -lt "$VOR" ] && echo ja || echo nein)" "ja"
pruef "Bericht-Zeile Dauerkontext vorher -> nachher" "$(printf '%s' "$OUT" | grep -c 'Dauerkontext  [0-9]* -> [0-9]* B')" "1"
pruef "Quittung: gelaufen" "$(tropfen "$P")" "gelaufen"
pruef "Quittung traegt das Artefakt (quelle datei, Pfad)" "$(grep '"name":"verdichten"' "$P/.claude-mind/schritt-quittung.jsonl" | tail -1 | grep -c '"quelle":"datei".*verdichten-mind-rules.txt')" "1"
pruef "verdichtet= im Kettenmerker" "$(grep -cxF "verdichtet=$X" "$P/.claude-mind/analyzed-scopes" 2>/dev/null)" "1"
pruef "Historie traegt die nach-Zeile" "$(grep -c '^nach ' "$P/.claude-mind/verdichten-historie" 2>/dev/null)" "1"

echo "=== 4) ende anwenden OHNE gruene Pruefung dieses Ergebnisses: rc 3, kein cp ==="
bauen vier; cd "$P" && L mind_verdicht_start "$P" mind-rules "$X" >/dev/null 2>&1
gut "$P/.claude-mind/verdichten-mind-rules.nachher.md"
ALT=$(wc -c < "$X" | tr -d ' ')
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-rules anwenden 2>&1); RC=$?
pruef "anwenden ohne pruefen: rc 3" "$RC" "3"
pruef "Datei unveraendert" "$(wc -c < "$X" | tr -d ' ')" "$ALT"
# pruefen, dann das Ergebnis AENDERN, dann anwenden: Fingerabdruck stimmt nicht mehr
bericht "$P/.claude-mind/verdichten-mind-rules.bericht.md"
(cd "$P" && L mind_verdicht_ende "$P" mind-rules pruefen >/dev/null 2>&1)
printf 'zusaetzlich\n' >> "$P/.claude-mind/verdichten-mind-rules.nachher.md"
(cd "$P" && L mind_verdicht_ende "$P" mind-rules anwenden >/dev/null 2>&1); RC=$?
pruef "Ergebnis nach der Pruefung geaendert: rc 3" "$RC" "3"
pruef "Datei weiter unveraendert" "$(wc -c < "$X" | tr -d ' ')" "$ALT"

echo "=== 5) SCHLECHTES Ergebnis (Marke verloren): verworfen + Quittung fehler ==="
bauen fuenf; (cd "$P" && L mind_verdicht_start "$P" mind-rules "$X" >/dev/null 2>&1)
sed 's/21\.08\.2026//' "$X" > "$P/.claude-mind/verdichten-mind-rules.nachher.md"   # Datum weg = Marke verloren
ALT=$(wc -c < "$X" | tr -d ' ')
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-rules pruefen 2>&1); RC=$?
pruef "pruefen rc 1" "$RC" "1"
pruef "Zeile 'verworfen:' in der Ausgabe" "$(printf '%s' "$OUT" | grep -c '^verworfen:')" "1"
pruef "Zeile 'verworfen:' im Deponat" "$(grep -c '^verworfen:' "$P/.claude-mind/verdichten-mind-rules.txt")" "1"
pruef "Quittung: fehler:verworfen" "$(tropfen "$P")" "fehler:verworfen"
pruef "KEIN Wortdiff erzeugt" "$(ls "$P/.claude-mind/"verdichten-mind-rules.wortdiff.* 2>/dev/null | wc -l | tr -d ' ')" "0"
pruef "anwenden nach rotem pruefen: rc 3, Datei unveraendert" "$( (cd "$P" && L mind_verdicht_ende "$P" mind-rules anwenden >/dev/null 2>&1); echo $?) $(wc -c < "$X" | tr -d ' ')" "3 $ALT"

echo "=== 6) Ergebnis fehlt (Agent schrieb nichts): rot, nicht abgestuerzt ==="
bauen sechs; (cd "$P" && L mind_verdicht_start "$P" mind-rules "$X" >/dev/null 2>&1)
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-rules pruefen 2>&1); RC=$?
pruef "pruefen rc 1" "$RC" "1"
pruef "verworfen: Ergebnis fehlt" "$(printf '%s' "$OUT" | grep -c 'Ergebnis fehlt')" "1"

echo "=== 7) ende OHNE Stand: rc != 0 mit Meldung ==="
bauen sieben
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-rules pruefen 2>&1); RC=$?
pruef "rc 2" "$RC" "2"
pruef "Meldung nennt den fehlenden Stand" "$(printf '%s' "$OUT" | grep -c 'kein Stand')" "1"
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-rules anwenden 2>&1); RC=$?
pruef "anwenden ohne Stand: rc 2" "$RC" "2"
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-rules gibtsnicht 2>&1); RC=$?
pruef "unbekannter Modus: rc 2" "$RC" "2"
OUT=$(cd "$P" && L mind_verdicht_start "$P" mind-gibtsnicht "$X" 2>&1); RC=$?
pruef "start fuer einen Nicht-Traeger: rc 2" "$RC" "2"

echo "=== 8) CRLF bleibt CRLF (Anwenden ist cp, nie Nachtippen) ==="
bauen acht crlf; (cd "$P" && L mind_verdicht_start "$P" mind-rules "$X" >/dev/null 2>&1)
gut "$P/.claude-mind/verdichten-mind-rules.nachher.md"; bericht "$P/.claude-mind/verdichten-mind-rules.bericht.md"
(cd "$P" && L mind_verdicht_ende "$P" mind-rules pruefen >/dev/null 2>&1)
(cd "$P" && L mind_verdicht_ende "$P" mind-rules anwenden >/dev/null 2>&1); RC=$?
pruef "anwenden rc 0" "$RC" "0"
CR=$(python -c "
import sys
b=open(sys.argv[1],'rb').read(); print(b.count(b'\r\n'), b.count(b'\n')-b.count(b'\r\n'))" "$(cygpath -w "$X" 2>/dev/null || echo "$X")")
pruef "alle Zeilenenden CRLF (kein nacktes LF)" "${CR#* }" "0"
pruef "CRLF-Zeilen vorhanden" "$([ "${CR% *}" -gt 3 ] && echo ja || echo nein)" "ja"
pruef "Datei == Ergebnis (byteweise)" "$(cmp -s "$X" "$P/.claude-mind/verdichten-mind-rules.nachher.md" && echo ja || echo nein)" "ja"

echo "=== 9) Deponat veraltet: Datei nach dem Pruefen geaendert -> anwenden verwirft, kein cp ==="
bauen neun; (cd "$P" && L mind_verdicht_start "$P" mind-rules "$X" >/dev/null 2>&1)
gut "$P/.claude-mind/verdichten-mind-rules.nachher.md"; bericht "$P/.claude-mind/verdichten-mind-rules.bericht.md"
(cd "$P" && L mind_verdicht_ende "$P" mind-rules pruefen >/dev/null 2>&1)
printf '\nNeue Zeile eines anderen Chats.\n' >> "$X"; ALT=$(wc -c < "$X" | tr -d ' ')
(cd "$P" && L mind_verdicht_ende "$P" mind-rules anwenden >/dev/null 2>&1); RC=$?
pruef "rc 1" "$RC" "1"
pruef "Datei unveraendert (kein cp)" "$(wc -c < "$X" | tr -d ' ')" "$ALT"
pruef "Quittung: fehler:anwenden" "$(tropfen "$P")" "fehler:anwenden"

echo "=== 10) start leert die Deponate des Vorlaufs (kein altes Ergebnis, kein alter Wortdiff) ==="
bauen zehn; (cd "$P" && L mind_verdicht_start "$P" mind-rules "$X" >/dev/null 2>&1)
gut "$P/.claude-mind/verdichten-mind-rules.nachher.md"; bericht "$P/.claude-mind/verdichten-mind-rules.bericht.md"
(cd "$P" && L mind_verdicht_ende "$P" mind-rules pruefen >/dev/null 2>&1)
(cd "$P" && L mind_verdicht_start "$P" mind-rules "$X" >/dev/null 2>&1)
pruef "altes Ergebnis weg" "$([ -f "$P/.claude-mind/verdichten-mind-rules.nachher.md" ] && echo da || echo weg)" "weg"
pruef "alter Wortdiff weg" "$(ls "$P/.claude-mind/"verdichten-mind-rules.wortdiff.* 2>/dev/null | wc -l | tr -d ' ')" "0"
pruef "anwenden gegen den neuen Stand ohne Pruefung: rc 3" "$( (cd "$P" && L mind_verdicht_ende "$P" mind-rules anwenden >/dev/null 2>&1); echo $?)" "3"

echo "=== 11) mind-memory: Frontmatter byteweise, Topic-Datei zaehlt nicht im Dauerkontext ==="
bauen elf; M="$P/mem/thema.md"; mkdir -p "$P/mem"
cat > "$M" <<'EOF'
---
name: thema
description: Ein Thema, das lang genug beschrieben ist, damit der Auswaehler es findet.
type: feedback
---

Der Fehler: am 21.08.2026 ging `x` schief, siehe [[anderes-thema]].
Ein erklaerender Satz ganz ohne Marke, der nur sagt, warum das alles so war und wie es dazu kam,
dass dieser Absatz so lang geworden ist, obwohl er in zwei Saetzen gesagt waere.
EOF
(cd "$P" && L mind_verdicht_start "$P" mind-memory "$M" >/dev/null 2>&1)
E="$P/.claude-mind/verdichten-mind-memory.nachher.md"
sed 's/^description: .*/description: Anders und kuerzer, aber lang genug fuer den Auswaehler hier./' "$M" | grep -v '^dass dieser Absatz' > "$E"
printf 'entfernt: keine\n' > "$P/.claude-mind/verdichten-mind-memory.bericht.md"
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-memory pruefen 2>&1); RC=$?
pruef "veraendertes Frontmatter: rc 1" "$RC" "1"
pruef "Meldung nennt das Frontmatter" "$(printf '%s' "$OUT" | grep -c 'Frontmatter')" "1"
grep -v '^dass dieser Absatz' "$M" | sed 's/^Ein erklaerender Satz.*/Kurz: so kam es./' > "$E"
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-memory pruefen 2>&1); RC=$?
pruef "Frontmatter gleich: rc 0" "$RC" "0"
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-memory anwenden 2>&1); RC=$?
pruef "anwenden rc 0 (Topic-Datei: kein 'Dauerkontext nicht kleiner')" "$RC" "0"
pruef "Datei == Ergebnis" "$(cmp -s "$M" "$E" && echo ja || echo nein)" "ja"
bauen zwoelf; M="$P/mem/thema.md"; mkdir -p "$P/mem"
printf -- '---\nname: t\ndescription: Ein Thema, das lang genug beschrieben ist, damit der Auswaehler es findet.\ntype: feedback\n---\n\nSiehe [[anderes-thema]] und 21.08.2026 sowie ein langer Satz ohne Marke der gekuerzt werden kann, ja.\n' > "$M"
(cd "$P" && L mind_verdicht_start "$P" mind-memory "$M" >/dev/null 2>&1)
E="$P/.claude-mind/verdichten-mind-memory.nachher.md"
printf -- '---\nname: t\ndescription: Ein Thema, das lang genug beschrieben ist, damit der Auswaehler es findet.\ntype: feedback\n---\n\nSiehe 21.08.2026.\n' > "$E"
printf 'entfernt: keine\n' > "$P/.claude-mind/verdichten-mind-memory.bericht.md"
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-memory pruefen 2>&1); RC=$?
pruef "[[Verweis]] verloren: rc 1" "$RC" "1"
pruef "Meldung nennt den Verweis" "$(printf '%s' "$OUT" | grep -c 'Verweis')" "1"

echo "=== 12) die fuenf Kandidaten-Bloecke: start nur MIT benannten Kandidaten, 'ende' laeuft ueber denselben Block ==="
for sk in mind-claudemd mind-rules mind-memory mind-files mind-update; do
  b=$(ls "$R/skills/$sk/bloecke/"*verdichten*.sh 2>/dev/null | head -1)
  pruef "$sk: Block ruft mind_verdicht_start" "$(grep -c 'mind_verdicht_start "\$PROJ" '"$sk"' "\$DATEI"' "$b")" "1"
  pruef "$sk: Block nimmt 'ende' als Argument" "$(grep -c 'mind_verdicht_ende "\$PROJ" '"$sk"' "\${2:-}"' "$b")" "1"
  pruef "$sk: ohne benannte Kandidaten weiter uebersprungen:keine-benannten-kandidaten" "$(grep -c 'uebersprungen:keine-benannten-kandidaten' "$b")" "1"
done
# Block im Fixture fahren: Rule MIT Deckel-Ausweis -> Auftrag; Rule OHNE -> uebersprungen, kein Stand
bauen dreizehn
OUT=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" bash "$R/skills/mind-rules/bloecke/08-step9b-verdichten-die.sh" 2>&1); RC=$?
pruef "Block mind-rules mit benanntem Kandidaten: gibt den Auftrag aus" "$(printf '%s' "$OUT" | grep -c 'AUFTRAG: verdichte EINE Datei')" "1"
pruef "…und den naechsten Aufruf mit 'ende pruefen'" "$(printf '%s' "$OUT" | grep -c '08-step9b-verdichten-die.sh" ende pruefen')" "1"
pruef "…und legt den Stand an" "$([ -f "$P/.claude-mind/verdichten-mind-rules.stand" ] && echo ja || echo nein)" "ja"
gut "$P/.claude-mind/verdichten-mind-rules.nachher.md"; bericht "$P/.claude-mind/verdichten-mind-rules.bericht.md"
OUT=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" bash "$R/skills/mind-rules/bloecke/08-step9b-verdichten-die.sh" ende pruefen 2>&1); RC=$?
pruef "Block … ende pruefen: rc 0 mit Wortdiff" "$RC $(printf '%s' "$OUT" | grep -c -- '----- WORTDIFF -----')" "0 1"
OUT=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" bash "$R/skills/mind-rules/bloecke/08-step9b-verdichten-die.sh" ende anwenden 2>&1); RC=$?
pruef "Block … ende anwenden: rc 0, gelaufen" "$RC $(tropfen "$P")" "0 gelaufen"
bauen vierzehn; sed -i '/GETILGT/d' "$X"
OUT=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" bash "$R/skills/mind-rules/bloecke/08-step9b-verdichten-die.sh" 2>&1)
pruef "Block ohne benannte Kandidaten: kein Auftrag" "$(printf '%s' "$OUT" | grep -c 'AUFTRAG: verdichte')" "0"
pruef "…kein Stand" "$([ -f "$P/.claude-mind/verdichten-mind-rules.stand" ] && echo ja || echo nein)" "nein"
pruef "…Quittung uebersprungen:keine-benannten-kandidaten" "$(tropfen "$P")" "uebersprungen:keine-benannten-kandidaten"

echo "=== 13) mind-claudemd: die Pipeline laeuft vorher UND nachher, ein neu roter Check verwirft ==="
bauen vierzehn-b; C="$P/CLAUDE.md"
cat > "$C" <<'EOF'
# Projekt

Kurzer Satz eins zum Aufbau.
Kurzer Satz zwei zum Aufbau.
Kurzer Satz drei zum Aufbau.
Kurzer Satz vier zum Aufbau.
Kurzer Satz fuenf zum Aufbau.
Kurzer Satz sechs zum Aufbau.

Test: `bash tests/alle.sh` (Version 5.1.0).
EOF
OUT=$(cd "$P" && L mind_verdicht_start "$P" mind-claudemd "$C" 2>&1)
pruef "start: Pipeline-Vorher-Stand liegt da" "$([ -s "$P/.claude-mind/verdichten-mind-claudemd.pipeline-vorher.txt" ] && echo ja || echo nein)" "ja"
pruef "Auftrag nennt die CLAUDE.md-Unantastbaren (Codeblock, Versionszeile, Zeiger)" "$(printf '%s' "$OUT" | grep -c 'jede Zeile mit einer Versionsnummer')" "1"
E="$P/.claude-mind/verdichten-mind-claudemd.nachher.md"
printf '# Projekt\n\nKurzer Satz eins zum Aufbau.\n\nTest: `bash tests/alle.sh` (Version 5.1.0).\n' > "$E"
printf 'entfernt: keine\n' > "$P/.claude-mind/verdichten-mind-claudemd.bericht.md"
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-claudemd pruefen 2>&1); RC=$?
pruef "gutes Ergebnis: rc 0" "$RC" "0"
pruef "…mit der Pipeline-Zeile vorher/nachher" "$(printf '%s' "$OUT" | grep -c 'Pipeline vorher/nachher')" "1"
# schlechtes: kleiner, aber eine neue 140-Zeichen-Prosazeile (Check 6) -> neu rot
printf '# Projekt\n\nKurzer Satz eins zum Aufbau und dann noch mehr Worte ohne jeden Zweck, damit diese Zeile 100 Zeichen ueberschreitet.\n\nTest: `bash tests/alle.sh` (Version 5.1.0).\n' > "$E"
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-claudemd pruefen 2>&1); RC=$?
pruef "neu roter Pipeline-Check: rc 1" "$RC" "1"
pruef "…Meldung nennt den Check" "$(printf '%s' "$OUT" | grep -c 'neu rot')" "1"

echo "=== 14) mind-files: Frontmatter (globs:) byteweise, sonst verworfen ==="
bauen fuenfzehn; F="$P/.claude/rules/backup-usage.md"
printf -- '---\nglobs: ["tools/**"]\n---\n\nAufruf tools/rollback.py list zeigt beide Ablagen, am 21.08.2026 gemessen.\nEin erklaerender Satz ohne Marke, der nur sagt, warum das alles so ist und wie es dazu kam, ja.\n' > "$F"
(cd "$P" && L mind_verdicht_start "$P" mind-files "$F" >/dev/null 2>&1)
E="$P/.claude-mind/verdichten-mind-files.nachher.md"
printf -- '---\nglobs: ["scripts/**"]\n---\n\nAufruf tools/rollback.py list zeigt beide Ablagen, am 21.08.2026 gemessen.\nKurz.\n' > "$E"
printf 'entfernt: keine\n' > "$P/.claude-mind/verdichten-mind-files.bericht.md"
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-files pruefen 2>&1); RC=$?
pruef "globs: veraendert: rc 1" "$RC" "1"
pruef "…Meldung nennt das Frontmatter" "$(printf '%s' "$OUT" | grep -c 'Frontmatter')" "1"
printf -- '---\nglobs: ["tools/**"]\n---\n\nAufruf tools/rollback.py list zeigt beide Ablagen, am 21.08.2026 gemessen.\nKurz.\n' > "$E"
OUT=$(cd "$P" && L mind_verdicht_ende "$P" mind-files pruefen 2>&1); RC=$?
pruef "Frontmatter + Aufrufform erhalten: rc 0" "$RC" "0"

echo "=== 15) die SKILL.md schicken nicht mehr zum Lesen von bestands-pass.md ==="
for sk in mind-claudemd mind-rules mind-memory mind-files mind-update; do
  pruef "$sk: 'Lies sie' beim Verdichten-Schritt weg" "$(grep -c 'Lies sie\.\*\*' "$R/skills/$sk/SKILL.md")" "0"
  pruef "$sk: SKILL.md nennt 'nur bei rotem Gate'" "$(grep -c 'nur bei rotem Gate' "$R/skills/$sk/SKILL.md")" "1"
done

echo
echo "test_verdicht_buendel: $ok gruen, $rot rot"
[ "$rot" -eq 0 ]
