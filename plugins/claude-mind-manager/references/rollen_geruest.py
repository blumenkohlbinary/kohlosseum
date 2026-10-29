# -*- coding: utf-8 -*-
"""Das Roster-Geruest erzeugen und die Abschnittsfolge pruefen.

⛔ DAS GERUEST IST NICHT FREI ZU ENTWERFEN. Es steht in Joplin
   `🧭 Manager-Chats` §10a (ID 6e27ab4e46f94884b88f56a1e7c46f27), Stand
   09.09.2026: verbindliche Abschnittsfolge, verbindliche Ueberschriften, vier
   Saetze die woertlich stehen muessen. **Dieses Skript baut genau das.**
   Sonst gaebe es zwei Wahrheiten — eine fuer Projekte, die die Kopiervorlage
   benutzt haben, und eine fuer die, in denen `/mind-files` lief.

⭐ WEGLASSEN IST ERLAUBT, UMBENENNEN UND UMSTELLEN NICHT. Was es in einem
   Projekt nicht gibt, faellt weg. Ein Roster, den man in jedem Projekt an
   derselben Stelle findet, ist mehr wert als einer, der schoener formuliert
   ist. Genau das prueft `--pruefe`.

⛔ DREI AUSFUELLFEHLER, alle aus §10a, alle hier mechanisch abgefangen:
   1. **Pfade, die es nicht gibt.** Am 09.09.2026 stand `knowledge/` nach einer
      Umbenennung noch an sechs Stellen im Dauerkontext und liess einen
      Snapshot still auf 0 Dateien laufen. → Die Eigentuemer-Tabelle wird aus
      dem TATSAECHLICHEN Bestand erzeugt, nie aus einer festen Liste.
   2. **Vergessen, was nicht im Projektordner liegt** — Claudes Speicher unter
      `~/.claude/projects/<slug>/memory/`. → Steht immer drin.
   3. **Allgemeines hineinkopieren statt zu verweisen.** → Das Geruest verweist
      auf `~/.claude/rules/manager-chats.md` und wiederholt sie nicht.

⛔ LEERE NAMEN BLEIBEN LEER. Namen vergibt der Nutzer. Ein erfundener Name ist
   schlimmer als eine Luecke: die Adressierung trifft dann ins Leere, und das
   faellt erst auf, wenn jemand eine Nachricht schickt.

⚠ UNTERORDNER-AUFBAU (§10a, Stand 11.09.2026 — Creator, neun Rollen in neun
   Unterordnern, der Roster in der Wurzel): die Rollentabelle traegt eine FUENFTE
   Spalte `Ordner`, relativ zur Wurzel (`Creator Stimme/`). Ohne sie weiss weder
   Sync noch Manager, wo eine Sitzung lebt. Erkannt wird der Aufbau am BESTAND:
   ein Unterordner mit eigenem `.claude/`, `.claude-mind/` oder `CLAUDE.md`
   (`unterordner()`). Ohne solche Unterordner bleibt es bei vier Spalten.
   `--pruefe` nimmt beide Formen; fuenf Spalten ohne Aufbau sind ein Hinweis,
   ein Aufbau ohne Spalte `Ordner` ist ein Befund.

⛔ SPALTE 3 IST DIE BLANKE UUID (`echo "$CLAUDE_CODE_SESSION_ID"`), NIE die
   `local_…`-Form aus `list_sessions` — §10a seit 11.09.2026. Bis dahin schrieb
   dieses Geruest `local_…` als Platzhalter vor, und das Rollen-Gate (v5.54.0)
   konnte damit KEINE Sitzung je erkennen. `--pruefe` meldet die falsche Form.

AUFRUF
    rollen_geruest.py --projekt <dir>            Geruest nach stdout
    rollen_geruest.py --pruefe <rollen.md>       Abschnittsfolge pruefen
                                                 (liegt sie unter .claude/rules/,
                                                  wird der Unterordner-Aufbau der
                                                  Wurzel mitgeprueft)
    rollen_geruest.py --selbsttest

RUECKGABE
    0 = in Ordnung · 1 = Abweichung · 2 = Aufruffehler
"""
import io
import os
import re
import shutil
import subprocess
import sys

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# ---------------------------------------------------------------------------
# Die verbindliche Abschnittsfolge aus §10a. ⛔ Reihenfolge ist Teil der
# Zusicherung — eine Liste, die nur die Namen prueft, liesse das Umstellen zu.
# ---------------------------------------------------------------------------
ABSCHNITTE = [
    "Wem welche Datei geh\u00f6rt",
    "Die projektweiten Werkzeuge",
    "\u26d4 Wer den NUTZER fragen darf \u2014 und wer NICHT",
    "\u26d4 Offene Deckel-Schuld",
]

# \u26d4 DAS BAND ZUR ZWEITEN QUELLE. Das Geruest steht auch in Joplin, und Joplin
#   ist von hier NICHT lesbar \u2014 kein Hook und kein Prueffall kommt an die Notiz.
#   Ein Gate dagegen ist deshalb nicht baubar; was baubar ist, ist ein ZEIGER
#   mit Stand-Datum. Wer eine der beiden Seiten aendert, sieht hier, wo die
#   andere liegt.
# \u26a0 GEMESSEN, dass das noetig ist: am 09.09.2026 wurden in \u00a710a sieben Punkte
#   geaendert, und dieses Skript zog KEINEN nach \u2014 sechs Marker, null Treffer.
#   Gefunden hat es ein Mensch beim Lesen, keine Pruefung.
QUELLE_NOTIZ = "6e27ab4e46f94884b88f56a1e7c46f27"   # Joplin `\ud83e\udded Manager-Chats`
QUELLE_ABSCHNITT = "10a"
QUELLE_STAND = "2026-09-11"

# ⭐ Die vier Saetze aus §10a. Jeder stammt aus einem Vorfall; sie werden
#   als TEILSTRING geprueft, damit Zeilenumbrueche nicht stoeren.
SAETZE = [
    ("Roster-Verweis", "manager-chats.md"),
    ("Lesen statt schreiben", "darf **lesen**, nicht schreiben"),
    ("Nur der Manager fragt", "wendet sich an den Nutzer"),
    ("Genau eine Rolle commitet", "der manager commitet nie"),
]

# Was in keiner Eigentuemer-Tabelle auftauchen soll: Ablagen des Werkzeugs
# selbst und alles, was Git ohnehin nicht fuehrt.
_UEBERGEHEN = {".git", ".claude-mind", "__pycache__", "node_modules", ".venv"}


def _bash():
    """Git Bash finden — ⛔ NIE ueber den blossen Namen.

    Windows' CreateProcess durchsucht System32 zuerst, und dort liegt WSLs
    `bash.exe`: der Aufruf scheitert mit leerer Ausgabe, was wie ein Befund
    aussieht. Dieselbe Absicherung wie in `Learnings/zaehl_gate.py`.
    """
    b = shutil.which("bash")
    if b and "System32" not in b:
        return b
    for k in (r"C:\Program Files\Git\bin\bash.exe",
              r"C:\Program Files\Git\usr\bin\bash.exe"):
        if os.path.exists(k):
            return k
    return None


def memory_pfad(projekt, plugin_root=None):
    """`~/.claude/projects/<slug>/memory` — ueber `hash_project_dir` aus lib.sh.

    ⛔ DER SLUG WIRD NICHT NACHGEBAUT. `hash_project_dir` ist das Original,
       `slug_regression.py` prueft es mit 12 Vektoren. Ein zweiter Erzeuger
       hiesse: zwei Messungen, und niemand weiss welche gilt.
    ⚠ Ist die Wurzel nicht erreichbar, kommt ein PLATZHALTER zurueck — kein
      geratener Pfad. Ein falscher Pfad hier ist genau Ausfuellfehler 1.
    """
    root = plugin_root or os.environ.get("CLAUDE_PLUGIN_ROOT", "")
    lib = os.path.join(root, "hooks", "lib.sh") if root else ""
    b = _bash()
    if not (lib and os.path.isfile(lib) and b):
        return None
    try:
        r = subprocess.run(
            [b, "-c", 'source "$1"; hash_project_dir "$2"', "_", lib, projekt],
            capture_output=True, timeout=30)
        slug = r.stdout.decode("utf-8", "replace").strip().split("\n")[-1].strip()
        if slug and "/" not in slug and len(slug) < 200:
            return "~/.claude/projects/%s/memory/" % slug
    except Exception:
        return None
    return None


def bestand(projekt):
    """Die Verzeichnisse oberster Ebene, die es WIRKLICH gibt."""
    try:
        namen = sorted(os.listdir(projekt))
    except OSError:
        return []
    return [n for n in namen
            if n not in _UEBERGEHEN
            and not n.startswith(".claude-mind")
            and os.path.isdir(os.path.join(projekt, n))]


# ⛔ Was einen Unterordner zu einem EIGENEN Arbeitsplatz macht. Dieselben drei
#   Marken, an denen `mind_projekt_wurzel` (lib.sh, v5.80.0) und der Sampler den
#   Aufbau erkennen — ein vierter Erkenner hier hiesse: zwei Messungen.
_KONTEXT_MARKEN = (".claude", ".claude-mind", "CLAUDE.md")


