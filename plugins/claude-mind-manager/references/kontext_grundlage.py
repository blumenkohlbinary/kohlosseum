# -*- coding: utf-8 -*-
u"""Messgrundlage fuer `/mind-denkstufe` (v5.155.0, Etappe 59/60 Punkt 0): wie gross wird der Verlauf in diesem
Ordner, und wofuer? Liest die Transkripte ZAEHLEND (je `message.id` einmal), nie in den Hauptkontext.

    python kontext_grundlage.py --projekt <ordner> [--grenze <tokens>] [--json]
    python kontext_grundlage.py --transkripte <dir> [--grenze <tokens>] [--json]
    python kontext_grundlage.py --selbsttest

Rueckgabe 0 gemessen · 1 nicht messbar (zu wenig Transkripte) · 2 Aufruffehler.

⛔ KEINE SCHWELLE (Nutzer 28.10.2026: „das soll nicht einfach festgelegt sein, jeder chat an eigene aufgabe").
   Geliefert wird eine Messgrundlage: Grundlast, Groesse nach Kompaktierung, Einlese-Bedarf bis zur ersten
   Aenderung, Verteilung — als BELEGT, mit der Zahl der Faelle. Was daraus gerechnet ist, steht als HERGELEITET.
⛔ Teilen sich mehrere Rollen den Ordner (Roster mit mehr als einer Zeile), gibt es nur EINEN Wert fuer alle —
   das wird gemeldet, nicht je Rolle zerlegt.
"""
import argparse
import io
import json
import os
import re
import shutil
import statistics
import sys
import tempfile
from pathlib import Path

AENDERT = {"Edit", "Write", "NotebookEdit", "MultiEdit"}
MIN_FAELLE = 3


def slug(pfad):
    return re.sub(r"[^A-Za-z0-9]", "-", str(Path(pfad)).replace("/", "\\"))


def _verlauf(u):
    return int(u.get("input_tokens", 0) or 0) + int(u.get("cache_read_input_tokens", 0) or 0) \
        + int(u.get("cache_creation_input_tokens", 0) or 0)


def lies_transkript(p):
    u"""-> Liste von Abschnitten; ein Abschnitt beginnt mit dem Start oder einer Kompaktierung.
    Je Abschnitt: art ('start'|'kompakt'), verlaeufe [..], erste_aenderung (Index oder None), agenten, workflows."""
    abschn = [{"art": "start", "v": [], "aend": None, "agenten": 0, "workflows": 0}]
    gesehen = set()
    with io.open(str(p), encoding="utf-8", errors="replace") as f:
        for z in f:
            if '"compact_boundary"' in z:
                try:
                    o = json.loads(z)
                except ValueError:
                    o = {}
                if o.get("subtype") == "compact_boundary":
                    abschn.append({"art": "kompakt", "v": [], "aend": None, "agenten": 0, "workflows": 0})
                continue
            if '"assistant"' not in z:
                continue
            try:
                o = json.loads(z)
            except ValueError:
                continue
            if o.get("type") != "assistant" or o.get("isSidechain"):
                continue
            m = o.get("message") or {}
            a = abschn[-1]
            mid = m.get("id")
            if mid and mid not in gesehen:
                gesehen.add(mid)
                a["v"].append(_verlauf(m.get("usage") or {}))
            for b in m.get("content") or []:
                if isinstance(b, dict) and b.get("type") == "tool_use":
                    n = b.get("name")
                    if n in AENDERT and a["aend"] is None:
                        a["aend"] = max(len(a["v"]) - 1, 0)
                    if n in ("Agent", "Task"):
                        a["agenten"] += 1
                    if n == "Workflow":
                        a["workflows"] += 1
    return [a for a in abschn if a["v"]]


def quantil(werte, q):
    if not werte:
        return None
    w = sorted(werte)
    k = max(0, min(len(w) - 1, int(round(q * (len(w) - 1)))))
    return w[k]


def geteilt(projekt):
    r = Path(projekt) / ".claude" / "rules" / "rollen.md"
    if not r.is_file():
        return False, 0
    n = sum(1 for l in io.open(str(r), encoding="utf-8", errors="replace")
            if re.match(r"^\|\s*\*\*(manager|arbeiter|sync)\*\*", l))
    return n > 1, n


