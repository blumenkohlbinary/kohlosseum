#!/usr/bin/env bash
# /mind-all — aus skills/mind-all/SKILL.md ausgelagert (v5.152.0, Etappe 58 Hebel B, ZIEL 5).
# ⛔ Jeder Block ist ein EIGENER Bash-Aufruf. Was ein frueherer Block setzte, ist hier LEER —
#    deshalb leitet mind_block_umgebung PROJ, SCOPES_FILE, LAUF und AGENT_SOLL selbst her.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
mind_block_umgebung
ARGS="${ARGUMENTS:-}"; AUTO_MODE="yes"
echo "$ARGS" | grep -qE '(^|[[:space:]])--(ask|interactive)([[:space:]]|$)' && AUTO_MODE="no"
# ⛔ v5.139.0: der PROBELAUF ist ERSATZLOS entfallen (Nutzer 29.09.2026: „wieso kein
#    richtiger lauf kostet geld", „allgemein keine Probelaeufe mehr … ich will Ergebnisse
#    sehen"). Wer die Flagge noch mitgibt, bekommt einen ABBRUCH und keinen stillen
#    Echtlauf: wer die Flagge tippt, erwartet, dass nichts geschrieben wird.
# ⛔ KEINE Backticks in den Meldungen: in doppelten Anfuehrungszeichen fuehrt bash aus, was
#    zwischen ihnen steht (shell-windows.md) — beim ersten Bau stand hier "`--ask`", und das
#    haette bei jedem Abbruch ein "--ask: command not found" erzeugt.
if echo "$ARGS" | grep -qE '(^|[[:space:]])--dry-run([[:space:]]|$)'; then
  echo "ABBRUCH: --dry-run ist entfallen (seit 5.139.0) — es gibt keinen Probelauf mehr." >&2
  echo "         Bitte OHNE die Flagge aufrufen. Der Lauf ist dann ein echter Lauf," >&2
  echo "         mit Snapshot vorher (Rueckweg). --ask fragt weiterhin vor dem Anwenden." >&2
  exit 2
fi