def unterordner(projekt):
    """Die Unterordner mit EIGENEM Kontext — der Unterordner-Aufbau, gemessen.

    -> Liste der Namen (relativ zur Wurzel), leer = kein Unterordner-Aufbau.
    ⚠ Nur oberste Ebene. Ein `.claude/` zwei Ebenen tiefer ist ein eigenes
      Projekt, kein Arbeitsplatz dieses Rosters.
    """
    raus = []
    for d in bestand(projekt):
        p = os.path.join(projekt, d)
        if any(os.path.exists(os.path.join(p, m)) for m in _KONTEXT_MARKEN):
            raus.append(d)
    return raus


def werkzeuge(plugin_root=None):
    """Die projektweiten Commands — aus dem INSTALLIERTEN Paket gelesen.

    ⚠ Nicht aus einer festen Liste: sie veraltet lautlos, und genau diese
      Klasse hat dieses Projekt sechsmal getroffen.
    """
    root = plugin_root or os.environ.get("CLAUDE_PLUGIN_ROOT", "")
    d = os.path.join(root, "skills") if root else ""
    if not (d and os.path.isdir(d)):
        return []
    raus = []
    for n in sorted(os.listdir(d)):
        if n.startswith("mind-") and os.path.isdir(os.path.join(d, n)):
            raus.append("/" + n)
    return raus


def geruest(projekt, plugin_root=None, rollen=3):
    """Das Geruest nach §10a — Platzhalter bleiben Platzhalter."""
    name = os.path.basename(os.path.abspath(projekt.rstrip("/\\")))
    dirs = bestand(projekt)
    uo = unterordner(projekt)
    mem = memory_pfad(projekt, plugin_root)
    wz = werkzeuge(plugin_root)

    z = []
    a = z.append
    a("---")
    a("description: Der Roster dieses Projekts \u2014 wer ist <Name1>, <Name2>, "
      "wem geh\u00f6rt welche Datei")
    # v5.119.0: KEIN globs:/paths: — der Roster laedt bei jedem Start; globs: war das
    # Cursor-Feld und filterte nie (Etappe 27 §1). Die Kommentarzeile sagt es dem Leser.
    a('# laedt bei jedem Start \u2014 bewusst kein paths: (globs: filterte nie)')
    a("---")
    a("# Rollen \u2014 dieses Projekt l\u00e4uft mit %d Sitzungen" % rollen)
    a("")
    a("\u26d4 **Diese Datei ist der ROSTER.** Wie Rollen sich verhalten \u2014 "
      "adressieren, berichten,")
    a("Freigaben, Widerspruchspflicht, wer die projektweiten Werkzeuge "
      "f\u00e4hrt \u2014 steht in")
    a("`~/.claude/rules/manager-chats.md` und l\u00e4dt \u00fcberall. **Hier "
      "stehen nur die Namen, der")
    a("Dateibesitz und was NUR hier gilt.**")
    a("")
    # \u2b50 Die sessionId-Spalte kam aus dem ZWEITEN Aufbau (Palvedo, 09.09.2026):
    #   Namen aendern sich, Auto-Namen wandern, Titel werden umbenannt \u2014 die
    #   sessionId bleibt.
    # \u26a0 Sie ist zugleich die EINZIGE fluechtige Angabe der Datei: eine ERSETZTE
    #   Sitzung bekommt eine neue Id, und die Zeile zeigt dann ins Leere.
    #   \u26d4 Genau das war am 09.09.2026 schon Stunden nach dem Eintragen der Fall
    #     \u2014 eine von drei Zeilen verwies auf eine Id ohne Transkript. Deshalb
    #     prueft `--pruefe` sie gegen die Wirklichkeit, statt ihr zu glauben.
    # \u26d4 `<uuid>`, nicht `local_\u2026` (\u00a710a, 11.09.2026): Spalte 3 liest das
    #   Rollen-Gate, und es vergleicht mit der BLANKEN Kennung aus dem Hook-Input.
    #   Ein Platzhalter in der falschen Form leitet den Nutzer in die falsche
    #   Spalte \u2014 am 10.09.2026 stand `local_\u2026` in einem echten Roster, und das
    #   Gate fand keinen der drei.
    # \u2b50 Unterordner-Aufbau: fuenfte Spalte `Ordner`, Pflicht, relativ zur
    #   Wurzel. Sie wird nur angelegt, wenn der Bestand einen solchen Aufbau
    #   zeigt \u2014 sonst bleibt die Tabelle byteweise vierspaltig.
    o5 = " <Ordner>/ |" if uo else ""
    a("| Rolle | Name | sessionId | Tut |%s" % (" Ordner |" if uo else ""))
    a("|---|---|---|---|%s" % ("---|" if uo else ""))
    a("| **manager** | **<Name>** | `<uuid>` | liest, beauftragt, "
      "pr\u00fcft nach. \u26d4 **Schreibt keinen Code** |%s" % o5)
    a("| **arbeiter** | **<Name>** | `<uuid>` | baut, misst, commitet |%s" % o5)
    a("| **sync** | **<Name>** | `<uuid>` | f\u00e4hrt die projektweiten "
      "Werkzeuge. \u26d4 **Baut nichts, entscheidet nichts** |%s" % o5)
    a("")
    a("\u26d4 **Spalte 3 ist die BLANKE UUID aus `echo \"$CLAUDE_CODE_SESSION_ID\"` "
      "\u2014 NIE die `local_\u2026`-Form aus")
    a("`list_sessions`.** Zwei getrennte Namensr\u00e4ume; `local_\u2026` braucht man "
      "nur zum Anschreiben")
    a("(`send_message`), nie im Roster.")
    a("")
    if uo:
        a("\u26a0 **Unterordner-Aufbau** \u2014 gemessen: %d Unterordner mit eigenem "
          "Kontext (%s)." % (len(uo), " \u00b7 ".join("`%s/`" % u for u in uo)))
        a("Die Spalte `Ordner` ist hier **Pflicht**, relativ zur Wurzel: je Rolle "
          "den Ordner eintragen, in dem")
        a("die Sitzung l\u00e4uft. Ohne sie wei\u00df weder Sync noch Manager, wo eine "
          "Sitzung lebt.")
        a("")
    a("Titel: `<Rollen-Emoji> <Vorname> \u00b7 <Rolle> \u00b7 %s` \u2014 "
      "\U0001f9ed manager \u00b7 \U0001f527 arbeiter \u00b7 \U0001f9e0 sync." % name)
    a("\u26a0 Bist du keine dieser Rollen, gilt diese Datei nicht \u2014 normal "
      "weiterarbeiten.")
    a("")
    a("\u26d4 **Nach Neustart, Fortsetzung oder Leeren ZUERST <Datei> und <Datei> lesen** "
      "(laden NICHT mit).")
    a("Ohne sie kennt eine frische Sitzung ihre Rolle, aber nicht ihren Auftrag.")
    a("")
    a("## Wem welche Datei geh\u00f6rt")
    a("")
    a("| Bereich | Eigent\u00fcmer |")
    a("|---|---|")
    for d in dirs:
        a("| `%s/**` | **<Name>** |" % d)
    # \u2b50 Feste Zeilen aus \u00a710a \u2014 sie stehen in JEDEM Roster gleich, weil jede
    #   einzelne aus einem Vorfall stammt.
    a("| `CLAUDE.md` | **<arbeiter>** |")
    a("| `.claude/rules/**` (au\u00dfer dieser Datei) | **<arbeiter>** |")
    a("| `.claude/rules/rollen.md` | **<manager>** |")
    if mem:
        a("| `.claude-mind/**`, `%s` \u2014 **wenn ein Werkzeug sie schreibt** | "
          "**<sync>** |" % mem)
    else:
        a("| `.claude-mind/**`, `~/.claude/projects/<slug>/memory/**` \u2014 "
          "**wenn ein Werkzeug sie schreibt** | **<sync>** "
          "\u26a0 Slug nicht aufgel\u00f6st, bitte eintragen |")
    # \u26d4 ZWEI \u201eniemand\"-Werte, und sie sind keine Alternativen, sondern zwei
    #   ACHSEN: gesperrt sein UND von einem Werkzeug befuellt werden geht
    #   gleichzeitig. Wer daraus zwei ZEILEN macht, erzeugt genau den Zustand,
    #   den \u201eein Pfad, ein Eigentuemer" verhindern soll \u2014 unentschieden statt
    #   doppelt geschuetzt. Beide Angaben gehoeren in DIESELBE Zelle.
    a("| `<pfad, den nur ein Werkzeug f\u00fcllt>` | \u26d4 **niemand von Hand** \u2014 "
      "schreibt `<werkzeug>` |")
    a("| `<pfad mit Nutzerdaten>` | \u26d4 **niemand \u2014 gesperrt**, weil `<grund>` |")
    a("| `git add` / `git commit` | **<Name>** \u2014 \u26d4 der manager "
      "commitet nie |")
    a("")
    a("Der jeweils andere darf **lesen**, nicht schreiben. \u00c4nderungswunsch: "
      "melden, nicht tun.")
    a("")
    a("## Die projektweiten Werkzeuge")
    a("")
    a("`%s`" % (" \u00b7 ".join(wz) if wz else "<liste>"))
    a("")
    # v5.157.0 (Etappe 61): „welcher Kontextstand welchen Fan-out ergibt“ zeigte ins Leere
    #   (die Regel gibt es nicht mehr) und stand in 4 von 4 Rostern — sie kamen von hier.
    a("**Absprache:** nur wenn die anderen idle sind. Warum: `manager-chats.md` \u2192 Limits.")
    a("")
    a("## \u26d4 Wer den NUTZER fragen darf \u2014 und wer NICHT")
    a("")
    a("\u26d4 **Nur <Manager-Name> wendet sich an den Nutzer.** Alle anderen "
      "fragen ihn \u2014 auch bei")
    a("Uneinigkeit, auch wenn die Frage dringend wirkt, auch wenn sie ihn "
      "selbst betrifft.")
    # v5.157.0: „fragt nur im Notfall“ ohne die vier Faelle stand in 3 Rostern (Pruefliste c).
    a("\u26d4 **Und er fragt nur in einem von vier Notf\u00e4llen** (`manager-chats.md`): "
      "Freigabe-Dialog \u00b7")
    a("unumkehrbarer Verlust (kein Weg zur\u00fcck) \u00b7 beide Wege zerst\u00f6ren Arbeit \u00b7 "
      "eine Messung widerspricht")
    a("dem erkl\u00e4rten ZIEL des Nutzers. Alles andere entscheidet er selbst.")
    a("\u26a0 **Die eine Ausnahme:** ein **Freigabe-Dialog** \u00f6ffnet sich "
      "beim Ausf\u00fchrenden und kann nur")
    a("dort beantwortet werden. Das ist kein Fragen, das ist der Mechanismus.")
    a("\u2b50 **Widerspruch bleibt PFLICHT** \u2014 er wird nicht leiser, nur "
      "richtig adressiert.")
    a("")
    a("| Lage | An wen |")
    a("|---|---|")
    a("| hart blockiert | **<Manager>** |")
    a("| zwei Wege m\u00f6glich, beide vertretbar | **<Manager>** |")
    a("| eine Messung widerspricht der Doku | **<Manager>** |")
    a("| **Freigabe-Dialog** (l\u00f6schen, Plan anwenden, Push) | "
      "\u26d4 **NUR der Nutzer** |")
    # v5.157.0 (Pruefliste b): der manager entscheidet und NENNT es (manager-chats.md).
    a("| \u00c4nderung, die bestehendes Verhalten ersetzt | **<Manager>** entscheidet "
      "und **nennt** es im Bericht |")
    a("")
    a("## \u26d4 Offene Deckel-Schuld")
    a("")
    # \u26d4 Der REGELTEXT steht seit dem 09.09.2026 global in
    #   `~/.claude/rules/kontext-anlegen.md` (seit 29.10.2026 `context-saving.md`) und NICHT mehr hier. Vorher stand
    #   er in zwei Rostern und null globalen Regeln; als er korrigiert wurde,
    #   zog nur eine Kopie nach, und beide Dateien meldeten fuer sich gruen.
    # v5.157.0: `kontext-anlegen.md` gibt es seit 29.10.2026 nicht mehr — die Deckel-Regel steht
    #   in `context-saving.md`, Abschnitt „Always-loaded context“.
    a("Die **Regel** steht global in `~/.claude/rules/context-saving.md` "
      "(\u201eAlways-loaded context\u201c) \u2014 wer anlegt, zahlt aus")
    a("dem Bestand; wer nichts zu streichen findet, weist die Schuld aus. "
      "\u26d4 **Hier steht nur die")
    a("Schuld DIESES Projekts**, sonst nichts:")
    a("")
    a("```")
    a("(keine)")
    a("```")
    a("")
    a("\u26d4 **Der Ausweis geh\u00f6rt in DIESE Datei, nicht in eine Antwort.** Nur "
      "gesagt ist er beim")
    a("n\u00e4chsten Sitzungsstart weg \u2014 dann ist die Schuld getilgt, ohne dass "
      "jemand sie getilgt hat.")
    a("\u2b50 Ist nichts offen: `(keine)`. Eine leere \u00dcberschrift ist kein Ausweis.")
    a("")
    a("> Herleitung und Vorf\u00e4lle: `<archiv-datei>` (l\u00e4dt nicht mit).")
    return "\n".join(z) + "\n"


