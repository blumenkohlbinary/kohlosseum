#!/usr/bin/env python3
"""sync_kandidaten.py — mechanische Kandidatenlisten fuer die knowledge-sync-Agenten (v5.175.0, Etappe 68).

Gemessen 31.10.2026 auf Stand e66 (isolierter Einzeltest, cwd = Kopie): die Agenten arbeiten ihre
Pruefliste nicht vollstaendig ab — rules pruefte die Optionen nur einer von drei Werkzeug-Rules
(`--entfernt` in wissenstransfer-pruefen.md verloren), memory pruefte das Zitat in rotes-gate nicht
nach und uebersah die Lehre „Zusammenfassung nicht kumulativ“ im Verlaufsbuch. Dieses Werkzeug
zaehlt die Kandidaten AUS, der Agent urteilt je Zeile. Es schreibt nichts.

Aufruf:
    python sync_kandidaten.py --buch <verlauf.md>|<stamm> [--buch ...] --gegen <datei|ordner> [...]
    python sync_kandidaten.py --optionen <rules-ordner> --wurzel <projekt> [--plugin <plugin-root>]
    python sync_kandidaten.py --zitate <memory-ordner> --suche <datei|ordner> [...]
    python sync_kandidaten.py --zeiger <CLAUDE.md> --wurzel <projekt>
    python sync_kandidaten.py --selbsttest

  --buch     Punkte (Aufzaehlungen) der Verlaufsbuch-Abschnitte, deren Marken (`Code-Spans`) in KEINER
             der --gegen-Dateien vorkommen: „ungedeckt“. Punkte ohne Marke werden nur gezaehlt.
  --optionen Optionen (`--xyz`), die ein in der Rule genanntes Werkzeug auswertet, die Rule aber nicht nennt.
  --zitate   Zitate („…“) in Memory-Dateien, deren Wortlaut in der davor genannten Quelle (*.md) fehlt.
  --max      hoechstens so viele Zeilen je Liste (Vorgabe 40), der Rest wird gezaehlt.
Rueckgabe: 0 = Liste ausgegeben (auch leer) · 2 = Aufruffehler.
"""
import os
import re
import sys
import tempfile

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
except AttributeError:
    pass

SPAN = re.compile(r"`([^`\n]{4,80})`")
PUNKT = re.compile(r"^\s*(?:[-*]|\d+\.)\s+")
WERKZEUG = re.compile(r"((?:tools|Learnings|references)/[A-Za-z0-9_]+\.py)")
OPTION = re.compile(r"(?<![\w-])--[a-z][a-z0-9-]{2,}")
ZITAT = re.compile(r"„([^“\"]{12,400})[“\"]", re.S)
TEIL = re.compile(r"^\d+\. (.+?):\s*$")
# nur die Teile der Kompaktierungs-Zusammenfassung, in denen Lehren und Mechanik stehen (gemessen: sonst 124 von 273)
LEHRTEIL = re.compile(r"Concept|Konzept|Error|Fehler|Problem", re.I)
QUELLE = re.compile(r"(?<![\w./~-])([\w./~-]+\.md)\b")