[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || { CLAUDE_PLUGIN_ROOT=$(jq -r '.plugins["claude-mind-manager@kohlosseum"][0].installPath // empty' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null); [ -n "$CLAUDE_PLUGIN_ROOT" ] && { CLAUDE_PLUGIN_ROOT=$(cygpath -u "$CLAUDE_PLUGIN_ROOT" 2>/dev/null || printf '%s' "$CLAUDE_PLUGIN_ROOT"); echo "WARN: CLAUDE_PLUGIN_ROOT war leer — Rueckfall auf installed_plugins.json: $CLAUDE_PLUGIN_ROOT (v5.107.0)" >&2; }; }   # v5.107.0 Rueckfall
[ -z "$CLAUDE_PLUGIN_ROOT" ] && { echo "ERROR: \$CLAUDE_PLUGIN_ROOT fehlt" >&2; exit 1; }
source "$CLAUDE_PLUGIN_ROOT/hooks/lib.sh"
PROJ=$(mind_projekt_wurzel 2>/dev/null) || PROJ="${CLAUDE_PROJECT_DIR:-$(pwd)}"   # v5.80.0: Wurzel mit Roster; ohne lib.sh wie bisher

# Hook-Gesundheit (NEU v5.2.1) — meldet den stillen Hook-Tod nach einem Plugin-Update.
# Kein Abbruchgrund: /mind-all laeuft auch ohne Hooks. Aber es MUSS im Bericht stehen,
# sonst haelt der naechste Befundlauf ein totes Netz fuer ein gespanntes.
mind_hook_health "$PROJ" || HOOK_WARN="ja"

# ⛔ v5.64.0: HIER STAND EIN TOKEN-GATE, DAS DEN LAUF ABBRACH. Es ist WEG.
#    Nutzer-Entscheidung 10.09.2026: "die sollen garnicht mehr tokens messen
#    das soll komplett raus". Der Grund ist gemessen: die Zahl kam aus
#    `mind_transkript_pfad`, und dieser Merker liegt je PROJEKT statt je
#    SITZUNG — bei mehreren Rollen im Ordner gewinnt der Letzte. Nora (sync,
#    Palvedo) stand bei ~130 000 und wurde mit 721 405 abgewiesen.
#    ⭐ DAS TEILSYNC-VERBOT BLEIBT, es wechselt den MESSPUNKT: der Lauf faehrt
#       immer und versucht immer alle 4 Agents; ob es gereicht hat, entscheidet
#       HINTERHER `mind_sync_voll` an `umfang=`/`ungepruef=`. Ein Lauf, der
#       nicht durchkam, begleicht KEINE Schuld — `OPEN` bleibt liegen.
#    ⚠ Der Transkript-Pfad wird trotzdem HIER geholt: er traegt unten die
#      Lauf-Kennung und die Sitzungskennung der Sperre. Je frueher, desto
#      kleiner das Rennfenster (v5.38.0).
MIND_TP=""
if type mind_transkript_pfad >/dev/null 2>&1; then
  MIND_TP=$(mind_transkript_pfad "$PROJ")
fi

# ⛔ v5.59.0: DIE SPERRE STEHT VOR DEM SNAPSHOT. Befund von Nora (Palvedo):
#    der Snapshot entstand ZUERST, und jeder abgewiesene Zweitlauf liess rund
#    464 KB liegen — eine Sicherung fuer einen Lauf, den es nie gab. Bei drei
#    Sitzungen in einem Ordner summiert sich das mit jedem Versuch.
# ⚠ DIE KENNUNG KANN DESHALB NICHT MEHR DER SNAPSHOT-NAME SEIN. Sie kommt
#   jetzt aus Zeitstempel und Transkriptnamen; `mind_lauf_kennung` bleibt
#   unveraendert fuer alle, die sie mit einem Snapshot rufen.
# ⛔ v5.139.0: hier stand `if [ "$DRY_RUN" = "no" ]`. Der Probelauf ist entfallen, also laeuft der Block IMMER — die Bedingung ist nicht wahr-gesetzt, sondern WEG.
# ⭐ v5.66.0: DIE KENNUNG KOMMT AUS DER UMGEBUNG, nicht aus einem Dateinamen.
#    `CLAUDE_CODE_SESSION_ID` ist in Skill-Bash gesetzt und traegt genau die
#    Kennung, die die Hooks aus stdin bekommen (gemessen 10.09.2026 in zwei
#    Sitzungen). ⛔ Bis v5.65.0 kam sie aus `$MIND_TP` — und der stammte aus
#    einem Merker je PROJEKT. Bei mehreren Rollen im Ordner schrieb der
#    Sperrenhalter damit womoeglich eine FREMDE Kennung ins Lock, und die
#    Abweisung nannte die falsche Sitzung. Das ist schlimmer als gar keine.
# ⚠ FAIL-SAFE: leere Variable -> Rueckfall auf den Dateinamen, wie bisher.
MIND_SID="${CLAUDE_CODE_SESSION_ID:-$(basename "${MIND_TP:-nosession}" .jsonl)}"
# ⛔ v5.140.0 (Etappe 51 §1): DIE LAUF-ID KOMMT AUS DEM KOPF, nicht aus `date` hier.
#    Der Kopf-Block (oben, eigener bash-Fence) hat sie erzeugt und in seine Startzeile
#    geschrieben; eine Variable von dort erreicht diesen Block NICHT. Holt man sie
#    stattdessen hier neu, tragen Kopf und Lock VERSCHIEDENE IDs — und die Pruefung,
#    die beide vergleicht, waere von Anfang an rot.
# ⚠ FAIL-SAFE: kein `lauf`-Feld im Kopf (Altbestand, Einzellauf) -> wie bisher rechnen.
# ⛔ v5.140.0, Nachtrag (Antons Befund): `mind_kopf_lauf_frisch`, NICHT `mind_kopf_lauf`.
#    Der Unterschied ist der ganze Fall: die blosse Kopf-ID kann die eines FRUEHEREN
#    Laufs sein (Rita fuhr den Kopf-Block nicht, die letzte Startzeile war neun Tage
#    alt). Uebernimmt der Lock sie, vergleicht `mind_kopf_epoch` alt gegen alt und ist
#    zufrieden — dieselbe Zirkularitaet eine Ebene hoeher.
# ⛔ UND KEIN FAIL-SAFE-NEURECHNEN: ein `|| LAUF=$(date …)` wuerde genau den Fall
#    wieder verdecken, um den es geht. Fehlt der eigene Kopf, bricht der Lauf AB.
# ⛔ v5.145.0 (Etappe 55 §6): GENAU EINMAL rufen. `mind_kopf_lauf_frisch` VERBRAUCHT den
#    Merker `lauf-offen` — ein zweiter Aufruf in einem spaeteren Block scheitert mit
#    „KOPF-BLOCK FEHLT". Spaetere Bloecke LESEN die ID: `mind_lock_lauf "$PROJ"` (der Lock
#    traegt sie bis Step 2.9) oder `mind_kopf_lauf "$PROJ"` (die Kopfzeile).
if ! LAUF=$(mind_kopf_lauf_frisch "$PROJ"); then
  echo "ABBRUCH: ohne eigenen Kopf-Block laeuft hier nichts weiter." >&2
  exit 1
fi
if ! _SPERRE=$(mind_lauf_sperre "$PROJ" "$LAUF" "$MIND_SID"); then
  echo "$_SPERRE" >&2
  exit 0    # ⛔ 0, NICHT 1 — kein Fehler, sondern die richtige Antwort.
            #   Ein Rueckgabewert 1 saehe im Log wie ein kaputter Lauf aus.
fi
# ⛔ v5.144.0 (Etappe 56 §1, CK3 18.10.2026): NUR beim ABBRUCH DIESES Blocks freigeben.
#    Jeder Code-Block ist ein EIGENER Bash-Aufruf — ein `trap … EXIT` feuert am Ende DIESES
#    Blocks, nicht am Ende des Laufs. Bis v5.143.0 stand hier ein unbedingter trap; gemessen
#    28.10.2026: im naechsten Aufruf war der Lock WEG. Er schuetzte nichts — weder die
#    Abweisung eines zweiten Laufs noch „liegt der Lock, aendert der Arbeiter keine
#    Dauerkontext-Datei" — und die Identitaetspruefung aus v5.140.0 (Kopf-Lauf gegen
#    Lock-Lauf) lief in jedem echten Lauf in ihren Ohne-Lock-Zweig.
#    Freigegeben wird im Schlussblock (Step 2.9). Ein Lauf, der danach abbricht, laesst
#    den Lock liegen: dieselbe Sitzung uebernimmt ihn sofort, eine fremde nach
#    MIND_LAUF_LOCK_MAXAGE (2 h) — `mind_lauf_sperre`.
trap '_mind_rc=$?; [ "$_mind_rc" -ne 0 ] && mind_lauf_frei "$PROJ" "$LAUF"' EXIT

# ⛔ v5.139.0: hier stand `if [ "$DRY_RUN" = "no" ]`. Der Probelauf ist entfallen, also laeuft der Block IMMER — die Bedingung ist nicht wahr-gesetzt, sondern WEG.
SNAPSHOT=$(mind_snapshot "$PROJ" "pre-mind-all") || {
  echo "ABBRUCH: Snapshot fehlgeschlagen — KEIN Skill wird gestartet." >&2; exit 1; }
echo "Snapshot fuer den gesamten Durchlauf: $SNAPSHOT"

# ⛔ v5.21.3 — SAGEN, WAS NICHT DRIN IST.
#    Befund aus `Pc Forschung` (26.08.2026): `INDEX.md`, die zentrale
#    Projektdatei, lag nicht im Snapshot. Alle Aenderungen daran liefen ohne
#    Netz, und die Restore-Liste im Bericht war fuer sie schlicht falsch.
#
#    Ihr Vorschlag war, `INDEX.md` fest einzubauen. Das waere ein
#    projektspezifisches Pflaster in einem allgemeinen Werkzeug —
#    `MIND_SNAPSHOT_EXTRA` loest den Fall seit v5.2.1 allgemein.
#
#    ⭐ GEMESSEN, warum sie das nicht wissen konnten: die Variable kommt in
#       `hooks/lib.sh` vor und in KEINEM Skill, KEINEM Bericht, KEINER
#       Referenz. Wer den Schlussbericht liest, sieht eine Restore-Liste und
#       hat keinen Weg zu erfahren, dass sie erweiterbar ist. Genau dasselbe
#       ist hier zweimal mit `knowledge/` passiert (env-vars.md).
#
#    ⚠ Gemeldet wird nur — welche Datei wichtig ist, weiss der Nutzer.
#    ⚠ NUR die zuletzt GEAENDERTEN, hoechstens fuenf. Eine vollstaendige Liste
#      waere hier 15 Namen lang (gemessen in diesem Projekt) und damit genau
#      die Ausgabe, die man gewohnheitsmaessig ueberliest — wovor `Pc Forschung`
#      im selben Bericht warnt. Die juengsten sind die, an denen gearbeitet wird.
#    ⛔ Der GLOB laeuft, NICHT `$(ls -t ...)`. Eine unquotierte
#      Befehlssubstitution zerlegt am Leerzeichen — und dieses Projekt heisst
#      `Plugin - Entwicklung/Claude Mind Manager`. Erste Fassung meldete
#      dadurch "79 Dateien" statt 15, mit Namen wie "Plugin - Claude Mind".
#      Klasse `windows-pfad`, in diesem Projekt seit v5.2.1 dokumentiert
#      ("Rotation nie mit xargs") und trotzdem wieder entstanden.
#    ⛔ Und KEINE Pipe in die Schleife: die liefe in einer Subshell, und `_N`
#      waere danach wieder 0 — derselbe Fehler steckt schon einmal in dieser
#      Datei (mind_check_tools_have_rules, dort mit einer Merkdatei geloest).
_LK=$(mind_snapshot_luecken "$PROJ" "$SNAPSHOT")
_N="${_LK%%|*}"; _UNGEDECKT="${_LK#*|}"
if [ "${_N:-0}" -gt 0 ] 2>/dev/null; then
  echo "  ⚠ NICHT im Snapshot ($_N Datei(en), die zuletzt geaenderten): $_UNGEDECKT"
  echo "    Ist eine davon fuer diesen Lauf tragend, VOR dem naechsten Mal setzen:"
  echo "      export MIND_SNAPSHOT_EXTRA=\"\$PWD/<pfad>\"   # ⛔ ABSOLUT, relativ wird still verworfen"
fi

# ⛔ v5.30.0: SPERRE GEGEN PARALLELE LAEUFE — direkt nach dem Snapshot, weil
#    die Laufkennung aus seinem Namen kommt.
#    Befund aus `Creator` (30.08.2026), hier unabhaengig nachgemessen:
#    `SCOPES_FILE` liegt PRO PROJEKT, der Stop-Hook feuert PRO SITZUNG. Zwei
#    Chats im selben Ordner haengen ihre `skill=`-Zeilen an DIESELBE Datei,
#    ihre Summe erreicht 5, `SYNC_LIEF` geht auf "ja" — und `rm -f "$OPEN"`
#    tilgt die Schuld fuer Arbeit, die KEIN EINZELNER Lauf geleistet hat.
#    ⚠ Kein flock (auf MSYS unzuverlaessig). `mkdir` ist atomar; auf diesem
#      Aufbau gemessen: 40 gleichzeitig -> genau 1 gewinnt, Gegenprobe
#      abgewiesen.
# ⚠ v5.59.0: DIE SPERRE WIRD OBEN GENOMMEN, vor dem Snapshot. Hier stand sie
#   bis v5.58.0 — also NACH einer Sicherung, die ein abgewiesener Lauf gar
#   nicht braucht. Der Block ist umgezogen, nicht entfallen.

# Kettenmarke — enthaelt den Snapshot-PFAD, damit die Einzel-Skills pruefen koennen,
# ob er wirklich da ist.
# ⚠ v5.139.0: hier stand „NUR wenn ein Snapshot existiert (C2-Fix: im Probelauf keine
#   Marke, sonst behauptet sie ein Netz, das es nicht gibt)". Der C2-Fix bleibt in der
#   SACHE gueltig; nur sein Traeger wechselt — ohne Probelauf gibt es keinen Lauf OHNE
#   Snapshot mehr, weil Step 0 bei gescheitertem Snapshot abbricht.
SCOPES_FILE="$PROJ/.claude-mind/analyzed-scopes"
# ⛔ v5.139.0: hier stand `if [ "$DRY_RUN" = "no" ]`. Der Probelauf ist entfallen, also laeuft der Block IMMER — die Bedingung ist nicht wahr-gesetzt, sondern WEG.
mkdir -p "$(dirname "$SCOPES_FILE")"; : > "$SCOPES_FILE"
# ⛔ v5.140.0 (Etappe 51 §1, Ritas Befund): run_started kommt aus `lock/ts`, NICHT mehr aus
#    dem Kopf. Vorher stand hier `mind_kopf_epoch` — und `mind_schritt_start` verglich
#    damit die ts DES KOPFES: **die Pruefung verglich den Kopf mit sich selbst**
#    (`Kopf < Kopf - 900`) und konnte nicht fehlschlagen. Gemessen 01.10.2026: ein neun
#    Tage alter Kopf lief glatt durch, derselbe Kopf mit unabhaengigem Bezug -> rc 1.
# ⭐ `lock/ts` ist der richtige Bezug: er entsteht unabhaengig vom Kopf und VOR dem
#    Snapshot (v5.59.0 zog die Sperre genau deshalb nach oben) — damit bleibt auch die
#    v5.118.0-Falle weg (run_started nach dem Snapshot, 12 s spaeter, erster Skill brach
#    faelschlich ab).
# ⚠ Fehlt `lock/ts`, wird KEINE Sekunde geraten: die Zeile entfaellt. mind_schritt_start
#    kommt damit zurecht, und eine fehlende Zeile ist ehrlicher als eine erfundene.
_RS=$(cat "$PROJ/.claude-mind/mind-all.lock/ts" 2>/dev/null)
case "$_RS" in
  ''|*[!0-9]*) echo "WARN: lock/ts unlesbar — run_started wird NICHT geschrieben (keine geratene Sekunde)." >&2 ;;
  *) echo "run_started=$_RS"   >> "$SCOPES_FILE" ;;