_UMLAUT = [("ä", "ae"), ("ö", "oe"), ("ü", "ue"),
           ("Ä", "Ae"), ("Ö", "Oe"), ("Ü", "Ue"),
           ("ß", "ss")]


def _normal(s):
    """Umlaute vereinheitlichen, sonst NICHTS anfassen.

    ⛔ GEFUNDEN AN ECHTEM MATERIAL, 09.09.2026. Die erste Fassung verglich
       buchstaeblich und meldete `Wem welche Datei gehoert` als "umbenannt",
       weil §10a `gehört` schreibt. Das ist DIESELBE Ueberschrift — dieses
       Projekt transliteriert Umlaute absichtlich (Windows, cp1252, Git Bash).
    ⚠ Ein Pruefer, der eine Schreibkonvention fuer eine Umbenennung haelt,
      erzeugt in jedem ASCII-schreibenden Projekt einen Fehlalarm. Bindestriche,
      Woerter und Reihenfolge bleiben streng — nur die Umlaute sind tolerant.
    """
    for a, b in _UMLAUT:
        s = s.replace(a, b)
    return s


def ueberschriften(text):
    return [m.group(1).strip()
            for m in re.finditer(r"^##\s+(.+?)\s*$", text, re.M)]


# ⛔⛔ HIER STAND EINE PRUEFUNG `sitzungen_pruefen()`. SIE IST FALSCH UND WIRD
#    NICHT WIEDER GEBAUT. Eingebaut und widerlegt am selben Tag, 09.09.2026.
#
# SIE GLICH JEDE `sessionId` GEGEN DIE TRANSKRIPTNAMEN unter
# `~/.claude/projects/<slug>/*.jsonl` ab. Gemessen im eigenen Projekt:
#
#     acd4e029-…  (manager)   Transkript da     Id == Transkriptname
#     61d97508-…  (sync)      Transkript da     Id == Transkriptname
#     a02a245a-…  (arbeiter)  KEIN Transkript   Id != Transkriptname
#                             ... und diese Id ist NACHWEISLICH ERREICHBAR:
#                             ueber sie kam ein halbes Dutzend Nachrichten an.
#
# ⛔ DIE PRUEFUNG HAETTE ALSO EINE FUNKTIONIERENDE ADRESSE ALS TOT GEMELDET —
#    und zwar die des Arbeiters, also die meistbenutzte. Wird eine Sitzung
#    fortgesetzt oder geforkt, behaelt die Datei ihren Namen und die Sitzung
#    bekommt eine neue Id. Ein Pruefer gegen Transkriptnamen meldet damit ROT
#    fuer jede fortgesetzte Sitzung.
#
# ⭐ MEIN DENKFEHLER WAR DER SCHAERFERE TEIL, und er steht hier, damit ihn
#    niemand wiederholt: `list_sessions` SCHLIESST DIE EIGENE SITZUNG AUS —
#    das steht in seiner Werkzeugbeschreibung. Dass `a02a245a` in meiner
#    Auflistung fehlte, war der **Beleg, dass ich es selbst bin**. Ich habe ihn
#    als Beleg fuer das Gegenteil gelesen und darauf ein Werkzeug gebaut.
#    ⚠ Klasse `instrument-meldet-falsch`: die Messung stimmte, die Auslegung
#      nicht. Das Fail-safe fing den AUSFALL und nicht den FEHLTREFFER.
#
# ⛔ WAS WIRKLICH MISST, und warum es hier nicht geht:
#    1. `list_sessions` ist die Registry — aber ein MCP-Werkzeug, fuer ein
#       `references/*.py` unerreichbar. Dieselbe Lage wie bei Joplin.
#    2. Der ZUSTELLVERSUCH ist die haerteste Pruefung und kann kein Skript
#       fahren.
#    ⭐ Also gibt es hier KEINE mechanische Pruefung. Das ist das Ergebnis,
#      nicht eine offene Aufgabe — und ein Pruefer, der seine Gegenseite nicht
#      lesen kann, ist `instrument-misst-nichts`.


_ROLLEN = ("manager", "arbeiter", "sync")


def _zelle(zeile, n):
    """Zelle n einer Markdown-Tabellenzeile, normalisiert und klein."""
    teile = zeile.split("|")
    if len(teile) <= n:
        return ""
    return (teile[n].replace("*", "").replace("`", "")
            .strip().lower())