def lies(p):
    try:
        with open(p, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def md_dateien(pfade):
    for p in pfade:
        if os.path.isdir(p):
            for n in sorted(os.listdir(p)):
                if n.endswith(".md"):
                    yield os.path.join(p, n)
        elif os.path.isfile(p):
            yield p


def norm(s):
    s = re.sub(r"[*`_>]", " ", s.lower())
    return re.sub(r"\s+", " ", s).strip()


def abschnitt(buch, stamm):
    zeilen = lies(buch).splitlines()
    von = None
    for i, z in enumerate(zeilen):
        if z.startswith("## Kompaktierung") and z.rstrip().endswith("rettung=" + stamm):
            von = i
        elif von is not None and z.startswith("## Kompaktierung"):
            return von, zeilen[von:i]
    return (von, zeilen[von:]) if von is not None else (None, [])


def buch_kandidaten(buecher, gegen, maxn):
    text = "\n".join(lies(p) for p in md_dateien(gegen))
    aus, ohne, gesamt = [], 0, 0
    for spec in buecher:
        buch, _, stamm = spec.rpartition("|")
        von, zeilen = abschnitt(buch, stamm)
        if von is None:
            aus.append("  (kein Abschnitt rettung=%s in %s)" % (stamm, os.path.basename(buch)))
            continue
        teil = ""
        for k, z in enumerate(zeilen):
            t = TEIL.match(z)
            if t:
                teil = t.group(1)
                continue
            if z.startswith("### "):
                teil = ""
            if not LEHRTEIL.search(teil) or not PUNKT.match(z):
                continue
            gesamt += 1
            marken = [m.strip() for m in SPAN.findall(z)]
            if not marken:
                ohne += 1
                continue
            if not any(m in text for m in marken):
                aus.append("  %s:%d  %s" % (os.path.basename(buch), von + k + 1, z.strip()[:150]))
    print("BUCH-PUNKTE OHNE DECKUNG (keine ihrer Marken steht in den geladenen Dateien) — je Zeile urteilen: "
          "gehoert es in eine Context-Datei (Ziel) oder ist es Durchgangsstand (INFO)?")
    for z in aus[:maxn]:
        print(z)
    if len(aus) > maxn:
        print("  ... %d weitere" % (len(aus) - maxn))
    print("  (%d Punkte gesamt, %d ohne Marke nicht mechanisch geprueft)" % (gesamt, ohne))


def optionen_kandidaten(rules, wurzel, plugin, maxn):
    aus = []
    for r in md_dateien([rules]):
        rt = lies(r)
        for ref in sorted(set(WERKZEUG.findall(rt))):
            src = pfad = ""
            for basis in (wurzel, plugin):
                if basis and os.path.isfile(os.path.join(basis, ref)):
                    pfad = os.path.join(basis, ref).replace("\\", "/")
                    src = lies(pfad)
                    break
            if not src:
                continue
            fehlt = sorted(o for o in set(OPTION.findall(src)) if o not in rt and o != "--help")
            if fehlt:
                aus.append("  %s nennt %s (%s) — dort ausgewertet, in der Rule nicht: %s"
                           % (os.path.basename(r), ref, pfad, " ".join(fehlt[:12])))
    print("WERKZEUG-OPTIONEN, DIE DIE RULE NICHT NENNT — UPDATE nur, wenn die Rule den Aufruf beschreibt und die "
          "Option fuer einen dort beschriebenen Weg (Rueckgabe, Ausnahme, Pflicht) noetig ist; sonst \"bewusst weggelassen\":")
    for z in aus[:maxn]:
        print(z)
    if len(aus) > maxn:
        print("  ... %d weitere" % (len(aus) - maxn))
    if not aus:
        print("  (keine)")


ZEIGER = re.compile(r"(Begr(?:ü|ue)ndung|Details|Belege?|Herleitung|Vorfall)[^:\n]{0,40}:\s*`?([\w./~-]+\.md)")


def zeiger_kandidaten(datei, wurzel, maxn):
    """Jeder Zeiger ("Begruendung: X", "Details: X") mit Zeile — der Agent prueft, ob der Gegenstand noch in X steht."""
    aus = []
    for i, z in enumerate(lies(datei).splitlines(), 1):
        for m in ZEIGER.finditer(z):
            ziel = m.group(2)
            da = any(os.path.isfile(os.path.join(b, ziel)) for b in (wurzel, os.path.dirname(datei)) if b)
            aus.append("  %s:%d  %s: %s %s" % (os.path.basename(datei), i, m.group(1), ziel, "" if da else "(FEHLT)"))
    print("ZEIGER — je Zeile urteilen: steht der GEGENSTAND der Zeile (nicht nur ein Stichwort) noch im Ziel? sonst UPDATE mit dem heutigen Ort:")
    for z in aus[:maxn]:
        print(z)
    if not aus:
        print("  (keine)")


def finde_quelle(name, suche):
    base = os.path.basename(name)
    for p in md_dateien(suche):
        if os.path.basename(p) == base:
            return p
    return ""


def zitat_kandidaten(memdir, suche, maxn):
    aus, geprueft = [], 0
    for m in md_dateien([memdir]):
        t = lies(m)
        for z in ZITAT.finditer(t):
            # die Quelle steht im selben Satz davor; Rettungen (*_chat.md) rotieren und sind keine Quelle
            vorher = t[max(0, z.start() - 150):z.start()]
            q = [n for n in QUELLE.findall(vorher) if not n.endswith("_chat.md")]
            if not q:
                continue
            quelle = finde_quelle(q[-1], suche)
            zeile = t.count("\n", 0, z.start()) + 1
            kern = norm(re.split(r"…|\.\.\.", z.group(1))[0])
            kern = " ".join(kern.split()[:6])
            if len(kern) < 12:
                continue
            geprueft += 1
            if not quelle:
                aus.append("  %s:%d  Quelle %s nicht gefunden — „%s…“" % (os.path.basename(m), zeile, q[-1], kern))
            elif kern not in norm(lies(quelle)):
                aus.append("  %s:%d  Wortlaut fehlt in %s — „%s…“" % (os.path.basename(m), zeile, quelle, kern))
    print("ZITATE OHNE WORTLAUT IN IHRER QUELLE — je Zeile UPDATE (heutiger Wortlaut oder Zeiger):")
    for z in aus[:maxn]:
        print(z)
    if len(aus) > maxn:
        print("  ... %d weitere" % (len(aus) - maxn))
    print("  (%d Zitate mit genannter Quelle geprueft)" % geprueft)


def selbsttest():
    ok = rot = 0

    def pruef(name, wert, soll):
        nonlocal ok, rot
        if wert == soll:
            ok += 1
            print("  [ok ] " + name)
        else:
            rot += 1
            print("  [ROT] %s — erwartet %r, bekommen %r" % (name, soll, wert))

    import io
    import contextlib
    d = tempfile.mkdtemp()
    os.makedirs(os.path.join(d, "rules"))
    os.makedirs(os.path.join(d, "tools"))
    os.makedirs(os.path.join(d, "mem"))
    with open(os.path.join(d, "buch.md"), "w", encoding="utf-8") as f:
        f.write("## Kompaktierung 1 · rettung=A\n2. Key Technical Concepts:\n- neu `isCompactSummary` nicht kumulativ\n"
                "- alt `bekannt_x`\n- ohne Marke\n7. Pending Tasks:\n- offen `nur_offen`\n"
                "## Kompaktierung 2 · rettung=B\n2. Key Technical Concepts:\n- fremd `nur_in_b`\n")
    with open(os.path.join(d, "rules", "r.md"), "w", encoding="utf-8") as f:
        f.write("`bekannt_x` und `tools/werk.py` mit --alt\n")
    with open(os.path.join(d, "tools", "werk.py"), "w", encoding="utf-8") as f:
        f.write("# --alt --neu-option\n")
    with open(os.path.join(d, "rules", "q.md"), "w", encoding="utf-8") as f:
        f.write("Report, do not fix beyond the prescription.\n")
    with open(os.path.join(d, "mem", "m.md"), "w", encoding="utf-8") as f:
        f.write("laut `q.md` — „ein Werkzeug meldet etwas Falsches und sie repariert“\n"
                "laut `q.md` — „Report, do not fix beyond the prescription“\n"
                "laut `q.md` — *„ein Werkzeug repariert etwas am Ende des Satzes\"*\n")

    def lauf(fn, *a):
        b = io.StringIO()
        with contextlib.redirect_stdout(b):
            fn(*a)
        return b.getvalue()

    o = lauf(buch_kandidaten, [os.path.join(d, "buch.md") + "|A"], [os.path.join(d, "rules")], 40)
    pruef("buch: ungedeckter Punkt gemeldet", "isCompactSummary" in o, True)
    pruef("buch: gedeckter Punkt nicht", "bekannt_x" in o, False)
    pruef("buch: anderer Abschnitt nicht", "nur_in_b" in o, False)
    pruef("buch: Teil Pending Tasks nicht", "nur_offen" in o, False)
    pruef("buch: Punkt ohne Marke gezaehlt", "1 ohne Marke" in o, True)
    o = lauf(optionen_kandidaten, os.path.join(d, "rules"), d, "", 40)
    pruef("optionen: fehlende gemeldet", "--neu-option" in o, True)
    pruef("optionen: genannte nicht", "--alt " in o or o.rstrip().endswith("--alt"), False)
    o = lauf(zitat_kandidaten, os.path.join(d, "mem"), [os.path.join(d, "rules")], 40)
    pruef("zitate: fehlender Wortlaut gemeldet", "werkzeug meldet etwas" in o, True)
    pruef("zitate: vorhandener nicht", "report, do not fix" in o, False)
    pruef("zitate: Schluss mit ASCII-Anfuehrung erkannt", "werkzeug repariert etwas" in o, True)
    pruef("zitate: alle drei gezaehlt", "3 Zitate" in o, True)
    with open(os.path.join(d, "C.md"), "w", encoding="utf-8") as f:
        f.write("- x\n  Begründung: `rules/r.md`\n- y Details: fehlt.md\n")
    o = lauf(zeiger_kandidaten, os.path.join(d, "C.md"), d, 40)
    pruef("zeiger: vorhandenes Ziel mit Zeile", "C.md:2  Begründung: rules/r.md " in o, True)
    pruef("zeiger: fehlendes Ziel markiert", "fehlt.md (FEHLT)" in o, True)
    print("  %d gruen · %d rot" % (ok, rot))
    return 1 if rot else 0


def main(a):
    if "--selbsttest" in a:
        return selbsttest()
    maxn = 40
    buecher, gegen, suche = [], [], []
    opt = wurzel = plugin = zit = zei = ""
    i = 0
    try:
        while i < len(a):
            k = a[i]
            if k == "--buch":
                buecher.append(a[i + 1]); i += 2
            elif k == "--gegen":
                i += 1
                while i < len(a) and not a[i].startswith("--"):
                    gegen.append(a[i]); i += 1
            elif k == "--suche":
                i += 1
                while i < len(a) and not a[i].startswith("--"):
                    suche.append(a[i]); i += 1
            elif k == "--optionen":
                opt = a[i + 1]; i += 2
            elif k == "--wurzel":
                wurzel = a[i + 1]; i += 2
            elif k == "--plugin":
                plugin = a[i + 1]; i += 2
            elif k == "--zitate":
                zit = a[i + 1]; i += 2
            elif k == "--zeiger":
                zei = a[i + 1]; i += 2
            elif k == "--max":
                maxn = int(a[i + 1]); i += 2
            else:
                print(__doc__); return 2
    except (IndexError, ValueError):
        print(__doc__); return 2
    if not (buecher or opt or zit or zei):
        print(__doc__); return 2
    if zei:
        zeiger_kandidaten(zei, wurzel, maxn)
    if buecher:
        buch_kandidaten(buecher, gegen, maxn)
    if opt:
        optionen_kandidaten(opt, wurzel, plugin, maxn)
    if zit:
        zitat_kandidaten(zit, suche, maxn)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
