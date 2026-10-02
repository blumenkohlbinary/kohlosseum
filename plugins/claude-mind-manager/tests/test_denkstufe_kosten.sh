#!/bin/bash
. "$(dirname "$0")/lib_test.sh"
# Pruefstand fuer die Kostenregel von /mind-denkstufe (v5.142.0, Etappe 52 §1, Teil 2).
#
# ⛔ WARUM DAS EINE EIGENE SAMMLUNG IST
#    Die Kostenregel ist der Grund, warum dieser Befehl ueberhaupt so gebaut ist:
#    Nutzer-Entscheidung 29.09.2026, der Probelauf flog aus dem Plugin, weil er Tokens
#    kostete. Ein Befehl, der bei jedem Aufruf zwei Agenten startet, waere derselbe
#    Fehler mit neuem Namen. Also wird GEPRUEFT, dass der Text die Reihenfolge
#    festlegt — gespeicherte Antwort zuerst, Agenten nur beim Erstaufruf.
#
# ⚠ Was eine Sammlung hier NICHT kann: erzwingen, dass das Modell sich daran haelt.
#   Pruefbar ist die Anweisung, nicht die Befolgung. Das steht hier, damit niemand die
#   gruenen Zeilen fuer eine Garantie liest.

export CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-C:/CD/KOHLEKTIV/Plugin - Entwicklung/hackj-plugins/plugins/claude-mind-manager}"
S="$CLAUDE_PLUGIN_ROOT/skills/mind-denkstufe/SKILL.md"
W="$CLAUDE_PLUGIN_ROOT/references/denkstufe_ablage.py"
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)

ok=0; rot=0
pruef() {
  if [ "$2" = "$3" ]; then echo "  [ok ] $1"; ok=$((ok+1))
  else echo "  [ROT] $1 — erwartet '$3', bekommen '$2'"; rot=$((rot+1)); fi
}

pruef "SKILL.md da" "$([ -f "$S" ] && echo ja || echo nein)" "ja"
pruef "Werkzeug da" "$([ -f "$W" ] && echo ja || echo nein)" "ja"
[ -f "$S" ] && [ -f "$W" ] || { echo "  Gegenstand fehlt — Abbruch"; exit 1; }

# --- 1 · die Reihenfolge steht im Text, und zwar VOR den Schritten ----------
# ⛔ Die Reihenfolge ist die Regel. Stuende die Kostenregel hinter den Schritten,
#    waere sie ein Nachgedanke — und genau so verschwinden Regeln.
Z_KOSTEN=$(grep -n 'DIE KOSTENREGEL STEHT VOR ALLEM ANDEREN' "$S" | cut -d: -f1 | head -1)
Z_STEP2=$(grep -n '^## Step 2' "$S" | cut -d: -f1 | head -1)
pruef "Kostenregel steht im Text" "$([ -n "$Z_KOSTEN" ] && echo ja || echo nein)" "ja"
pruef "... und VOR Step 2" \
  "$([ -n "$Z_KOSTEN" ] && [ -n "$Z_STEP2" ] && [ "$Z_KOSTEN" -lt "$Z_STEP2" ] && echo ja || echo nein)" "ja"

# --- 2 · gespeicherte Antwort zuerst, und der Lauf endet dort ---------------
pruef "Step 1 heisst antwort_zuerst" "$(grep -c '^## Step 1 · `antwort_zuerst`' "$S")" "1"
pruef "der Zweig endet mit exit 0" \
  "$(sed -n '/^## Step 1/,/^## Step 2/p' "$S" | grep -c 'exit 0')" "1"
pruef "der Zweig ruft --aufgabe (liest die gespeicherte Antwort)" \
  "$(sed -n '/^## Step 1/,/^## Step 2/p' "$S" | grep -c -- '--aufgabe')" "1"
# ⛔ Die uebersprungenen Schritte MUESSEN quittiert werden, sonst ist der Lauf von
#    einem abgebrochenen nicht zu unterscheiden (FEHLT in der Bilanz, v5.130.0).
pruef "die uebersprungenen Schritte werden quittiert" \
  "$(sed -n '/^## Step 1/,/^## Step 2/p' "$S" | grep -c 'uebersprungen:gespeicherte Antwort')" "1"
pruef "--neu umgeht den Zweig" \
  "$(sed -n '/^## Step 1/,/^## Step 2/p' "$S" | grep -c 'NEU" = "no"')" "1"