def _platzhalter(s):
    """Ist die Zelle noch ein Platzhalter aus dem Geruest?

    ⛔ GEMESSEN AM EIGENEN ERZEUGNIS, nicht angenommen: `geruest()` schreibt
       `**<Name>**`, `` `<uuid>` `` und `<Ordner>/`. Eine Zelle ist also unausgefuellt,
       wenn sie spitze Klammern oder Auslassungspunkte traegt — nicht, wenn sie
       leer ist. Die erste Fassung dieses Melders nahm "leer" an und schwaerzte
       damit JEDES frisch erzeugte Roster an.
    """
    if not s:
        return True
    return ("<" in s) or (">" in s) or ("\u2026" in s) or ("..." in s)


def kennung_gueltig(k):
    """Sieht die Zelle wie eine sessionId aus? — FORM, nicht Existenz.

    ⛔ Bewusst dieselbe Regel wie `_mind_kennung_gueltig` in `hooks/lib.sh`:
       mindestens 8 Zeichen, nur Kennungszeichen. Weicht sie ab, meldet das
       Geruest gruen fuer einen Roster, den das Gate nicht lesen kann.
    """
    if not k or len(k) < 8:
        return False
    for c in k:
        if not (c.isascii() and (c.isalnum() or c in "_-")):
            return False
    return True


def kennungen_pruefen(text):
    """Traegt die Rollentabelle Kennungen, mit denen das Gate arbeiten kann?

    -> (befunde, hinweise)

    ⛔ KEINE Aussage darueber, ob eine Sitzung LEBT. Das kann hier niemand
       messen (siehe Ratschen-Block), und es zu versuchen war der Fehler vom
       09.09.2026.

    ⛔ EIN LEERES GERUEST IST KEIN BEFUND, und dieser Satz ist der Grund,
       warum der Positivfall im Selbsttest tragend ist. Die erste Fassung
       meldete das frisch erzeugte Geruest als kaputt — also JEDES neu
       angelegte Roster. Gefunden hat es Fall 1, nicht das Nachlesen.
    ⭐ Die Trennlinie ist der NAME: steht in Spalte 2 keiner, ist die Zeile
       noch nicht ausgefuellt und schweigt. Steht einer und die Kennung fehlt,
       hat jemand den Roster befuellt und Spalte 3 vergessen.
    """
    B, H = [], []
    gesehen = {}
    for z in text.splitlines():
        if not z.lstrip().startswith("|"):
            continue
        rolle = _zelle(z, 1)
        if rolle not in _ROLLEN:
            continue
        name = _zelle(z, 2)
        kenn = _zelle(z, 3)
        if _platzhalter(name) and _platzhalter(kenn):
            continue          # unausgefuelltes Geruest — dazu wird nichts gesagt
        gesehen[rolle] = (not _platzhalter(kenn)) and kennung_gueltig(kenn)
        # ⛔ Die FALSCHE FORM ist der belegte Fall (10.09.2026): drei Zeilen mit
        #   `local_…`, formal gueltig, und das Gate fand keine. `kennung_gueltig`
        #   sieht das nicht — die Form ist lang genug und besteht aus
        #   Kennungszeichen. Deshalb hier, benannt.
        if kenn.startswith("local_"):
            B.append("%s traegt in Spalte 3 die `local_…`-Form aus `list_sessions` "
                     "— das Rollen-Gate vergleicht mit der BLANKEN UUID aus "
                     "`$CLAUDE_CODE_SESSION_ID` und findet diese Sitzung nie" % rolle)

    if not gesehen:
        return B, H

    if "sync" not in gesehen:
        H.append("keine ausgefuellte sync-Zeile — das Rollen-Gate legt "
                 "niemanden still, Mahnung und Zwang laufen wie in einem "
                 "Einzelprojekt (zulaessig)")
    elif not gesehen["sync"]:
        B.append("die sync-Zeile hat einen Namen, aber KEINE Kennung in "
                 "Spalte 3 — das Rollen-Gate (v5.54.0) findet damit keinen "
                 "Zustaendigen und mahnt weiter in JEDER Sitzung")

    for r in ("manager", "arbeiter"):
        if r in gesehen and not gesehen[r]:
            H.append("%s hat einen Namen, aber keine Kennung — diese Sitzung "
                     "wird nie stillgelegt, auch wenn eine sync-Zeile da ist" % r)

    # ⚠ KEINE Doppelpruefung auf gleiche Kennungen in zwei Zeilen. Sie waere
    #   billig und faende nichts: zwei Rollen mit derselben Id sind ein
    #   Tippfehler, den der Zustellversuch sofort zeigt — und der Melder haette
    #   keinen einzigen belegten Fall. `negativbefund-ist-ein-ergebnis`.
    return B, H

def _zellen(zeile):
    """Die Zellen einer Tabellenzeile, roh (ohne aeussere Pipes)."""
    return zeile.strip().strip("|").split("|")


def spalten_pruefen(text, uo=None, projekt=None):
    """Vier oder fuenf Spalten — passt die Tabelle zum Aufbau? (befunde, hinweise)

    uo = Liste der Unterordner mit eigenem Kontext, `None` = unbekannt (dann
    wird nur die Form der Tabelle geprueft, nicht ihr Verhaeltnis zum Bestand).

    | Tabelle   | Bestand            | Ergebnis |
    |-----------|--------------------|----------|
    | 5 Spalten | kein Unterordner   | Hinweis  |
    | 4 Spalten | Unterordner-Aufbau | ⛔ BEFUND |
    | 5 Spalten, 5. heisst nicht `Ordner` | — | ⛔ BEFUND (umbenannt) |
    | Ordner-Zelle nennt einen Ordner, den es nicht gibt | — | ⛔ BEFUND (Ausfuellfehler 1) |
    """
    B, H = [], []
    kopf = None
    zeilen = text.splitlines()
    for i, z in enumerate(zeilen):
        if z.lstrip().startswith("|") and _zelle(z, 1) == "rolle":
            kopf = i
            break
    if kopf is None:
        return B, H
    # ⛔ v5.145.0 (Etappe 55 §6b, Veras Befund M-G, Zustellplan 12.10.2026): DIE SPALTE `Ordner`
    #    WIRD AN IHRER UEBERSCHRIFT ERKANNT, NICHT AN DER SPALTENZAHL. Bis v5.144.0 galt „fuenf
    #    Spalten = die fuenfte ist `Ordner`". Veras gesunder Roster `Rolle | Name | sessionId |
    #    Kennung belegt | Tut` ergab vier Befunde, alle Fehlalarm: die Taetigkeitstexte wurden als
    #    Ordnernamen gesucht. Der vorgeschriebene Fix (Spalte umbenennen) waere falsch gewesen.
    #    ⚠ Unser eigener Roster hat vier Spalten — darum fiel es hier nie auf.
    kz = [_normal(c.strip().lower()) for c in _zellen(zeilen[kopf])]
    n = len(kz)
    if n < 4:
        B.append("die Rollentabelle hat %d Spalten, §10a verlangt mindestens vier" % n)
        return B, H
    oi = kz.index("ordner") if "ordner" in kz else None
    if oi is None:
        if uo:
            B.append("Unterordner-Aufbau gemessen (%s), aber die Rollentabelle hat "
                     "keine Spalte `Ordner` — weder Sync noch Manager wissen, wo "
                     "eine Sitzung lebt%s" % (" · ".join("`%s/`" % u for u in uo),
                     # ⚠ Mehr als vier Spalten, keine heisst `Ordner`: vermutlich UMBENANNT —
                     #   das sagte die Meldung bis v5.144.0 (dann ohne Aufbau-Bedingung).
                     " — umbenannt?" if n >= 5 else ""))
    elif uo is not None and not uo:
        H.append("Spalte `Ordner` vorhanden, aber kein Unterordner mit eigenem Kontext "
                 "gemessen — hier nicht noetig (zulaessig)")

    if oi is not None:
        for z in zeilen[kopf + 2:]:
            if not z.lstrip().startswith("|"):
                break
            if _zelle(z, 1) not in _ROLLEN:
                continue
            name = _zelle(z, 2)
            ordner = _zellen(z)[oi].strip().replace("`", "") if len(_zellen(z)) > oi else ""
            if _platzhalter(name):
                continue
            if _platzhalter(ordner):
                if uo:
                    B.append("%s hat einen Namen, aber keinen Ordner in Spalte 5 "
                             "— im Unterordner-Aufbau ist sie Pflicht" % _zelle(z, 1))
                continue
            if projekt and not os.path.isdir(os.path.join(projekt, ordner.rstrip("/\\"))):
                B.append("%s: Ordner %r gibt es unter der Wurzel nicht "
                         "(Ausfuellfehler 1)" % (_zelle(z, 1), ordner))
    return B, H


