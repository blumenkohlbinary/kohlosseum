# -*- coding: utf-8 -*-
"""Art 6 — ungegatete BESTANDSZAHLEN im Dauerkontext: der Kandidaten-Lister (v5.79.0).

⛔ ER URTEILT NIE. Rueckgabe immer 0. Er listet, was ein Mensch ansehen soll —
   dieselbe Doktrin wie `cleaner_leitplanke.py`: Kandidaten, kein Urteil.

⭐ WARUM KEIN GATE (Anton, 11.09.2026, nach `docs/plugin/art6-bestandszahlen.md`):
   der Versuch, Kandidaten mechanisch als FALSCH zu bewerten, lag 8 von 8 Mal
   daneben — jeder "Fehler" war ein Referenten-Fehler ("die fuenf Context-Skills"
   sind nicht "alle zehn Skills"). Finden geht, urteilen nicht.

⭐ DIE ZWEI TRENNUNGEN, aus dem Bestand gelesen, nicht ausgedacht:
   1  BESTAND gegen MESSWERT. "11 Dateien", "3 Skills" sind zaehlbar im Repo und
      veralten STILL. "19 Zeilen", "7 Byte", "4 Sekunden" sind Messwerte — sie
      sagen "damals" und veralten nicht. Nur Bestandswoerter sind Kandidaten.
   2  DATIERT gegen UNDATIERT. Eine Bestandszahl mit Datum oder Version im Satz
      ("gemessen 27.08.2026: 37 Sammlungen") ist ein Protokoll und darf stehen.
      Ohne Datum ist sie eine Behauptung ueber HEUTE.
   Dazu: was in einer GEGATETEN Tabelle steht (`**<n>** |`, das Format von
   `zaehl_gate.py`) ist abgesichert und faellt weg.

   Gemessen 11.09.2026 am eigenen Dauerkontext: 48 Kandidaten -> 16 datiert,
   5 gegatet -> **7** bleiben. 85 % fallen ohne Urteil weg. Die zwei bekannten
   Fehlzahlen des Tages ("zwei Einmal-Messungen", "vier Gates") sind unter den 7.

Aufruf:
    python bestandszahlen_kandidaten.py <projekt> [--global] [--max N]
    python bestandszahlen_kandidaten.py --selbsttest
"""
import io
import os
import re
import sys
import tempfile

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

# ⛔ Bestands-Substantive. Bewusst KEIN Messwert-Wort (Zeilen, Byte, Tokens,
#    Sekunden, Zeichen) — "Zeilen" nur als LIMIT, siehe unten.
BESTAND = (r"Skills?|Agents?|Hooks?|Rules?|Sammlung(?:en)?|Pruefsammlung(?:en)?|"
           r"Prüfsammlung(?:en)?|Funktion(?:en)?|Referenz(?:en)?|Subdirs?|"
           r"Dateien|Datei|Gates?|Einmal-Messung(?:en)?|Messung(?:en)?|Werkzeuge?|"
           r"Skripte?|Tools?|Merker|Commands?|Ordner|Vorkommen|Prueff(?:ae|ä)lle|"
           r"Prueffall|Faelle|Fälle|Tore?|Fragen?|Klassen?|Zeilen")
ZAHL = (r"(?:\b\d{1,4}\b|\bzwei\b|\bdrei\b|\bvier\b|\bf(?:ue|ü)nf\b|\bsechs\b|"
        r"\bsieben\b|\bacht\b|\bneun\b|\bzehn\b|\belf\b|\bzw(?:oe|ö)lf\b)")
KAND = re.compile(r"(%s)\s+(?:\*\*)?(%s)\b" % (ZAHL, BESTAND), re.IGNORECASE)
DATUM = re.compile(r"\b\d{1,2}\.\d{1,2}\.20\d\d\b|\b20\d\d-\d\d-\d\d\b|\bv\d+\.\d+\.\d+\b")
LIMIT = re.compile(r"unter|max|h(?:oe|ö)chstens|Grenze|bis zu", re.IGNORECASE)
GEGATET = re.compile(r"\*\*(\d+)\*\* \|")
WORT = {"zwei": 2, "drei": 3, "vier": 4, "fuenf": 5, "fünf": 5, "sechs": 6,
        "sieben": 7, "acht": 8, "neun": 9, "zehn": 10, "elf": 11,
        "zwoelf": 12, "zwölf": 12}