esac
echo "snapshot=$SNAPSHOT"        >> "$SCOPES_FILE"

# ⛔ v5.19.0: Die Agent-Quittung wird HIER angelegt, nicht in mind-update.
#    Bis v5.18.0 rief `mind_agent_quittung_start` ausschliesslich mind-update
#    Step 3.5 — also GENAU DER SCHRITT, DER AUSFAELLT. Faellt er aus, faellt die
#    Quittung mit aus, und ihr FEHLEN sieht aus wie ihr SCHWEIGEN.
#    Das ist woertlich dasselbe Muster, das v5.3.1 eine Ebene tiefer behoben hat:
#    ein Hook, der schweigt weil er soll, und einer, der schweigt weil er tot ist,
#    sind im Log nicht zu unterscheiden.
#    Ab hier gilt: keine Quittung == die Kette kam nie bis zum Fan-out. Von
#    aussen messbar, weil der Anleger nicht mehr im Ausfallpfad liegt.
#    ⛔ v5.21.3: die 4 ist PFLICHT. v5.21.2 gab der Funktion den Parameter und
#       liess beide Aufrufer unveraendert — die Quittung verhielt sich damit
#       exakt wie vorher. Woertlich der v5.7.1-Fall ("es sammelte die Variable
#       und benutzte sie nie") und derselbe Halbfix wie bei classify_path am
#       selben Tag. Ohne die Zahl kann die Bilanz "nie dispatcht" nicht von
#       "ueber das Agent-Werkzeug gestartet" unterscheiden — und genau das hat
#       `Pc Forschung` am 26.08. zum ZWEITEN Mal unveraendert gemeldet.
#    ⛔ v5.104.0: die 4 bleibt hier stehen, obwohl custom-context bei 0 Dateien
#       entfaellt — Step 0 kennt die Dateizahl nicht (Step 1.5 von mind-update zaehlt
#       sie). Das Ueberspringen quittiert mind-update mit `mind_agent_uebersprungen`;
#       die Bilanz zieht es von ERWARTET ab, Step 2.96a vom Soll (`3/3 agents`).
#       Ohne das war ein Projekt ohne Custom-Context-Dateien NIE voll (Palvedo,
#       10.–13.09.2026, drei Laeufe, zehn Rettungen ungetilgt).
mind_agent_quittung_start "$PROJ" 4