# ---------------------------------------------------------------------------
# v5.157.0 (Etappe 61): der Roster ist kein NOTIZHEFT, und er wiederholt keine widerlegte Regel.
# Vorlage ist die Pruefliste a–m der Update-Vorlage (Joplin `4ccf1cf8333543269a6ed1a64784f437`).
# ⛔ Gebaut wurde NUR, was an den fuenf echten Rostern (28./29.10.2026) einen echten Treffer hatte
#    (`Learnings/roster_messung.py`): b 3/5 · c 3/5 · d 1/5 · e 1/5 · f 2/5 · g 1/5 · h 3/5 · m 4/5 ·
#    Notizheft 4/5. NICHT gebaut, Trefferquote 0 oder nur Fehlalarm: a (Zeiger auf den Fan-out —
#    im Bestand schon weg, die Quelle war dieses Geruest, behoben), i (Kennungs-Erklaerung), j
#    (Pfad doppelt: 6 Treffer, alle Ordner-Praefixe oder Erwaehnungen), k (der einzige Fall ist
#    eine begruendete lokale Ausnahme, Buerokratie), „Spalte 3 mit Zusatz“ (0; die `local_…`-Form
#    meldet `kennungen_pruefen` schon).
# ⭐ Zeilen der Deckel-TABELLE beschreiben fruehere Aenderungen („`backup-before-delete.md` →
#    `file-handling.md`“) — sie sind kein Zeiger und keine Regel. Sie prueft nur der Betrag (h).
# ⛔ Nur MELDEN. Der Roster gehoert dem manager.
# ---------------------------------------------------------------------------
_WIDERLEGT = [
    ("b", re.compile(r"Verhalten ersetzt.*nur der nutzer", re.I),
     "„Änderung, die bestehendes Verhalten ersetzt | NUR der Nutzer“ — der manager entscheidet "
     "und NENNT es im Bericht (`manager-chats.md`)"),
    ("d", re.compile(r"frei (miteinander )?reden|reden frei|schreiben einander", re.I),
     "Kollegen „reden frei“ — Nachrichten nur nach `manager-chats.md` → Messages, eine Zeile"),
    ("e", re.compile(r"VOR- und NACH-Meldung|meldet beim ersten Start", re.I),
     "VOR-Meldung als Nachricht — VOR gehoert in die Auftragsdatei, nur `NACH` ist eine Nachricht"),
    ("f", re.compile(r"wandert bei jedem Neustart|local_\S*\W+wandert|"
                     r"(sessionId|Kennung)\W+wechselt beim Neustart", re.I),
     "„`local_…` wandert / sessionId wechselt beim Neustart“ — widerlegt: die UUID wechselt bei "
     "Fortsetzung und Leeren, nicht bei `/compact`; `local_…` bleibt stabil"),
    ("g", re.compile(r"manager kompaktiert|kompaktier\w*\W+(nur|erst),? wenn|"
                     r"wenn (seine|die|ihre) Aufgabe abgeschlossen|nur nach Abschluss", re.I),
     "Kompaktier-Regel im Roster („nur nach Abschluss“, „manager kompaktiert“) — die App "
     "kompaktiert ueber die Grenze, selbst kompaktieren darf jeder Chat, wann er will"),
]
_NOTFALL = re.compile(r"fragt nur im Notfall", re.I)
# Die vier Notfaelle gelten als ausgeschrieben, wenn der unumkehrbare Verlust dasteht — er ist der
# Fall, den kein anderer Satz eines Rosters zufaellig enthaelt.
_VIER = re.compile(r"irrevers|unumkehrbar|kein(en)? Weg zur(ü|ue)ck", re.I)
_NOTIZ = [
    re.compile(r"gemessen \d{1,2}\.\d{1,2}\.(\d{4})? an \w", re.I),
    re.compile(r"w(ö|oe)rtlich|Ansage w", re.I),
    re.compile(r"\bVorfall\b|schon einmal passiert", re.I),
    re.compile(r"seit \d{1,2}\.\d{1,2}\.\d{4} leer", re.I),
]
_BETRAG = re.compile(r"\d[\d \u00a0\u202f]*\s?K?B\b")
_DATUM_VORN = re.compile(r"^(\d{8}(_\d{6})?|\d{4}-\d{2}-\d{2})_")


def _archivierte_rules(home=None):
    """Namen globaler Rules, die im Archiv liegen und in `~/.claude/rules/` FEHLEN — umgezogen."""
    home = home or os.path.expanduser("~")
    da = os.path.join(home, ".claude", "rules")
    arch = os.path.join(home, ".claude", "rules-archiv")
    if not os.path.isdir(arch):
        return set()
    heute = set(os.listdir(da)) if os.path.isdir(da) else set()
    weg = set()
    for wurzel, _, dateien in os.walk(arch):
        for d in dateien:
            if d.endswith(".md"):
                n = _DATUM_VORN.sub("", d)
                if n not in heute:
                    weg.add(n)
    return weg


def notizheft_pruefen(text, projekt=None, home=None):
    """Widerlegte Regeln, tote Rule-Zeiger, Betraege im Deckel, Notizheft-Inhalt. (befunde, hinweise)

    Zeilennummern in jeder Meldung — der manager raeumt seinen Roster selbst auf.
    """
    B, H = [], []
    zeilen = text.splitlines()
    tot = _archivierte_rules(home)
    eigene = set()
    if projekt and os.path.isdir(os.path.join(projekt, ".claude", "rules")):
        eigene = set(os.listdir(os.path.join(projekt, ".claude", "rules")))
    deckel = False
    funde = {}
    betrag, notiz, zeiger = [], [], {}
    for n, z in enumerate(zeilen, 1):
        if z.startswith("#"):
            deckel = "deckel" in z.lower()
            continue
        tabelle = z.lstrip().startswith("|")
        if deckel and _BETRAG.search(z):
            betrag.append(n)
        if deckel and tabelle:
            continue
        for kurz, rx, _ in _WIDERLEGT:
            if rx.search(z):
                funde.setdefault(kurz, []).append(n)
        if _NOTFALL.search(z) and not _VIER.search(text):
            funde.setdefault("c", []).append(n)
        for name in re.findall(r"([A-Za-z0-9_-]+\.md)\b", z):
            if name in tot and name not in eigene:
                zeiger.setdefault(name, []).append(n)
        if any(rx.search(z) for rx in _NOTIZ):
            notiz.append(n)

    def zn(liste):
        return "Z. " + ", ".join(str(x) for x in liste[:6]) + (" …" if len(liste) > 6 else "")

    for kurz, _, meldung in _WIDERLEGT:
        if kurz in funde:
            B.append("widerlegte Regel (%s): %s — %s" % (kurz, meldung, zn(funde[kurz])))
    if "c" in funde:
        B.append("widerlegte Regel (c): „fragt nur im Notfall“ ohne die vier Notfaelle "
                 "(`manager-chats.md`) — %s" % zn(funde["c"]))
    for name, ns in sorted(zeiger.items()):
        B.append("toter Zeiger (m): `%s` liegt nur noch in `~/.claude/rules-archiv/` — %s"
                 % (name, zn(ns)))
    if betrag:
        B.append("Deckel mit Betraegen (h): ein Ausweis nennt Datum, Anlass und Datei, keinen "
                 "Bestandsbetrag — der Betrag wird gemessen (`mind_kontext_bilanz`) — %s" % zn(betrag))
    if notiz:
        H.append("Notizheft (l): Messbelege, Vorfaelle, woertliche Ansagen oder Ordnerzustaende im "
                 "Roster — ins Archiv verschieben, nicht loeschen (`manager-chats.md`, „The roster is "
                 "not a notebook“) — %s" % zn(notiz))
    return B, H


