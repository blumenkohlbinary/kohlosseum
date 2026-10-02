#!/bin/bash
. "$(dirname "$0")/lib_test.sh"
# Pruefstand fuer den Skilltext von /mind-denkstufe (v5.142.0, Etappe 52 §1, Teil 2).
#
# ⛔ WAS HIER GEPRUEFT WIRD UND WAS NICHT
#    Ein Skilltext ist eine Anweisung an ein Modell — ob sie BEFOLGT wird, kann keine
#    Sammlung messen (`mind_check_tools_have_rules` misst Erreichbarkeit, nicht Wirkung).
#    Pruefbar ist dagegen, ob der Text SAGT, was er sagen muss, und ob er sich nicht
#    selbst widerspricht. Genau das ist hier zweimal passiert und beide Male gefunden:
#    die Pflichtschritt-Liste gegen den wirklichen Aufruf, und eine feste Kennzahl im
#    Text, zwei Abschnitte ueber dem Satz, der sie verbietet.

export CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-C:/CD/KOHLEKTIV/Plugin - Entwicklung/hackj-plugins/plugins/claude-mind-manager}"
S="$CLAUDE_PLUGIN_ROOT/skills/mind-denkstufe/SKILL.md"
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)

ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

# --- 0 · VAKUUM-WAECHTER -----------------------------------------------------
pruef "SKILL.md liegt im Paket" "$([ -f "$S" ] && echo ja || echo nein)" "ja"
[ -f "$S" ] || { echo "  Gegenstand fehlt — Abbruch"; exit 1; }

# --- 1 · Frontmatter --------------------------------------------------------
pruef "name steht im Frontmatter" "$(grep -c '^name: mind-denkstufe$' "$S")" "1"
pruef "allowed-tools stehen da"   "$(grep -c '^allowed-tools:' "$S")" "1"
pruef "Agent ist erlaubt (die Gegenprobe braucht es)" \
  "$(grep '^allowed-tools:' "$S" | grep -c 'Agent')" "1"
# ⛔ `kontext-anlegen.md`: die description muss DIREKTIV sein, sonst zieht das Modell
#    den Skill nicht (gemessen 20-84 % Auswahlquote, direktiver Stil half).
pruef "description ist direktiv (ALWAYS invoke)" \
  "$(grep -c 'ALWAYS invoke' "$S")" "1"
# Ausschluesse am Ende fangen Fehlaktivierung ab — ebenfalls aus kontext-anlegen.md.
pruef "description nennt AUSSCHLUESSE" \
  "$(sed -n '/^description:/,/^allowed-tools:/p' "$S" | grep -c 'NICHT fuer')" "1"

# --- 2 · genau EIN Versions-Stempel -----------------------------------------
# ⛔ Lehre aus 5.139.0/5.140.0: der Stempler hat dreizehn Releases lang nur ANGEHAENGT,
#    und in allen zehn Skills stand ein zweiter, stale Stempel daneben.
pruef "genau ein MIND_SKILL_VERSION" "$(grep -c '^MIND_SKILL_VERSION=' "$S")" "1"

# --- 3 · ⭐ Pflichtschritte gegen den WIRKLICHEN Aufruf ----------------------
# ⛔ DIE STAERKSTE ZUSICHERUNG DIESER SAMMLUNG. Stehen in der Liste andere Schritte als
#    im `mind_schritt_start`-Aufruf, ist die Buchfuehrung von Anfang an falsch: die
#    Bilanz erwartet Namen, die nie quittiert werden, und meldet FEHLT (v5.130.0) —
#    oder sie erwartet zu wenige und meldet einen Teillauf als vollstaendig.
LISTE=$("$PY" - "$S" <<'PYEOF'
import io, sys, re
t = io.open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"PFLICHTSCHRITTE\n(.*?)```", t, re.S)
print(" ".join(m.group(1).split()) if m else "")
PYEOF
)
AUFRUF=$("$PY" - "$S" <<'PYEOF'
import io, sys, re
t = io.open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"mind_schritt_start \"\$PROJ\" mind-denkstufe ([^\n]*)", t)
print(" ".join(m.group(1).split()) if m else "")
PYEOF
)
pruef "Pflichtschritt-Liste ist nicht leer" "$([ -n "$LISTE" ] && echo ja || echo nein)" "ja"
pruef "mind_schritt_start-Aufruf gefunden" "$([ -n "$AUFRUF" ] && echo ja || echo nein)" "ja"
pruef "Liste und Aufruf nennen DIESELBEN Schritte" "$LISTE" "$AUFRUF"

# --- 4 · die Ausgabeform traegt die Herkunft je Zeile ------------------------
pruef "BELEGT kommt vor"       "$(grep -c 'BELEGT' "$S" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"
pruef "HERGELEITET kommt vor"  "$(grep -c 'HERGELEITET' "$S" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"
pruef "GEGENSTIMMEN kommen vor" "$(grep -ci 'GEGENSTIMMEN' "$S" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"
pruef "UNGEPRUEFT fuer den leeren Agenten" \
  "$(grep -c 'UNGEPRUEFT' "$S" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"
pruef "BELEGT ohne Quelle ist ausdruecklich verboten" \
  "$(grep -ci 'BELEGT` ohne Quelle' "$S" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"

# --- 5 · ⛔ KEINE feste Kennzahl im Text ------------------------------------
# ⛔ Der Text verbietet es selbst — und ich hatte beim Schreiben „99 635 Tokens"
#    hineingeschrieben, zwei Abschnitte ueber dem Satz, der es verbietet. Diese
#    Zusicherung haelt die Stelle frei.
# ⚠ Versionsnummern (5.141.0) und Jahre (2026) sind HISTORISCHE Marken, keine
#   Kennzahlen — sie sind ausgenommen, und die Ausnahme ist benannt statt breit.
ZAHLEN=$("$PY" - "$S" <<'PYEOF'
import io, sys, re
t = io.open(sys.argv[1], encoding="utf-8").read()
# Versionsmarken und Daten entfernen, dann nach Zahlen ab vier Stellen suchen
t = re.sub(r"v?\d+\.\d+\.\d+", " ", t)
t = re.sub(r"\b(?:19|20)\d\d\b", " ", t)
t = re.sub(r"\b\d{1,2}\.\d{1,2}\.", " ", t)
print(len(re.findall(r"\d[\d\u00a0 ]{3,}\d", t)))
PYEOF
)
pruef "keine Kennzahl ab vier Stellen im Text" "$ZAHLEN" "0"
# GEGENKONTROLLE: das Muster MUSS anschlagen, wenn eine Kennzahl drinsteht.
KONTROLL=$("$PY" - <<'PYEOF'
import re
t = "ein Agent kostete 99 635 Tokens, Version 5.141.0, am 01.10.2026"
t = re.sub(r"v?\d+\.\d+\.\d+", " ", t)
t = re.sub(r"\b(?:19|20)\d\d\b", " ", t)
t = re.sub(r"\b\d{1,2}\.\d{1,2}\.", " ", t)
print(len(re.findall(r"\d[\d\u00a0 ]{3,}\d", t)))
PYEOF
)
pruef "   ... und das Muster TRIFFT eine echte Kennzahl (Gegenkontrolle)" "$KONTROLL" "1"

# --- 6 · die gesetzte Schwelle ist als gesetzt ausgewiesen -------------------
pruef "die 30 ist als GESETZT benannt" \
  "$(grep -c 'GESETZT, nicht gemessen' "$S" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