# ⛔ v5.145.0 (Etappe 55 §6, Veras Befund): DIESER ABSCHNITT IST HISTORIE. Den Merker
#    `.claude-mind/transkript-pfad` gibt es seit v5.66.0 NICHT MEHR — niemand schreibt
#    oder liest ihn (gemessen am Paket 5.144.0: nur noch Kommentare). `mind_transkript_pfad`
#    adressiert die Sitzung ueber `CLAUDE_CODE_SESSION_ID`. Eine liegengebliebene Datei
#    (Zustellplan, Stand 04.09.2026) ist ein Rest, kein Zustand. Vera las die Saetze unten im
#    Praesens als heutige Mechanik — sie stehen deshalb jetzt in der Vergangenheit.
# v5.38.0–v5.65.0: der Merker WAR eine Datei je PROJEKT und sollte eine SITZUNG
#    kennzeichnen — jede Sitzung ueberschrieb ihn bei jedem Prompt, der Letzte gewann.
#    Wer ihn erst in Step 2.96a las, hatte dazwischen MINUTEN Rennfenster; wer ihn hier
#    las, Millisekunden.
# ⚠ Der Rest damals: schob eine andere Sitzung ihren Prompt genau dazwischen,
#   war er schon fremd. Aufloesen liesse sich das nur mit einer Sitzungskennung
#   im Skill — die gibt es dort nicht (CLAUDE_SESSION_ID ist LEER, gemessen v5.30.0).
#   ⛔ v5.66.0 KORRIGIERT: die Messung stimmte, der Schluss nicht —
#      `CLAUDE_CODE_SESSION_ID` ist gesetzt und traegt genau diese Kennung.
# ⚠ v5.55.0: MIND_TP steht schon — es wird oben vor dem Teilsync-Gate geholt.
#   Hier wird es nur noch GEMELDET. Ein zweites `mind_transkript_pfad` waere ein
#   zweiter Griff auf einen Merker, der sich zwischendurch geaendert haben kann.
if [ -n "$MIND_TP" ]; then
  echo "Transkript dieser Sitzung: $(basename "$MIND_TP")"
  # ⛔ v5.151.0 (Etappe 58 §1, ZIEL 5): DER EIGENE VERLAUF IST DER GROESSTE KOSTENPOSTEN. Jeder Schritt
  #    dieses Laufs liest ihn neu (Cache-Lesen). Gemessen am Transkript (`references/lauf_tokens.py`):
  #    Ritas Lauf 29.09. 132,9 Mio Tokens, davon 85 % die steuernde Sitzung bei einem Verlauf bis
  #    964 634; Veras Lauf 12.10. 91,3 Mio, davon 93 % bei Verlauf bis 770 099. Was der Lauf braucht,
  #    liegt in Dateien (Rettungen, Quittungen, Context-Dateien) — der alte Verlauf der Sitzung nicht.
  # ⛔ HINWEIS, KEIN ZWANG (Nutzer 10.09.2026: keine Token-Messung als Zwang). Geleert wird von aussen:
  #    im Rollen-Aufbau leert der manager die Sync-Sitzung VOR dem Auftrag; allein: `/clear`.
  _VL=$(grep -o '"cache_read_input_tokens":[0-9]*' "$MIND_TP" 2>/dev/null | tail -1 | cut -d: -f2)
  case "$_VL" in ''|*[!0-9]*) _VL=0 ;; esac
  if [ "$_VL" -gt "${MIND_VERLAUF_HINWEIS:-150000}" ] 2>/dev/null; then
    echo "⚠ VERLAUF: diese Sitzung traegt rund $_VL Tokens Verlauf — jeder Schritt dieses Laufs liest ihn neu."
    echo "  Gemessen: 85-93 % eines Laufs kostet die steuernde Sitzung. Guenstiger: den Lauf in einer FRISCH"
    echo "  geleerten Sitzung fahren (Rollen-Aufbau: der manager leert die Sync-Sitzung vorher). Der Lauf geht weiter."
    echo "  Diese Zeile gehoert in den Schlussbericht (Step 3) — gemessen wird hinterher: references/lauf_tokens.py --lauf <ID>."
  fi
else
  echo "⚠ Transkript NICHT bestimmbar — Tokenzahlen dieses Laufs bleiben LEER."
  echo "  (Eine fehlende Zahl ist keine Null. Der Lauf geht weiter.)"
fi