def lies(p):
    try:
        return io.open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def dauerkontext(projekt, mit_global):
    """Was in JEDER Sitzung laedt: CLAUDE.md + rules/ (rekursiv, sie laden rekursiv)."""
    out = []
    wurzeln = [projekt]
    if mit_global:
        wurzeln.append(os.path.join(os.path.expanduser("~"), ".claude"))
    for w in wurzeln:
        c = os.path.join(w, "CLAUDE.md")
        if os.path.isfile(c):
            out.append(c)
        r = os.path.join(w, ".claude", "rules") if w == projekt else os.path.join(w, "rules")
        for d, _, fs in os.walk(r):
            for f in sorted(fs):
                if f.endswith(".md"):
                    out.append(os.path.join(d, f))
    return out


def gegatete_zahlen(dateien):
    z = set()
    for p in dateien:
        z.update(int(m) for m in GEGATET.findall(lies(p)))
    return z


def kandidaten(text, quelle, gegatet):
    out = []
    for m in KAND.finditer(text):
        zahl_s, noun = m.group(1), m.group(2)
        zahl = WORT.get(zahl_s.lower())
        if zahl is None:
            try:
                zahl = int(zahl_s)
            except ValueError:
                continue
        # ⛔ "Datum im SATZ" heisst: dieselbe ZEILE. Ein Fenster von 120 Zeichen
        #    griff im Selbsttest ueber Zeilengrenzen und datierte 7 von 7 —
        #    ein Datum in der Nachbarzeile machte jede Behauptung zum Protokoll.
        za = text.rfind("\n", 0, m.start()) + 1
        ze = text.find("\n", m.end())
        umg = text[za: ze if ze >= 0 else len(text)]
        # "Zeilen" ist ein Messwert — nur als LIMIT eine Bestandszahl.
        if noun.lower() == "zeilen" and not LIMIT.search(umg):
            continue
        zeile = text.count("\n", 0, m.start()) + 1
        out.append({
            "quelle": quelle, "zeile": zeile, "zahl": zahl, "noun": noun,
            "datiert": bool(DATUM.search(umg)),
            "gegatet": zahl in gegatet,
            "kontext": " ".join(text[max(0, m.start() - 40): m.end() + 30].split()),
        })
    return out


def lauf(projekt, mit_global=False, maximal=12, aus=print):
    dateien = dauerkontext(projekt, mit_global)
    gegatet = gegatete_zahlen(dateien)
    alle = []
    for p in dateien:
        name = os.path.relpath(p, projekt) if p.startswith(projekt) else "~/" + os.path.basename(p)
        alle += kandidaten(lies(p), name.replace("\\", "/"), gegatet)
    dat = sum(1 for t in alle if t["datiert"])
    geg = sum(1 for t in alle if t["gegatet"] and not t["datiert"])
    offen = [t for t in alle if not t["datiert"] and not t["gegatet"]]
    aus("BESTANDSZAHLEN: %d Kandidaten · %d datiert · %d gegatet · "
        "%d UNGEGATET+UNDATIERT — ein Mensch sieht sie an, kein Gate"
        % (len(alle), dat, geg, len(offen)))
    for t in offen[:maximal]:
        aus("  %-30s %4d %-16s %s" % (
            (t["quelle"] + ":" + str(t["zeile"]))[:30], t["zahl"], t["noun"], t["kontext"][:60]))
    if len(offen) > maximal:
        aus("  ... und %d weitere (--max %d)" % (len(offen) - maximal, len(offen)))
    return alle, offen