def pruefe(text, projekt=None):
    """Pruefung 8: Abschnittsfolge und Saetze. (befunde, hinweise)

    projekt = Wurzel, falls bekannt — dann wird der Unterordner-Aufbau des
    Bestands gegen die Spaltenzahl der Rollentabelle gehalten.

    ⭐ WEGLASSEN IST ERLAUBT. Geprueft wird, dass die vorhandenen Abschnitte
       in der Reihenfolge von §10a stehen und woertlich so heissen — nicht,
       dass alle da sind. Ein Projekt ohne projektweite Werkzeuge soll den
       Abschnitt weglassen duerfen, ohne rot zu werden.
    """
    B, H = [], []
    soll = [_normal(u) for u in ABSCHNITTE]
    gefunden = ueberschriften(text)
    bekannt = [u for u in gefunden if _normal(u) in soll]
    fremd = [u for u in gefunden if _normal(u) not in soll]
    fehlend = [ABSCHNITTE[i] for i, u in enumerate(soll)
               if u not in [_normal(x) for x in bekannt]]

    # Reihenfolge: die bekannten muessen aufsteigend in ABSCHNITTE liegen.
    idx = [soll.index(_normal(u)) for u in bekannt]
    if idx != sorted(idx):
        B.append("Abschnitte stehen in falscher Reihenfolge: %s"
                 % " \u2192 ".join(bekannt))

    # \u2b50 EIN FREMDER ABSCHNITT IST NICHT PER SE EIN FEHLER. \u00a710a verbietet
    #   Umbenennen und Umstellen \u2014 nicht ERGAENZEN. `rollen.md` soll sogar
    #   aufnehmen, "was NUR hier gilt".
    # \u26d4 Aber: eine UMBENANNTE Ueberschrift sieht von aussen genau wie eine
    #   hinzugefuegte aus. Der Unterschied ist mechanisch nur daran zu sehen,
    #   ob dafuer ein Pflichtabschnitt FEHLT. Also:
    #     fehlt einer  -> jeder fremde ist verdaechtig  -> BEFUND
    #     fehlt keiner -> die fremden sind Zugaben      -> Hinweis
    # \u26d4 HINZUFUEGEN ist erlaubt, DAZWISCHENSCHIEBEN nicht (\u00a710a, 09.09.2026).
    #   Ein neuer Abschnitt HINTER dem letzten Pflichtabschnitt ist eine Zugabe;
    #   einer ZWISCHEN zweien zerreisst die Folge, an der man den Roster in
    #   jedem Projekt an derselben Stelle findet.
    letzter = -1
    for i, u in enumerate(gefunden):
        if _normal(u) in soll:
            letzter = i
    for i, u in enumerate(gefunden):
        if _normal(u) in soll:
            continue
        if fehlend:
            B.append("Ueberschrift steht nicht in \u00a710a und ein "
                     "Pflichtabschnitt fehlt \u2014 umbenannt? %r" % u)
        elif i < letzter:
            B.append("Abschnitt DAZWISCHENGESCHOBEN \u2014 erlaubt ist nur "
                     "Anhaengen: %r" % u)
        else:
            H.append("projekteigener Abschnitt (erlaubt): %r" % u)
    for u in fehlend:
        H.append("Abschnitt fehlt (Weglassen ist erlaubt): %r" % u)

    # ⛔ KEINE sessionId-Pruefung, die eine Id gegen die WIRKLICHKEIT haelt.
    #    Begruendung im Ratschen-Block oberhalb von `pruefe`. Was hier steht,
    #    ist etwas anderes: eine FORM-Pruefung der ZELLE.
    #
    # ⭐ WARUM SIE SEIT v5.54.0 NOETIG IST. Spalte 3 war bis dahin Beschriftung.
    #    Seither liest `mind_sync_zustaendig` sie: steht in der sync-Zeile keine
    #    Kennung, findet das Rollen-Gate keinen Zustaendigen und mahnt weiter in
    #    JEDER Sitzung — also genau der Zustand, gegen den es gebaut wurde.
    #    ⚠ Das ist die richtige Fail-safe-Richtung und trotzdem eine Falle:
    #      der Aufbau sieht fertig aus und wirkt nicht.
    #
    # ⛔ DER UNTERSCHIED ZUR VERWORFENEN PRUEFUNG, in einem Satz:
    #    Hier wird gefragt "STEHT da eine Kennung?", nicht "GIBT es die Sitzung?".
    #    Die erste Frage kann ein Skript beantworten, die zweite nicht — und
    #    genau daran ist `sitzungen_pruefen()` am 09.09.2026 gescheitert.
    B2, H2 = kennungen_pruefen(text)
    B.extend(B2)
    H.extend(H2)
    uo = unterordner(projekt) if projekt else None
    B3, H3 = spalten_pruefen(text, uo, projekt)
    B.extend(B3)
    H.extend(H3)
    B4, H4 = notizheft_pruefen(text, projekt)
    B.extend(B4)
    H.extend(H4)
    for name, teil in SAETZE:
        if teil not in text:
            B.append("Pflichtsatz fehlt \u2014 %s (%r)" % (name, teil))
    return B, H