def messen(transkripte, grenze=None, projekt=None):
    dateien = sorted(Path(transkripte).glob("*.jsonl"))
    frisch, kompakt, einlese, alle = [], [], [], []
    agenten = workflows = 0
    for d in dateien:
        for a in lies_transkript(d):
            alle.extend(a["v"])
            agenten += a["agenten"]
            workflows += a["workflows"]
            (frisch if a["art"] == "start" else kompakt).append(a["v"][0])
            if a["aend"] is not None:
                einlese.append(max(0, a["v"][a["aend"]] - a["v"][0]))
    # ⛔ Eine FORTGESETZTE Sitzung beginnt mit ihrem alten Verlauf — ihre erste Anfrage ist keine Grundlast
    #    (gemessen 29.10.2026, Zustellplan: Median 566 508 statt ~150 000). Ein frischer Start kann nicht
    #    groesser sein als das Doppelte des Stands nach einer Kompaktierung; groessere zaehlen nicht.
    fortgesetzt = 0
    if kompakt:
        dach = 2 * statistics.median(kompakt)
        fortgesetzt = sum(1 for v in frisch if v > dach)
        frisch = [v for v in frisch if v <= dach]
    erg = {
        "transkripte": len(dateien), "anfragen": len(alle), "fortgesetzt": fortgesetzt,
        "grundlast": {"median": int(statistics.median(frisch)) if frisch else None, "faelle": len(frisch)},
        "nach_kompakt": {"median": int(statistics.median(kompakt)) if kompakt else None, "faelle": len(kompakt)},
        "einlese": {"p50": quantil(einlese, .5), "p95": quantil(einlese, .95), "faelle": len(einlese)},
        "verlauf": {"p50": quantil(alle, .5), "p95": quantil(alle, .95), "max": max(alle) if alle else None},
        "agenten": agenten, "workflows": workflows, "grenze": grenze,
    }
    if grenze and alle:
        erg["verlauf"]["anteil_nahe_grenze"] = round(100.0 * sum(1 for v in alle if v >= .9 * grenze) / len(alle), 1)
    if projekt:
        g, n = geteilt(projekt)
        erg["geteilt"], erg["rollen"] = g, n
    erg["messbar"] = len(frisch) + len(kompakt) >= MIN_FAELLE and len(alle) >= 10
    # HERGELEITET: wann lohnt Leeren statt Kompaktieren? Nach dem Kompaktieren traegt jede Anfrage ~K, nach dem Leeren
    # ~G + E (Grundlast + neu einlesen). Das Kompaktieren selbst liest den Verlauf H einmal. Leeren ist billiger,
    # solange G + E <= K — sonst holt es den Mehrverbrauch je Anfrage nach H / ((G+E)-K) Anfragen wieder ein.
    G, K, E = erg["grundlast"]["median"], erg["nach_kompakt"]["median"], erg["einlese"]["p50"]
    if G is not None and K is not None and E is not None:
        erg["leeren"] = {"nach_leeren": G + E, "nach_kompakt": K,
                         "mehr_je_anfrage": max(0, G + E - K)}
    erg["grenze_vorschlag"] = grenze_vorschlag(dateien, G, K)
    return erg


# ⛔ v5.171.0 (Etappe 66, Nutzer 30.10.2026 — ersetzt „keine Schwelle“ vom 28.10.2026): jeder Ordner bekommt eine
#    berechnete Kompaktierungsgrenze. HERGELEITET, nie BELEGT: Startlast + Bedarf einer vollstaendigen Strecke + 15 %.
#    Gemessen wird der Bedarf NUR an Strecken, die OHNE Kompaktierung endeten — eine Strecke, die an der Grenze
#    abbricht, ist zensiert (ihre Spitze ist die alte Grenze, nicht der Bedarf). Je Ordner die hungrigste Sitzung.
RESERVE = 0.15
GRENZE_MIN, GRENZE_MAX, RASTER = 100000, 1000000, 50000