# --- 3 · Agenten nur beim Erstaufruf, und je GEGEN eine These --------------
pruef "Gegenprobe nur beim ERSTaufruf" \
  "$(grep -c 'Nur beim ERSTaufruf je Aufgabe' "$S" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"
pruef "je GEGEN eine These" \
  "$(grep -ci 'JE GEGEN EINE THESE' "$S" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"
pruef "die beiden Auftraege zeigen in verschiedene Richtungen" \
  "$(grep -c 'NIEDRIGE Stufe' "$S")$(grep -c 'HOHE Stufe' "$S")" "11"
# Lehre 17.09.2026: Sub-Agenten starten ungefragt eigene.
pruef "der Auftrag verbietet eigene Unteragenten" \
  "$(grep -c 'starte keine eigenen Agenten' "$S" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"
# Lehre workflow-agent-rate-limit.md: ein leerer Agent ist KEIN unauffaellig.
pruef "ein leerer Agent gilt als UNGEPRUEFT, nicht als unauffaellig" \
  "$(grep -c 'gilt seine Richtung als \*\*ungeprueft\*\*' "$S")" "1"

# --- 4 · der Agent wird NUR in der Gegenprobe gerufen ----------------------
# ⛔ Sonst waere die Kostenregel an einer Stelle umgangen, die niemand liest.
#    Gezaehlt wird der Abschnitt, in dem von Agenten die Rede ist.
AG_AUSSER=$("$PY" - "$S" <<'PYEOF'
import io, sys, re
t = io.open(sys.argv[1], encoding="utf-8").read()
# Step 5 (gegenprobe) herausschneiden, dann im Rest nach Agenten-Auftraegen suchen.
i = t.find("## Step 5")
j = t.find("## Step 6")
rest = t[:i] + t[j:] if i > 0 and j > i else t
# "Agent" in allowed-tools, in Merkmalstabellen und in Hard Constraints ist Rede ueber
# Agenten, kein Auftrag. Ein AUFTRAG stuende als Dispatch da.
print(len(re.findall(r"dispatch|Agent-Tool starten|starte zwei Agenten", rest, re.I)))
PYEOF
)
pruef "kein Agenten-Start aussserhalb der Gegenprobe" "$AG_AUSSER" "0"

# --- 5 · --messen: teuer, auf Ansage, und nicht bei Aussenwirkung ----------
pruef "--messen nur auf ausdrueckliche Ansage" \
  "$(grep -c 'nur auf ausdrueckliche Ansage' "$S" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"
pruef "--messen meldet VORHER die Kosten" \
  "$(grep -c 'VORHER melden, was es kostet' "$S" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"
pruef "Aussenwirkung -> melden, NICHT fahren" \
  "$(grep -c 'melden, nicht fahren' "$S" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"
# ⛔ Der Unterschied zum verworfenen Probelauf MUSS dastehen, sonst fliegt --messen beim
#    naechsten Aufraeumen mit raus — und zwar zu Recht, weil niemand den Unterschied weiss.
pruef "der Unterschied zum Probelauf vom 29.09. ist benannt" \
  "$(grep -c 'KEIN Probelauf im Sinn des 29.09' "$S" | awk '$1>0{print 1;exit}$1==0{print 0}')" "1"

# --- 6 · funktional: der zweite Aufruf FINDET die Antwort ------------------
# Ohne diesen Treffer gaebe es keinen Grund, beim zweiten Mal Agenten zu sparen.
T=$(mktemp -d)
export MIND_DENKSTUFE_DIR="$T/ablage"
export MIND_DENKSTUFE_SICHERUNG="$T/sich"; mkdir -p "$MIND_DENKSTUFE_SICHERUNG"
printf '{"empfehlung":{"modell":"opus","stufe":"high"},"aussagen":[{"text":"x","art":"HERGELEITET"}]}\n' > "$T/a.json"
"$PY" "$W" --schreiben "/mind-all" --json "$T/a.json" >/dev/null 2>&1
"$PY" "$W" --aufgabe "/mind-all" >/dev/null 2>&1
pruef "zweiter Aufruf findet die Antwort (rc 0)" "$?" "0"
"$PY" "$W" --aufgabe "/mind-rules" >/dev/null 2>&1
pruef "andere Aufgabe findet NICHTS (rc 1)" "$?" "1"
rm -rf "$T"

echo ""
echo "  $ok gruen · $rot rot"
[ "$rot" -eq 0 ] || exit 1
