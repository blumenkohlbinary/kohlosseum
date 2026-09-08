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

AUFRUF
    rollen_geruest.py --projekt <dir>            Geruest nach stdout
    rollen_geruest.py --pruefe <rollen.md>       Abschnittsfolge pruefen
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
    "\u26d4 Deckelregel",
]

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
    mem = memory_pfad(projekt, plugin_root)
    wz = werkzeuge(plugin_root)

    z = []
    a = z.append
    a("---")
    a("description: Der Roster dieses Projekts \u2014 wer ist <Name1>, <Name2>, "
      "wem geh\u00f6rt welche Datei")
    a('globs: ["**/*"]')
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
    a("| Rolle | Name | Tut |")
    a("|---|---|---|")
    a("| **manager** | **<Name>** | liest, beauftragt, pr\u00fcft nach. "
      "\u26d4 **Schreibt keinen Code** |")
    a("| **arbeiter** | **<Name>** | baut, misst, commitet |")
    a("| **sync** | **<Name>** | f\u00e4hrt die projektweiten Werkzeuge. "
      "\u26d4 **Baut nichts, entscheidet nichts** |")
    a("")
    a("Titelform: `<Vorname> \u00b7 %s \u00b7 <Rolle>`." % name)
    a("\u26a0 Bist du keine dieser Rollen, gilt diese Datei nicht \u2014 normal "
      "weiterarbeiten.")
    a("")
    a("\u26d4 **Nach einem Neustart ZUERST <Datei> und <Datei> lesen** "
      "(laden NICHT mit).")
    a("Ohne sie kennt eine frische Sitzung ihre Rolle, aber nicht ihren Auftrag.")
    a("")
    a("## Wem welche Datei geh\u00f6rt")
    a("")
    a("| Bereich | Eigent\u00fcmer |")
    a("|---|---|")
    for d in dirs:
        a("| `%s/**` | **<Name>** |" % d)
    if mem:
        a("| `%s` | **<Name>** | \u2b50 liegt AUSSERHALB des Projektordners" % mem)
    else:
        a("| `~/.claude/projects/<slug>/memory/` | **<Name>** | "
          "\u26a0 Slug nicht aufgel\u00f6st \u2014 `hash_project_dir` war nicht "
          "erreichbar, bitte eintragen |")
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
    a("**Absprache:** nur wenn die anderen idle sind. Warum, und welcher "
      "Kontextstand welchen")
    a("Fan-out ergibt: `manager-chats.md`.")
    a("")
    a("## \u26d4 Wer den NUTZER fragen darf \u2014 und wer NICHT")
    a("")
    a("\u26d4 **Nur <Manager-Name> wendet sich an den Nutzer.** Alle anderen "
      "fragen ihn \u2014 auch bei")
    a("Uneinigkeit, auch wenn die Frage dringend wirkt, auch wenn sie ihn "
      "selbst betrifft.")
    a("\u26d4 **Und er fragt nur im Notfall.**")
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
    a("| Freigabe f\u00fcr eine \u00c4nderung, die bestehendes Verhalten "
      "ersetzt | \u26d4 **NUR der Nutzer** |")
    a("")
    a("## \u26d4 Deckelregel")
    a("")
    a("Wer im Dauerkontext anlegt, **zahlt aus dem Bestand** \u2014 100 dazu, "
      "100 weg.")
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


def pruefe(text):
    """Pruefung 8: Abschnittsfolge und Saetze. (befunde, hinweise)

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
    for u in fremd:
        if fehlend:
            B.append("Ueberschrift steht nicht in \u00a710a und ein "
                     "Pflichtabschnitt fehlt \u2014 umbenannt? %r" % u)
        else:
            H.append("projekteigener Abschnitt (erlaubt): %r" % u)
    for u in fehlend:
        H.append("Abschnitt fehlt (Weglassen ist erlaubt): %r" % u)
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
    umbenannt = g.replace("## \u26d4 Deckelregel", "## Deckel-Regel")
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
    luecke = zusatz.replace("## \u26d4 Deckelregel", "## Deckel-Regel")
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
        B, H = pruefe(io.open(p, encoding="utf-8", errors="replace").read())
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