def grenze_vorschlag(dateien, grundlast, nach_kompakt):
    je_sitzung = {}
    for d in dateien:
        abschn = lies_transkript(d)
        for i, a in enumerate(abschn):
            if i + 1 < len(abschn):      # endete in einer Kompaktierung -> zensiert
                continue
            je_sitzung.setdefault(d.stem, []).append(max(a["v"]) - a["v"][0])
    alle = [b for w in je_sitzung.values() for b in w]
    start = max(x for x in (grundlast, nach_kompakt, 0) if x is not None)
    if len(alle) < MIN_FAELLE or not start:
        return {"wert": None, "faelle": len(alle), "grund": "zu wenige vollstaendige Strecken (%d < %d)" % (len(alle), MIN_FAELLE)}
    hungrig = max(je_sitzung, key=lambda s: statistics.median(je_sitzung[s]))
    bedarf = int(statistics.median(je_sitzung[hungrig]))
    roh = (start + bedarf) * (1 + RESERVE)
    wert = int(min(GRENZE_MAX, max(GRENZE_MIN, -(-roh // RASTER) * RASTER)))
    return {"wert": wert, "faelle": len(alle), "start": start, "bedarf": bedarf, "sitzung": hungrig,
            "gekappt": wert != -(-roh // RASTER) * RASTER}


def bericht(e):
    def t(x):
        return "—" if x is None else "{:,}".format(x).replace(",", " ")
    z = ["Messgrundlage Verlauf (%d Transkripte, %d Anfragen, je message.id gezaehlt)" % (e["transkripte"], e["anfragen"])]
    if not e["messbar"]:
        z.append("  NICHT MESSBAR: zu wenig Faelle — globale Vorgabe lassen, keine Zahl nennen.")
        return "\n".join(z)
    z += ["  BELEGT  Grundlast (erste Anfrage einer frischen Sitzung): %s  (%d Faelle, %d fortgesetzte ausgeschlossen)" % (
              t(e["grundlast"]["median"]), e["grundlast"]["faelle"], e.get("fortgesetzt", 0)),
          "  BELEGT  nach Kompaktierung (erste Anfrage danach): %s  (%d Faelle)" % (t(e["nach_kompakt"]["median"]), e["nach_kompakt"]["faelle"]),
          "  BELEGT  Einlese-Bedarf bis zur ersten Aenderung: p50 %s · p95 %s  (%d Faelle)" % (
              t(e["einlese"]["p50"]), t(e["einlese"]["p95"]), e["einlese"]["faelle"]),
          "  BELEGT  Verlauf je Anfrage: p50 %s · p95 %s · max %s" % (t(e["verlauf"]["p50"]), t(e["verlauf"]["p95"]), t(e["verlauf"]["max"]))]
    if "anteil_nahe_grenze" in e["verlauf"]:
        z.append("  BELEGT  Anfragen ab 90 %% der Grenze %s: %s %%" % (t(e["grenze"]), e["verlauf"]["anteil_nahe_grenze"]))
    z.append("  BELEGT  Agenten-Aufrufe %d · Workflows %d" % (e["agenten"], e["workflows"]))
    if "leeren" in e:
        l = e["leeren"]
        z.append("  HERGELEITET  nach Leeren ~%s (Grundlast + Einlesen) gegen nach Kompaktieren ~%s -> %s" % (
            t(l["nach_leeren"]), t(l["nach_kompakt"]),
            "Leeren mit Uebergabe ist billiger" if l["mehr_je_anfrage"] == 0 else
            "Kompaktieren ist billiger, Leeren traegt ~%s mehr je Anfrage" % t(l["mehr_je_anfrage"])))
    gv = e.get("grenze_vorschlag") or {}
    if gv.get("wert"):
        z.append("  HERGELEITET  Kompaktierungsgrenze autoCompactWindow %s = (Startlast %s + Bedarf %s) x 1,15, auf %s gerundet%s"
                 " — hungrigste Sitzung %s, %d vollstaendige Strecken" % (
                     t(gv["wert"]), t(gv["start"]), t(gv["bedarf"]), t(RASTER),
                     ", auf %s–%s gekappt" % (t(GRENZE_MIN), t(GRENZE_MAX)) if gv["gekappt"] else "", gv["sitzung"][:8], gv["faelle"]))
    else:
        z.append("  KEINE Kompaktierungsgrenze: %s — globale Vorgabe lassen." % gv.get("grund", "nicht messbar"))
    if e.get("geteilt"):
        z.append("  ⚠ %d Rollen teilen diesen Ordner — eine Einstellung gilt fuer alle; der Wert folgt der hungrigsten Sitzung." % e["rollen"])
    return "\n".join(z)


def _zeile(mid, v, tools=()):
    c = [{"type": "tool_use", "name": n, "id": "t%s%s" % (mid, n)} for n in tools] or [{"type": "text", "text": "x"}]
    return json.dumps({"type": "assistant", "message": {"id": mid, "content": c,
                       "usage": {"input_tokens": 0, "cache_read_input_tokens": v, "cache_creation_input_tokens": 0}}}) + "\n"


def selbsttest():
    ok = rot = 0

    def pruef(was, ist, soll):
        nonlocal ok, rot
        if ist == soll:
            ok += 1
            print("  [ok ] " + was)
        else:
            rot += 1
            print("  [ROT] %s - erwartet %r, bekommen %r" % (was, soll, ist))
    d = Path(tempfile.mkdtemp())
    try:
        t = d / "transkripte"
        t.mkdir()
        # Sitzung 1: Grundlast 100k, Einlesen bis 400k, dann Aenderung; Kompaktierung; danach 150k
        (t / "a.jsonl").write_text(
            _zeile("m1", 100000) + _zeile("m1", 100000) + _zeile("m2", 250000, ["Read"]) + _zeile("m3", 400000, ["Edit"])
            + _zeile("m4", 420000) + json.dumps({"type": "system", "subtype": "compact_boundary"}) + "\n"
            + _zeile("m5", 150000) + _zeile("m6", 160000, ["Write"]), encoding="utf-8")
        (t / "c.jsonl").write_text(_zeile("c1", 900000) + _zeile("c2", 910000), encoding="utf-8")   # fortgesetzt
        (t / "b.jsonl").write_text(_zeile("n1", 110000) + _zeile("n2", 300000, ["Agent"]) + _zeile("n3", 320000, ["Edit"])
                                   + "".join(_zeile("n%d" % i, 330000) for i in range(4, 9)), encoding="utf-8")
        e = messen(t, grenze=700000)
        pruef("je message.id einmal (m1 doppelt)", e["anfragen"], 16)
        pruef("fortgesetzte Sitzung zaehlt nicht als Grundlast", e["fortgesetzt"], 1)
        pruef("Grundlast = Median der ersten Anfragen", e["grundlast"]["median"], 105000)
        pruef("nach Kompaktierung", e["nach_kompakt"]["median"], 150000)
        pruef("Einlese-Bedarf p95 (300k, 10k, 210k)", e["einlese"]["p95"], 300000)
        pruef("Agenten gezaehlt", e["agenten"], 1)
        pruef("messbar", e["messbar"], True)
        pruef("Bericht nennt BELEGT und HERGELEITET", ("BELEGT" in bericht(e), "HERGELEITET" in bericht(e)), (True, True))
        # v5.171.0: Grenze nur aus Strecken OHNE Kompaktierung (a: 1 zensiert + 1 offen, b: 1, c: 1 -> 3 Faelle)
        gv = e["grenze_vorschlag"]
        pruef("Grenze: zensierte Strecke zaehlt nicht (3 vollstaendige)", gv["faelle"], 3)
        pruef("Grenze: hungrigste Sitzung b (Bedarf 220k)", (gv["sitzung"], gv["bedarf"]), ("b", 220000))
        pruef("Grenze: (150k + 220k) x 1,15 -> 450k", gv["wert"], 450000)
        pruef("Bericht nennt die Grenze HERGELEITET", "HERGELEITET  Kompaktierungsgrenze autoCompactWindow 450 000" in bericht(e), True)
        pruef("Kappung oben 1 000 000", grenze_vorschlag([t / "b.jsonl", t / "c.jsonl", t / "a.jsonl"], 900000, 0)["wert"], 1000000)
        nur_zensiert = d / "zensiert"
        nur_zensiert.mkdir()
        (nur_zensiert / "z.jsonl").write_text(_zeile("z1", 100000) + _zeile("z2", 600000) + json.dumps(
            {"type": "system", "subtype": "compact_boundary"}) + "\n", encoding="utf-8")
        gz = grenze_vorschlag(sorted(nur_zensiert.glob("*.jsonl")), 100000, None)
        pruef("nur zensierte Strecken: KEINE Zahl", (gz["wert"], "zu wenige" in gz["grund"]), (None, True))
        leer = d / "leer"
        leer.mkdir()
        e2 = messen(leer)
        pruef("ohne Transkripte: nicht messbar", (e2["messbar"], "NICHT MESSBAR" in bericht(e2)), (False, True))
        p = d / "projekt"
        (p / ".claude" / "rules").mkdir(parents=True)
        (p / ".claude" / "rules" / "rollen.md").write_text(
            "| **manager** | A | x |\n| **arbeiter** | N | y |\n| **sync** | R | z |\n", encoding="utf-8")
        e3 = messen(t, projekt=p)
        pruef("geteilter Ordner wird gemeldet", (e3["geteilt"], e3["rollen"], "teilen diesen Ordner" in bericht(e3)), (True, 3, True))
    finally:
        shutil.rmtree(str(d), ignore_errors=True)
    print("\n  %d gruen, %d rot" % (ok, rot))
    return 0 if rot == 0 else 1


def main(a):
    p = argparse.ArgumentParser()
    p.add_argument("--projekt")
    p.add_argument("--transkripte")
    p.add_argument("--grenze", type=int)
    p.add_argument("--json", action="store_true")
    p.add_argument("--selbsttest", action="store_true")
    o = p.parse_args(a)
    if o.selbsttest:
        return selbsttest()
    if o.transkripte:
        t = Path(o.transkripte)
    elif o.projekt:
        t = Path(os.path.expanduser("~")) / ".claude" / "projects" / slug(o.projekt)
    else:
        print((__doc__ or "").split("\n\n")[1])
        return 2
    if not t.is_dir():
        print("FEHLER: kein Transkript-Ordner %s" % t, file=sys.stderr)
        return 2
    e = messen(t, o.grenze, o.projekt)
    print(json.dumps(e, ensure_ascii=False, indent=1) if o.json else bericht(e))
    return 0 if e["messbar"] else 1


if __name__ == "__main__":
    try:
        getattr(sys.stdout, "reconfigure")(encoding="utf-8", errors="replace")
    except Exception:
        pass
    sys.exit(main(sys.argv[1:]))
