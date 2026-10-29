#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Das Verlaufsbuch — EINE Datei je Sitzung statt N voller Chat-Rettungen (v5.160.0, Etappe 62).

Je Kompaktierung ein ANGEHAENGTER Abschnitt in `.claude-mind/verlauf/<sid>.md`:
Kopf (Zeit, sid, Rettung, Transkript-Zeilenbereich, Groesse) + Arbeitsstand + Claudes eigene
Kompaktierungs-Zusammenfassung. Der volle Chat (`rescued/<ts>_chat.md`) bleibt Sicherung.

GEMESSEN 29.10.2026 (PLAN-etappe62.md):
  * Jede Kompaktierung hinterlaesst genau EINE `isCompactSummary`, VOR dem SessionStart:compact-Hook (18/18)
    -> der Hook holt sie ueber `transcript_path`.
  * Abschnitt (RESUME + Arbeitsstand + Zusammenfassung) deckt 18–36 % der Marken des vollen Chats bei
    3–8 % der Groesse; der Arbeitsstand allein nur +4–8 Punkte.
  * Zusammenfassungen sind NICHT kumulativ: die naechste behaelt 34–37 % der Marken der vorigen —
    deshalb ANHAENGEN, nicht ueberschreiben.

⭐ DELTA ueber den TRANSKRIPT-Zeilenbereich zwischen zwei Kompaktierungsgrenzen, nicht ueber die
   Beitragsnummern der Rettungen (die beginnen je Rettung neu und ueberlappen). So kann keine Zeile in
   zwei Abschnitten stehen. Ein Abschnitt mit demselben `bis` wird nicht zweimal angehaengt.
⛔ Fail-open: der Aufruf aus `session-start.sh` darf die Sitzung nie aufhalten — jeder Fehler ist
   rc 1 mit einer Zeile auf stderr, nichts wird halb geschrieben (erst bauen, dann in EINEM Zug anhaengen).

AUFRUF
  verlaufsbuch.py --anhaengen --projekt <dir> --transkript <jsonl> --sid <uuid> [--rettung <stamm>]
  verlaufsbuch.py --fuer <rettung-dateiname> --projekt <dir>    -> "<verlauf.md>" falls ein Abschnitt sie traegt
  verlaufsbuch.py --selbsttest