def selbsttest():
    rot = 0

    def pruef(was, ist, soll):
        nonlocal rot
        if ist == soll:
            print("  [ok ] %s" % was)
        else:
            rot += 1
            print("  [ROT] %s (erwartet %r, war %r)" % (was, soll, ist))

    hier = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(hier)
    g = geruest(root, root)

    print("=== 1) \u2b50 POSITIVKONTROLLE: das erzeugte Geruest besteht ===")
    B, H = pruefe(g)
    pruef("keine Befunde am eigenen Erzeugnis", B, [])
    pruef("und kein Abschnitt fehlt", H, [])

    print()
    print("=== 2) Die vier Pflichtsaetze stehen woertlich drin ===")
    for name, teil in SAETZE:
        pruef("Satz: %s" % name, teil in g, True)

    print()
    print("=== 3) \u26d4 NEGATIVKONTROLLE: Umbenennen und Umstellen fallen auf ===")
    umbenannt = g.replace("## \u26d4 Offene Deckel-Schuld", "## Deckel-Schuld")
    B2, _ = pruefe(umbenannt)
    pruef("umbenannte Ueberschrift wird gemeldet", len(B2) >= 1, True)

    a = "## Die projektweiten Werkzeuge"
    b = "## Wem welche Datei geh\u00f6rt"
    getauscht = g.replace(a, "@@X@@").replace(b, a).replace("@@X@@", b)
    B3, _ = pruefe(getauscht)
    pruef("vertauschte Reihenfolge wird gemeldet",
          any("Reihenfolge" in x for x in B3), True)

    fehlt = g.replace("| **manager** | **<Name>** | liest, beauftragt, "
                      "pr\u00fcft nach. \u26d4 **Schreibt keinen Code** |", "")
    B4, _ = pruefe(fehlt)
    pruef("Geruest ohne Manager-Zeile bleibt formal gueltig", B4, [])

    ohne = g.replace("der manager commitet nie", "irgendwer commitet")
    B5, _ = pruefe(ohne)
    pruef("fehlender Pflichtsatz wird gemeldet",
          any("Pflichtsatz" in x for x in B5), True)

    print()
    print("=== 4) \u2b50 WEGLASSEN ist erlaubt, und zwar still ===")
    kurz = g.split("## \u26d4 Wer den NUTZER")[0]
    B6, H6 = pruefe(kurz + "\nder manager commitet nie\nwendet sich an den Nutzer\n")
    pruef("weggelassener Abschnitt ist HINWEIS, kein Befund", B6, [])
    pruef("   ... und wird als Hinweis genannt", len(H6) >= 1, True)

    print()
    print("=== 4b) \u2b50 Schreibkonvention ist keine Umbenennung ===")
    ascii_fassung = g.replace("## Wem welche Datei geh\u00f6rt",
                              "## Wem welche Datei gehoert")
    B7, _ = pruefe(ascii_fassung)
    pruef("`gehoert` statt `geh\u00f6rt` ist KEIN Befund", B7, [])
    anders = g.replace("## Wem welche Datei geh\u00f6rt", "## Dateibesitz")
    B8, _ = pruefe(anders)
    pruef("   ... eine echte Umbenennung dagegen schon",
          any("umbenannt" in x for x in B8), True)

    print()
    print("=== 4c) \u2b50 ERGAENZEN ist erlaubt, UMBENENNEN nicht ===")
    zusatz = g + "\n## \u26d4 Agenten-Zuschnitt\n\nprojekteigen.\n"
    B9, H9 = pruefe(zusatz)
    pruef("zusaetzlicher Abschnitt bei VOLLSTAENDIGEM Geruest: kein Befund",
          B9, [])
    pruef("   ... und er wird als erlaubt gemeldet",
          any("projekteigener" in x for x in H9), True)
    luecke = zusatz.replace("## \u26d4 Offene Deckel-Schuld", "## Deckel-Schuld")
    B10, _ = pruefe(luecke)
    pruef("fehlt dagegen ein Pflichtabschnitt, wird der fremde verdaechtig",
          any("umbenannt" in x for x in B10), True)

    print()
    print("=== 5) \u26d4 Ausfuellfehler 1: nur Pfade, die es GIBT ===")
    dirs = bestand(root)
    pruef("jeder genannte Ordner existiert wirklich",
          all(os.path.isdir(os.path.join(root, d)) for d in dirs), True)
    pruef("   ... und .git ist nicht dabei", ".git" in dirs, False)
    pruef("   ... und .claude-mind auch nicht", ".claude-mind" in dirs, False)

    print()
    print("=== 6) \u26d4 Ausfuellfehler 2: der Speicher AUSSERHALB steht drin ===")
    pruef("memory-Zeile ist da",
          "/memory/" in g and "projects" in g, True)

    print()
    print("=== 7) \u26d4 Ausfuellfehler 3: Allgemeines wird VERWIESEN ===")
    pruef("zeigt auf manager-chats.md", "manager-chats.md" in g, True)
    pruef("   ... und kopiert die Widerspruchspflicht NICHT herein",
          "99,2" in g or "48,3" in g, False)

    print()
    print("=== 8) Leere Namen bleiben LEER ===")
    pruef("kein erfundener Name im Geruest", "<Name>" in g, True)

    print()
    print("=== 9) ⭐ Der Stand vom 09.09.2026 — sieben Punkte aus §10a ===")
    pruef("1 sessionId-Spalte in der Rollentabelle",
          "| Rolle | Name | sessionId | Tut |" in g, True)
    pruef("2 Titel mit Rollen-Emoji und ausgeschriebener Rolle",
          "\U0001f9ed manager" in g and "\U0001f527 arbeiter" in g, True)
    pruef("3 Abschnitt heisst `Offene Deckel-Schuld`",
          "## ⛔ Offene Deckel-Schuld" in g, True)
    pruef("   ... und der REGELTEXT ist NICHT mehr drin",
          "100 dazu, 100 weg" in g, False)
    pruef("   ... sondern ein Zeiger auf die globale Regel",
          "context-saving.md" in g, True)
    pruef("4 beide `niemand`-Werte stehen drin",
          "niemand von Hand" in g and "niemand — gesperrt" in g, True)
    pruef("5 feste Eigentuemer-Zeilen",
          all(x in g for x in ("| `CLAUDE.md` | **<arbeiter>** |",
                               "| `.claude/rules/rollen.md` | **<manager>** |")),
          True)
    pruef("7 die Quelle ist benannt, damit sie nicht driftet",
          QUELLE_NOTIZ in (__doc__ or "") or len(QUELLE_NOTIZ) == 32, True)

    print()
    print("=== 9b) ⛔ DAZWISCHENSCHIEBEN ist verboten, ANHAENGEN erlaubt ===")
    mitte = g.replace("## Die projektweiten Werkzeuge",
                      "## Eigener Abschnitt\n\ntext\n\n"
                      "## Die projektweiten Werkzeuge")
    B11, _ = pruefe(mitte)
    pruef("ein eingeschobener Abschnitt wird gemeldet",
          any("DAZWISCHENGESCHOBEN" in x for x in B11), True)
    B12, H12 = pruefe(g + "\n## Ganz hinten\n\ntext\n")
    pruef("   ... ein angehaengter NICHT", B12, [])
    pruef("   ... und er gilt als erlaubt",
          any("projekteigener" in x for x in H12), True)

    print()
    print("=== 9c) ⛔ RATSCHE: die sessionId-Pruefung darf NICHT zurueckkommen ===")
    # ⛔ Sie war am 09.09.2026 eingebaut und am selben Tag widerlegt: sie
    #   meldete eine NACHWEISLICH ERREICHBARE Adresse als tot, weil eine
    #   fortgesetzte Sitzung eine andere Id traegt als ihr Transkript.
    #   Diese Sammlung wird rot, sobald jemand sie erneut baut.
    tot = (g + "\n| **x** | **y** | "
           "`local_00000000-0000-0000-0000-000000000000` | z |\n")
    B13, H13 = pruefe(tot)
    pruef("eine unbekannte sessionId ergibt KEINEN Befund",
          any("zeigt ins Leere" in x for x in B13 + H13), False)
    quelle = io.open(os.path.abspath(__file__), encoding="utf-8").read()
    # ⛔ ZUSAMMENGESETZT, sonst findet die Ratsche SICH SELBST: der gesuchte
    #   String stuende sonst woertlich in dieser Zeile, und die Pruefung waere
    #   von der ersten Sekunde an rot. Beim ersten Lauf genau so passiert.
    pruef("   ... und die Funktion ist nicht wieder da",
          ("def " + "sitzungen_pruefen") in quelle, False)
    pruef("   ... die Begruendung steht daneben",
          "NICHT WIEDER GEBAUT" in quelle, True)

    print("=== 9d) ⛔ Spalte 3 ist seit v5.54.0 TRAGEND — die FORM wird geprueft ===")
    # ⭐ Der Unterschied zu 9c in einem Satz: dort wurde gefragt "GIBT es die
    #   Sitzung?" (unbeantwortbar), hier "STEHT da eine Kennung?" (ablesbar).
    def _tab(sync_kennung, mit_sync=True):
        z = ["| Rolle | Name | sessionId | Tut |", "|---|---|---|---|",
             "| **manager** | **Anton** | `aaaaaaaa-1111-4111-8111-111111111111` | liest |",
             "| **arbeiter** | **Nils** | `bbbbbbbb-2222-4222-8222-222222222222` | baut |"]
        if mit_sync:
            z.append("| **sync** | **Rita** | %s | faehrt |" % sync_kennung)
        return "\n".join(z)

    B14, H14 = kennungen_pruefen(_tab("`cccccccc-3333-4333-8333-333333333333`"))
    pruef("⭐ POSITIVKONTROLLE: alle drei mit Kennung -> kein Befund", B14, [])
    pruef("   ... und auch kein Hinweis", H14, [])

    B15, _ = kennungen_pruefen(_tab("—"))
    pruef("sync mit Namen, ohne Kennung -> BEFUND", len(B15), 1)
    B16, _ = kennungen_pruefen(_tab("`tbd`"))
    pruef("   ... auch bei einem zu kurzen Wert", len(B16), 1)

    B17, H17 = kennungen_pruefen(_tab("", mit_sync=False))
    pruef("⛔ gar keine sync-Zeile ist KEIN Befund", B17, [])
    pruef("   ... sondern ein Hinweis", len(H17), 1)

    # ⛔ Der Fall, der die erste Fassung gestellt hat: das frische Geruest.
    B18, H18 = kennungen_pruefen(g)
    pruef("⭐ das eigene Geruest schweigt (Platzhalter)", B18 + H18, [])

    # ⚠ Und die Gegenprobe dazu: ein AUSGEFUELLTER Name neben einem
    #   Platzhalter-Zeiger ist sehr wohl ein Befund. Ohne diesen Fall koennte
    #   `_platzhalter` alles verschlucken und der Melder waere stumm.
    halb = _tab("`<uuid>`")
    B19, _ = kennungen_pruefen(halb)
    pruef("⛔ echter Name + Platzhalter-Kennung -> BEFUND", len(B19), 1)

    # ⛔ Der belegte Fall vom 10.09.2026: formal gueltig, falscher Namensraum.
    B20, _ = kennungen_pruefen(_tab("`local_cccccccc-3333-4333-8333-333333333333`"))
    pruef("⛔ `local_…`-Form in Spalte 3 -> BEFUND (Gate liest die blanke UUID)",
          any("local_" in x for x in B20), True)
    # ⚠ Als ZELLE gesucht, nicht als Wort: der Erklaersatz im Geruest nennt
    #   `local_…` ausdruecklich als die falsche Form.
    pruef("   ... und das Geruest schreibt sie nicht mehr vor",
          "| `local_" in g, False)

    print()
    print("=== 10) ⭐ UNTERORDNER-AUFBAU: fuenfte Spalte `Ordner` (§10a, 11.09.2026) ===")
    import tempfile
    tmp = tempfile.mkdtemp(prefix="geruest_uo_")
    try:
        wz_ = os.path.join(tmp, "Creator")
        for d, marke in (("Creator Idee", ".claude"), ("Creator Mind Sync", "CLAUDE.md"),
                         ("docs", None)):
            os.makedirs(os.path.join(wz_, d))
            if marke == ".claude":
                os.makedirs(os.path.join(wz_, d, marke))
            elif marke:
                io.open(os.path.join(wz_, d, marke), "w", encoding="utf-8").write("# x\n")
        pruef("unterordner() findet genau die zwei mit Kontext",
              unterordner(wz_), ["Creator Idee", "Creator Mind Sync"])
        g5 = geruest(wz_, root)
        pruef("⭐ Kopfzeile hat fuenf Spalten, die fuenfte heisst Ordner",
              "| Rolle | Name | sessionId | Tut | Ordner |" in g5, True)
        pruef("   ... jede Rollenzeile traegt den Platzhalter `<Ordner>/`",
              g5.count("| <Ordner>/ |"), 3)
        pruef("   ... die gemessenen Unterordner stehen als Hinweis drin",
              "`Creator Idee/` \u00b7 `Creator Mind Sync/`" in g5, True)
        pruef("   ... `docs/` nicht (kein eigener Kontext)", "`docs/`" in g5, False)
        B21, H21 = pruefe(g5, wz_)
        pruef("⭐ POSITIVKONTROLLE: das fuenfspaltige Geruest besteht", B21, [])
        pruef("   ... ohne Hinweis", H21, [])

        # ⛔ Ohne Unterordner-Aufbau: vier Spalten, kein Wort von Ordnern.
        pruef("ohne Unterordner-Aufbau bleibt es bei vier Spalten",
              "| Rolle | Name | sessionId | Tut |\n" in g and "Ordner |" not in g, True)
        pruef("   ... und die Unterordner-Zeile fehlt", "Unterordner-Aufbau" in g, False)

        # ⛔ NEGATIVKONTROLLE 1: Aufbau da, Spalte fehlt -> BEFUND
        B22, _ = pruefe(g, wz_)
        pruef("⛔ vier Spalten bei gemessenem Unterordner-Aufbau -> BEFUND",
              any("keine Spalte `Ordner`" in x for x in B22), True)
        # 2: fuenf Spalten ohne Aufbau -> Hinweis, kein Befund
        B23, H23 = pruefe(g5, root)
        pruef("fuenf Spalten ohne Unterordner-Aufbau -> KEIN Befund", B23, [])
        pruef("   ... aber ein Hinweis", any("nicht noetig" in x for x in H23), True)
        # 3: fuenfte Spalte umbenannt -> BEFUND
        B24, _ = pruefe(g5.replace("| Tut | Ordner |", "| Tut | Pfad |"), wz_)
        pruef("⛔ fuenfte Spalte heisst nicht `Ordner` -> BEFUND",
              any("umbenannt" in x for x in B24), True)
        # 4: ausgefuellt, Ordner gibt es -> still; gibt es nicht -> BEFUND
        voll = g5.replace("| **sync** | **<Name>** | `<uuid>` |",
                          "| **sync** | **Nora** | `33333333-cccc-4ccc-8ccc-333333333333` |")
        voll_ok = voll.replace("entscheidet nichts** | <Ordner>/ |",
                               "entscheidet nichts** | `Creator Mind Sync/` |")
        B25, _ = pruefe(voll_ok, wz_)
        pruef("ausgefuellte Zeile mit vorhandenem Ordner -> kein Befund", B25, [])
        voll_tot = voll.replace("entscheidet nichts** | <Ordner>/ |",
                                "entscheidet nichts** | `Creator Stimme/` |")
        B26, _ = pruefe(voll_tot, wz_)
        pruef("⛔ ... mit einem Ordner, den es nicht gibt -> BEFUND (Ausfuellfehler 1)",
              any("Ausfuellfehler 1" in x for x in B26), True)
        B27, _ = pruefe(voll, wz_)
        pruef("⛔ Name da, Ordner-Zelle noch Platzhalter -> BEFUND",
              any("keinen Ordner in Spalte 5" in x for x in B27), True)
        # 5: ohne Wurzel (projekt=None) urteilt --pruefe nur ueber die FORM
        B28, H28 = pruefe(g5)
        pruef("ohne bekannte Wurzel: fuenf Spalten sind kein Befund und kein Hinweis",
              B28 + H28, [])
    finally:
        import shutil as _sh
        _sh.rmtree(tmp, ignore_errors=True)

    print()
    print("=== 11) ⭐ v5.157.0: Notizheft und widerlegte Regeln (Etappe 61) ===")
    import tempfile as _tf
    import shutil as _sh2
    fh = _tf.mkdtemp()
    try:
        os.makedirs(os.path.join(fh, ".claude", "rules"))
        os.makedirs(os.path.join(fh, ".claude", "rules-archiv", "2026-10-29_ordner"))
        io.open(os.path.join(fh, ".claude", "rules", "file-handling.md"), "w").write("x")
        io.open(os.path.join(fh, ".claude", "rules-archiv", "2026-10-29_alt-regel.md"), "w").write("x")
        io.open(os.path.join(fh, ".claude", "rules-archiv", "2026-10-29_ordner", "tief.md"), "w").write("x")
        io.open(os.path.join(fh, ".claude", "rules-archiv", "2026-10-29_file-handling.md"), "w").write("x")
        pos = {
            "b": "| Freigabe für eine Änderung, die bestehendes Verhalten ersetzt | ⛔ **NUR der Nutzer** |",
            "c": "⛔ **Und er fragt nur im Notfall.**",
            "d": "Paul und Vera dürfen frei miteinander reden.",
            "e": "Udo bekommt VOR- und NACH-Meldungen.",
            "f": "Zum Anschreiben (`send_message`, wandert bei jedem Neustart):",
            "g": "| Kompaktieren | jeder Chat **selbst, wenn seine Aufgabe abgeschlossen ist** |",
        }
        for kurz, zeile in pos.items():
            Bx, _ = notizheft_pruefen("# Rollen\n\n" + zeile + "\n", home=fh)
            pruef("%s: echte Zeile aus einem Roster -> BEFUND" % kurz,
                  any("(%s)" % kurz in x for x in Bx), True)
        Bm, _ = notizheft_pruefen("Regel in `~/.claude/rules/alt-regel.md` und `tief.md`.\n", home=fh)
        pruef("m: Rule nur im Archiv (Datumsvorsatz) -> toter Zeiger",
              any("`alt-regel.md`" in x for x in Bm), True)
        pruef("m: ... auch aus einem Archiv-UNTERORDNER", any("`tief.md`" in x for x in Bm), True)
        Bm2, _ = notizheft_pruefen("Siehe `file-handling.md`.\n", home=fh)
        pruef("⛔ m: archiviert UND noch da (alte Fassung) -> KEIN Zeiger-Befund", Bm2, [])
        Bm3, _ = notizheft_pruefen("Siehe `alt-regel.md`.\n", home=os.path.join(fh, "fehlt"))
        pruef("⛔ m: ohne Archiv urteilt niemand -> still", Bm3, [])
        dk = ("## ⛔ Offene Deckel-Schuld\n\n| Datum | Was | Bilanz | Stand |\n|---|---|---|---|\n"
              "| 29.10. | global `alt-regel.md` -> `file-handling.md`, ersetzt „Clear statt Compact“, "
              "manager kompaktiert fremden Chat | wird gemessen | OFFEN |\n")
        Bd, Hd = notizheft_pruefen(dk, home=fh)
        pruef("⛔ Deckel-TABELLENZEILE beschreibt eine Aenderung -> weder Zeiger noch Regel", Bd + Hd, [])
        Bh, _ = notizheft_pruefen(dk.replace("wird gemessen", "11 921 → 8 024 B"), home=fh)
        pruef("h: Betrag in der Deckel-Tabelle -> BEFUND", any("(h)" in x for x in Bh), True)
        Bh2, _ = notizheft_pruefen("# Arbeit\n\n| Datei | 4 KB |\n", home=fh)
        pruef("⛔ h: ein Betrag AUSSERHALB des Deckels ist kein Ausweis", Bh2, [])
        Bc, _ = notizheft_pruefen(pos["c"] + "\nVier Notfaelle: Freigabe-Dialog · unumkehrbarer Verlust …\n",
                                  home=fh)
        pruef("⛔ c: die vier Notfaelle stehen da -> still", Bc, [])
        for i, zeile in enumerate(("Leeren aendert die Kennung (gemessen 24.09.2026 an Udo).",
                                   "Nutzer-Ansage 15.09.2026, wörtlich sinngemäß: alles selbst.",
                                   "fuer Repo-Dateien (Vorfall: 5 Adressen).",
                                   "| `Kinder/**` — seit 21.09.2026 leer | **Sven** |"), 1):
            _, Hl = notizheft_pruefen(zeile + "\n", home=fh)
            pruef("l%d: Notizheft-Zeile -> Hinweis, kein Befund" % i, any("(l)" in x for x in Hl), True)
        Bn, Hn = notizheft_pruefen("Das Emoji ersetzt sie nicht, es zeigt nur das Feld.\n", home=fh)
        pruef("⛔ l: „ersetzt“ im Alltagssinn ist kein Notizheft (Fehlalarm der Messung)", Bn + Hn, [])
        g0 = geruest(root, root)
        Bg, _ = notizheft_pruefen(g0)
        pruef("⭐ das eigene Geruest traegt keine widerlegte Regel und keinen toten Zeiger", Bg, [])
    finally:
        _sh2.rmtree(fh, ignore_errors=True)
    return rot