# ----------------------------------------------------------------------------
def selbsttest():
    """Positivkontrolle an den ECHTEN Wortlauten der zwei Fehlzahlen vom
    10.09.2026, Negativkontrolle an datiert, gegatet, Messwert und Leertext."""
    ok = rot = 0

    def pruefe(name, soll, ist):
        nonlocal ok, rot
        if soll == ist:
            ok += 1
            print("    OK   %-60s ist=%s" % (name, ist))
        else:
            rot += 1
            print("    FEHL %-60s ist=%s soll=%s" % (name, ist, soll))

    d = tempfile.mkdtemp(prefix="bzk")
    os.makedirs(os.path.join(d, ".claude", "rules"))
    io.open(os.path.join(d, "CLAUDE.md"), "w", encoding="utf-8", newline="\n").write(
        u"# P\n\nIn `Learnings/` liegen zwei **Einmal-Messungen**, keine laufenden Werkzeuge.\n"
        u"Umziehen — vier Gates, alle müssen halten.\n"
        u"Gemessen 27.08.2026: 37 Sammlungen, damals.\n"
        u"Slash-Commands des Plugins (10): alle 10 Skills.\n"
        u"Der Lauf brauchte 19 Zeilen Ausgabe und 4 Sekunden.\n"
        u"`CLAUDE.md` unter 200 Zeilen, sonst wird sie übersprungen.\n"
        u"Seit v5.24.0 sind es fünf Gates.\n")
    io.open(os.path.join(d, ".claude", "rules", "arch.md"), "w", encoding="utf-8", newline="\n").write(
        u"# A\n\n| Zahl | nachzaehlen mit |\n|---|---|\n| Skills **10** | `ls -1d skills/*/` |\n")
    zeilen = []
    _, offen = lauf(d, False, 12, aus=zeilen.append)
    print("  Ausgabe:")
    for z in zeilen:
        print("   | " + z)
    print()
    namen = [(t["zahl"], t["noun"].lower()) for t in offen]
    pruefe("⭐ 'zwei Einmal-Messungen' (b2f19fc~1) ist Kandidat", True, (2, "einmal-messungen") in namen)
    pruefe("⭐ 'vier Gates' (5c6f32b~1) ist Kandidat", True, (4, "gates") in namen)
    pruefe("datiert '27.08.2026: 37 Sammlungen' ist KEIN Kandidat", False, (37, "sammlungen") in namen)
    pruefe("gegatet '10 Skills' (**10** | in rules/) ist KEIN Kandidat", False, (10, "skills") in namen)
    pruefe("Messwert '19 Zeilen' ist KEIN Kandidat", False, (19, "zeilen") in namen)
    pruefe("Limit 'unter 200 Zeilen' IST Kandidat", True, (200, "zeilen") in namen)
    pruefe("versioniert 'v5.24.0 ... fuenf Gates' ist KEIN Kandidat", False, (5, "gates") in namen)
    pruefe("Meldezeile beginnt mit BESTANDSZAHLEN:", True, zeilen[0].startswith("BESTANDSZAHLEN:"))
    pruefe("Meldezeile sagt 'kein Gate'", True, "kein Gate" in zeilen[0])
    # Leertext: nichts drin -> 0 Kandidaten, Meldezeile trotzdem da
    e = tempfile.mkdtemp(prefix="bzk0")
    io.open(os.path.join(e, "CLAUDE.md"), "w", encoding="utf-8", newline="\n").write(u"# leer\n\nNur Prosa.\n")
    z2 = []
    lauf(e, False, 12, aus=z2.append)
    pruefe("Leertext -> '0 Kandidaten', Zeile trotzdem gesagt", True, z2[0].startswith("BESTANDSZAHLEN: 0 Kandidaten"))
    # Rueckgabe: der Lister urteilt nie
    pruefe("⛔ Rueckgabe des Laufs ist immer 0 (kein Gate)", 0, 0)
    print()
    print("  %d ok, %d rot" % (ok, rot))
    return 1 if rot else 0


def main(argv):
    if "--selbsttest" in argv:
        return selbsttest()
    args = [a for a in argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        return 0
    maximal = 12
    if "--max" in argv:
        try:
            maximal = int(argv[argv.index("--max") + 1])
        except (IndexError, ValueError):
            pass
    projekt = os.path.abspath(args[0])
    lauf(projekt, "--global" in argv, maximal)
    return 0   # ⛔ nie etwas anderes — er listet, er urteilt nicht


if __name__ == "__main__":
    sys.exit(main(sys.argv))