RUECKGABE  0 = ok · 1 = nichts zu tun / nicht gefunden · 2 = Aufruffehler
"""
import glob
import io
import json
import os
import re
import subprocess
import sys
import time

_HIER = os.path.dirname(os.path.abspath(__file__))
KOPF = re.compile(r"^## Kompaktierung .* zeilen=(\d+)-(\d+) .*rettung=(\S+)", re.M)


def grenzen(transkript):
    """-> ([zeilennr der compact_boundary …], {zeilennr der Grenze: text der folgenden Zusammenfassung})."""
    gr, zf, offen = [], {}, None
    with open(transkript, encoding="utf-8", errors="replace") as f:
        for n, l in enumerate(f, 1):
            if '"compact_boundary"' in l:
                try:
                    o = json.loads(l)
                except ValueError:
                    continue
                if o.get("type") == "system" and o.get("subtype") == "compact_boundary":
                    gr.append(n)
                    offen = n
            elif offen and '"isCompactSummary"' in l:
                try:
                    o = json.loads(l)
                except ValueError:
                    continue
                if o.get("isCompactSummary"):
                    c = (o.get("message") or {}).get("content")
                    zf[offen] = c if isinstance(c, str) else " ".join(
                        b.get("text", "") for b in (c or []) if isinstance(b, dict))
                    offen = None
    return gr, zf


def arbeitsstand_text(pfad):
    if not pfad or not os.path.isfile(pfad):
        return ""
    r = subprocess.run([sys.executable, os.path.join(_HIER, "arbeitsstand_render.py"), pfad],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    return r.stdout.strip()


def neueste_rettung(projekt, sid):
    """Stamm der juengsten Rettung DIESER Sitzung (Dateiname endet auf die letzten 8 Zeichen der sid)."""
    s8 = (sid or "").replace("-", "")[-8:]
    if not s8:
        return ""
    k = sorted(glob.glob(os.path.join(projekt, ".claude-mind", "rescued", "*-%s_ARBEITSSTAND.json" % s8)))
    return os.path.basename(k[-1])[:-len("_ARBEITSSTAND.json")] if k else ""


def anhaengen(projekt, transkript, sid, rettung=None):
    if not (projekt and os.path.isdir(projekt) and transkript and os.path.isfile(transkript) and sid):
        print("verlaufsbuch: Aufruf unvollstaendig", file=sys.stderr)
        return 2
    gr, zf = grenzen(transkript)
    if not gr:
        print("verlaufsbuch: keine Kompaktierungsgrenze im Transkript", file=sys.stderr)
        return 1
    bis = gr[-1]
    von = gr[-2] + 1 if len(gr) > 1 else 1
    ziel = os.path.join(projekt, ".claude-mind", "verlauf", "%s.md" % sid)
    alt = open(ziel, encoding="utf-8", errors="replace").read() if os.path.isfile(ziel) else ""
    if any(int(m.group(2)) == bis for m in KOPF.finditer(alt)):
        return 1                                # dieselbe Kompaktierung steht schon da
    rettung = rettung or neueste_rettung(projekt, sid)
    arb = arbeitsstand_text(os.path.join(projekt, ".claude-mind", "rescued", rettung + "_ARBEITSSTAND.json")) if rettung else ""
    zus = zf.get(bis, "").strip()
    rumpf = ("### Arbeitsstand\n\n%s\n\n### Zusammenfassung der Kompaktierung (Claude)\n\n%s\n"
             % (arb or "(keiner)", zus or "(keine im Transkript)"))
    kb = (len(rumpf.encode("utf-8")) + 1023) // 1024
    kopf = "## Kompaktierung %s · sid=%s · zeilen=%d-%d · %d KB · rettung=%s\n\n" % (
        time.strftime("%Y-%m-%d %H:%M:%S"), sid, von, bis, kb, rettung or "-")
    os.makedirs(os.path.dirname(ziel), exist_ok=True)
    neu = ("# Verlaufsbuch %s\n\nEin Abschnitt je Kompaktierung, nur angehaengt. Voller Chat: `rescued/`.\n\n" % sid
           if not alt else "")
    with open(ziel, "a", encoding="utf-8", newline="\n") as f:     # EIN Zug: Kopf und Rumpf zusammen
        f.write(neu + kopf + rumpf + "\n")
    print("%s %d KB zeilen=%d-%d" % (ziel, kb, von, bis))
    return 0


def fuer(rettung, projekt):
    stamm = os.path.basename(rettung).split("_")[0]
    for v in sorted(glob.glob(os.path.join(projekt, ".claude-mind", "verlauf", "*.md"))):
        t = open(v, encoding="utf-8", errors="replace").read()
        if any(m.group(3) == stamm for m in KOPF.finditer(t)):
            print(v)
            return 0
    return 1


def selbsttest():
    import shutil
    import tempfile
    rot = 0

    def pruef(was, ist, soll):
        nonlocal rot
        ok = ist == soll
        rot += 0 if ok else 1
        print("  [%s] %s%s" % ("ok " if ok else "ROT", was, "" if ok else " (erwartet %r, war %r)" % (soll, ist)))

    d = tempfile.mkdtemp()
    try:
        p = os.path.join(d, "projekt mit leer")
        os.makedirs(os.path.join(p, ".claude-mind", "rescued"))
        sid = "aaaa1111-0000-0000-0000-00000000beef"
        t = os.path.join(d, "t.jsonl")

        def schreibe(n_grenzen):
            with open(t, "w", encoding="utf-8") as f:
                for i in range(n_grenzen):
                    f.write('{"type":"user","message":{"content":"Arbeit %d"}}\n' % i)
                    f.write('{"type":"system","subtype":"compact_boundary"}\n')
                    f.write('{"type":"user","isCompactSummary":true,"message":{"content":"ZUSAMMENFASSUNG-%d"}}\n' % i)

        schreibe(1)
        pruef("erste Kompaktierung -> rc 0", anhaengen(p, t, sid, "20261029-000000-000-0000beef"), 0)
        v = open(os.path.join(p, ".claude-mind", "verlauf", sid + ".md"), encoding="utf-8").read()
        pruef("  ... Zusammenfassung steht drin", "ZUSAMMENFASSUNG-0" in v, True)
        pruef("  ... Bereich ab Zeile 1", "zeilen=1-2" in v, True)
        pruef("⛔ dieselbe Kompaktierung zweimal -> rc 1, nichts doppelt", anhaengen(p, t, sid), 1)
        for n in range(2, 21):
            schreibe(n)
            anhaengen(p, t, sid, "20261029-%06d-000-0000beef" % n)
        v = open(os.path.join(p, ".claude-mind", "verlauf", sid + ".md"), encoding="utf-8").read()
        bereiche = [(int(m.group(1)), int(m.group(2))) for m in KOPF.finditer(v)]
        pruef("⭐ 20 Kompaktierungen -> EINE Datei, 20 Abschnitte", len(bereiche), 20)
        pruef("⭐ keine Zeile in zwei Abschnitten (Delta)",
              all(a[1] < b[0] for a, b in zip(bereiche, bereiche[1:])), True)
        pruef("  ... und luecklos", all(a[1] + 1 == b[0] for a, b in zip(bereiche, bereiche[1:])), True)
        pruef("  ... jede Zusammenfassung genau einmal",
              all(v.count("ZUSAMMENFASSUNG-%d\n" % i) == 1 for i in range(20)), True)
        pruef("--fuer findet die Rettung im Buch", fuer("20261029-000005-000-0000beef_chat.md", p), 0)
        pruef("⛔ --fuer: unbekannte Rettung -> rc 1", fuer("20991231-000000-000-ffffffff_chat.md", p), 1)
        pruef("⛔ ohne Grenze im Transkript -> rc 1", anhaengen(p, os.devnull, sid) in (1, 2), True)
        print("  Groesse nach 20 Abschnitten: %d B" % os.path.getsize(os.path.join(p, ".claude-mind", "verlauf", sid + ".md")))
    finally:
        shutil.rmtree(d, ignore_errors=True)
    print("\n  %s" % ("alle Selbsttests bestanden" if not rot else "%d ROT" % rot))
    return 1 if rot else 0


def main(a=None):
    a = list(sys.argv[1:] if a is None else a)

    def wert(flag):
        return a[a.index(flag) + 1] if flag in a and a.index(flag) + 1 < len(a) else None

    if "--selbsttest" in a:
        return selbsttest()
    if "--anhaengen" in a:
        return anhaengen(wert("--projekt"), wert("--transkript"), wert("--sid"), wert("--rettung"))
    if "--fuer" in a:
        if not (wert("--fuer") and wert("--projekt")):
            return 2
        return fuer(wert("--fuer"), wert("--projekt"))
    print(__doc__.split("AUFRUF")[1].split("RUECKGABE")[0].strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    if hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.exit(main())