def main():
    if "--selbsttest" in sys.argv:
        rot = selbsttest()
        print()
        print("  %s" % ("alle Selbsttests bestanden" if not rot
                        else "%d ROT" % rot))
        return 1 if rot else 0

    if "--pruefe" in sys.argv:
        i = sys.argv.index("--pruefe")
        if i + 1 >= len(sys.argv):
            print("Aufruf: --pruefe <rollen.md>", file=sys.stderr)
            return 2
        p = sys.argv[i + 1]
        if not os.path.isfile(p):
            print("\u26d4 Datei nicht gefunden: %s" % p, file=sys.stderr)
            return 2
        # Wurzel nur, wenn die Datei dort liegt, wo ein Roster liegt:
        # <wurzel>/.claude/rules/<name>.md. Sonst wird die Form allein geprueft.
        ap = os.path.abspath(p)
        wurzel = None
        if (os.path.basename(os.path.dirname(ap)) == "rules"
                and os.path.basename(os.path.dirname(os.path.dirname(ap))) == ".claude"):
            wurzel = os.path.dirname(os.path.dirname(os.path.dirname(ap)))
        B, H = pruefe(io.open(p, encoding="utf-8", errors="replace").read(), wurzel)
        for x in B:
            print("  [BEFUND]  %s" % x)
        for x in H:
            print("  [Hinweis] %s" % x)
        if not B:
            print("  Abschnittsfolge stimmt mit \u00a710a \u00fcberein.")
        return 1 if B else 0

    if "--projekt" in sys.argv:
        i = sys.argv.index("--projekt")
        if i + 1 >= len(sys.argv):
            print("Aufruf: --projekt <dir>", file=sys.stderr)
            return 2
        sys.stdout.write(geruest(sys.argv[i + 1]))
        return 0

    print((__doc__ or "").split("AUFRUF")[1].split("RUECKGABE")[0].strip(),
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
