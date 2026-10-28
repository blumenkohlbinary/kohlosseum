# -*- coding: utf-8 -*-
u"""lauf_tokens.py — was ein /mind-all-Lauf an Tokens kostet, hinterher am Transkript gemessen.

Aufruf:
    python lauf_tokens.py --lauf <LAUF-ID> [--projekt <ordner>] [--json]
    python lauf_tokens.py --transkript <sitzung.jsonl> --von <UTC-ISO> --bis <UTC-ISO> [--json]
    python lauf_tokens.py --selbsttest

Rueckgabe: 0 = gemessen · 1 = nichts im Fenster gefunden · 2 = Aufruffehler / nicht messbar.

⛔ WARUM ES DAS GIBT (v5.151.0, Etappe 58 §0, ZIEL 5): ein voller Lauf soll hoechstens ein Viertel
   der Tokens von heute kosten. Dafuer braucht es EIN Messgeraet, das alt und neu gleich zaehlt.
⛔ GEZAEHLT WIRD JE NACHRICHT, NICHT JE ZEILE. Claude Code schreibt eine Assistenten-Nachricht mit
   mehreren Bloecken (Text + parallele Werkzeugaufrufe) als MEHRERE Zeilen — und jede traegt dieselbe
   `usage`. Gemessen 28.10.2026 an Ritas Transkript: 936 von 936 mehrzeiligen Nachrichten mit
   identischer `usage`; je Zeile summiert ergab 1 157,7 Mio, je Nachricht 632,8 Mio (Faktor 1,83).
   Die Zeilen-Zaehlung wird zum Vergleich mit aelteren Messungen MIT ausgegeben (`zeilen_summe`).
⭐ Ein Lauf wird ueber seine LAUF-ID abgegrenzt (seit v5.140.0 in der mind-all-Startzeile der
   Schritt-Quittung): von dieser Startzeile bis zum letzten Eintrag vor dem naechsten mind-all-Start.
   Die Sitzung kommt aus der ID (sie endet auf die letzten neun Zeichen der Sitzungskennung);
   Pruefhelfer sind die Subagenten dieser Sitzung, die im Fenster BEGONNEN haben.
⚠ Steuernde Sitzung = die Sitzung, die den Lauf faehrt. Ihre Kosten sind fast nur Cache-Lesen:
   jeder Schritt liest den ganzen Verlauf neu — deshalb steht `verlauf_max` (groesster Kontext) dabei.
"""
import glob
import io
import json
import os
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:  # pragma: no cover
    pass

FELDER = ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens", "output_tokens")


def summe(pfad, von=None, bis=None):
    """-> dict mit Nachrichten-Summe (je message.id einmal) UND Zeilen-Summe (je Zeile)."""
    msg, zeilen, erst = {}, 0, None
    with io.open(pfad, encoding="utf-8", errors="replace") as f:
        for line in f:
            if '"assistant"' not in line or '"usage"' not in line:
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if d.get("type") != "assistant":
                continue
            ts = d.get("timestamp", "") or ""
            if von and not (von <= ts <= bis):
                continue
            m = d.get("message") or {}
            u = m.get("usage")
            if not u:
                continue
            werte = tuple(int(u.get(k, 0) or 0) for k in FELDER)
            zeilen += sum(werte)
            msg[m.get("id") or d.get("uuid")] = (werte, ts)
            erst = erst or ts
    s = {"schritte": len(msg), "zeilen_summe": zeilen, "verlauf_max": 0, "von": erst, "bis": None}
    for k in ("neu", "cache_lesen", "cache_schreiben", "ausgabe"):
        s[k] = 0
    for werte, ts in msg.values():
        s["neu"] += werte[0]; s["cache_lesen"] += werte[1]; s["cache_schreiben"] += werte[2]; s["ausgabe"] += werte[3]
        s["verlauf_max"] = max(s["verlauf_max"], werte[0] + werte[1] + werte[2])
        if not s["bis"] or ts > s["bis"]:
            s["bis"] = ts
    s["summe"] = s["neu"] + s["cache_lesen"] + s["cache_schreiben"] + s["ausgabe"]
    return s


def fenster_aus_lauf(projekt, lauf):
    """-> (von, bis) aus der Schritt-Quittung, oder (None, Grund)."""
    q = os.path.join(projekt, ".claude-mind", "schritt-quittung.jsonl")
    if not os.path.isfile(q):
        return None, "keine Schritt-Quittung unter %s" % q
    zeilen = io.open(q, encoding="utf-8", errors="replace").read().splitlines()
    start = None
    for i, z in enumerate(zeilen):
        if '"ereignis":"start","skill":"mind-all"' in z and '"lauf":"%s"' % lauf in z:
            start = i
    if start is None:
        return None, "Lauf %s steht in keiner mind-all-Startzeile" % lauf
    ende = len(zeilen)
    for j in range(start + 1, len(zeilen)):
        if '"ereignis":"start","skill":"mind-all"' in zeilen[j]:
            ende = j
            break
    ts = []
    for z in zeilen[start:ende]:
        try:
            t = json.loads(z).get("ts")
        except ValueError:
            continue
        if t:
            ts.append(t)
    if not ts:
        return None, "Lauf %s hat keine Zeitstempel" % lauf
    # ⛔ Das Ende ist der letzte Eintrag VOR der ersten Luecke ueber MIND_LAUF_LUECKE_MIN (30 min),
    #    nicht der letzte vor dem naechsten Lauf: an Veras Lauf vom 12.10. kam ein `mind_debug_write`
    #    zehn Stunden nach dem Ende (12:26 statt ~02:00) — das Fenster haette 10 h fremde Arbeit
    #    mitgezaehlt (Hauptsitzung 233,8 statt der gemessenen ~224 Mio).
    import datetime as _dt

    def _sek(x):
        try:
            return _dt.datetime.strptime(x[:19], "%Y-%m-%dT%H:%M:%S").timestamp()
        except ValueError:
            return None
    try:
        luecke = 60 * int(os.environ.get("MIND_LAUF_LUECKE_MIN", "30"))
    except ValueError:
        luecke = 1800
    ts = sorted(ts)
    ende = ts[0]
    for a_, b_ in zip(ts, ts[1:]):
        sa, sb = _sek(a_), _sek(b_)
        if sa is not None and sb is not None and sb - sa > luecke:
            break
        ende = b_
    ts = [x for x in ts if x <= ende]
    # ts in der Quittung sind sekundengenau ("…Z"), die Transkripte tragen Millisekunden — das Ende
    # wird bis zum Ende dieser Sekunde gefasst, damit der letzte Schritt nicht herausfaellt.
    bis = max(ts)
    if bis.endswith("Z") and "." not in bis:
        bis = bis[:-1] + ".999Z"
    return (min(ts), bis), None


def sitzung_aus_lauf(lauf, basis=None):
    """-> Pfad des Transkripts, dessen Sitzungskennung auf die Endung der Lauf-ID endet."""
    endung = lauf.rsplit("-", 1)[-1]
    basis = basis or os.path.expanduser("~/.claude/projects")
    treffer = [p for p in glob.glob(os.path.join(basis, "*", "*.jsonl"))
               if os.path.basename(p)[:-6].endswith(endung)]
    return treffer


def _ms(ts, ende=False):
    """`…:SSZ` -> `…:SS.000Z` (bzw. `.999Z` als Ende): sonst vergleicht der Text falsch.
    ⛔ Gefunden am Selbsttest: `…:00.100Z` < `…:00Z`, weil `.` vor `Z` sortiert — ein Fenster in
       Sekundenform schnitt die erste Sekunde ab."""
    if ts and ts.endswith("Z") and "." not in ts:
        return ts[:-1] + (".999Z" if ende else ".000Z")
    return ts


def turn_ende(transkript, nach):
    """-> Zeitstempel der letzten Assistenten-Zeile vor der ersten MENSCHLICHEN Nachricht nach <nach>.

    ⛔ Nach dem letzten Quittungseintrag folgen noch Schlussbericht und `sync-stand` — der Lauf endet
       mit dem TURN, nicht mit der Quittung (Veras Lauf: Verlauf 761 593 gegen 770 099 bei Anton).
       Menschlich = Nutzertext, der nicht mit `<` beginnt (keine Systemmeldung, kein Werkzeugergebnis).
    """
    letzt = nach
    with io.open(transkript, encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            ts = d.get("timestamp", "") or ""
            if ts <= nach:
                continue
            c = (d.get("message") or {}).get("content")
            if d.get("type") == "user" and isinstance(c, str) and not c.lstrip().startswith("<") and not d.get("isMeta"):
                break
            if d.get("type") == "assistant":
                letzt = ts
    return letzt


def turn_start(transkript, vor):
    """-> Zeitstempel des letzten /mind-all-AUFRUFS vor <vor> (Slash-Befehl oder Skill-Werkzeug).
    ⛔ Vor der mind-all-Startzeile der Quittung liegen schon Schritte (Skill lesen, Step -1).
    ⚠ Nicht „die letzte menschliche Nachricht": der Slash-Befehl beginnt mit `<command-name>`
      und sah wie eine Systemmeldung aus — das Fenster begann 1 h 40 zu frueh (Veras Lauf)."""
    start = vor
    with io.open(transkript, encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            ts = d.get("timestamp", "") or ""
            if ts >= vor:
                break
            if '"Skill"' in line or "mind-all" in line:
                c = (d.get("message") or {}).get("content")
                if d.get("type") == "user" and isinstance(c, str) and "<command-name>" in c and "mind-all" in c:
                    start = ts
                elif d.get("type") == "assistant" and isinstance(c, list):
                    for blk in c:
                        if (isinstance(blk, dict) and blk.get("type") == "tool_use" and blk.get("name") == "Skill"
                                and "mind-all" in str((blk.get("input") or {}).get("skill", ""))):
                            start = ts
    return start


def messen(transkript, von, bis):
    von, bis = _ms(von), _ms(bis, ende=True)
    haupt = summe(transkript, von, bis)
    agenten = []
    for p in sorted(glob.glob(os.path.join(transkript[:-6], "subagents", "agent-*.jsonl"))):
        s = summe(p)
        if s["von"] and von <= s["von"] <= bis:
            s["datei"] = os.path.basename(p)
            agenten.append(s)
    ag = {k: sum(a[k] for a in agenten) for k in ("summe", "zeilen_summe", "schritte")}
    gesamt = haupt["summe"] + ag["summe"]
    return {"transkript": transkript, "von": von, "bis": bis, "haupt": haupt,
            "agenten": {"anzahl": len(agenten), **ag}, "gesamt": gesamt,
            "gesamt_zeilen": haupt["zeilen_summe"] + ag["zeilen_summe"],
            "anteil_haupt": round(100.0 * haupt["summe"] / gesamt, 1) if gesamt else 0.0}


def bericht(r):
    h, a = r["haupt"], r["agenten"]
    print("Fenster: %s .. %s" % (r["von"], r["bis"]))
    print("steuernde Sitzung: %d Schritte · %s Tokens · davon Cache-Lesen %s · Verlauf bis %s"
          % (h["schritte"], "{:,}".format(h["summe"]), "{:,}".format(h["cache_lesen"]), "{:,}".format(h["verlauf_max"])))
    print("Pruefhelfer:       %d Agenten · %d Schritte · %s Tokens"
          % (a["anzahl"], a["schritte"], "{:,}".format(a["summe"])))
    print("GESAMT: %s Tokens (Anteil steuernd %.1f %%)" % ("{:,}".format(r["gesamt"]), r["anteil_haupt"]))
    print("  zum Vergleich je ZEILE gezaehlt (aeltere Messungen): %s" % "{:,}".format(r["gesamt_zeilen"]))


def selbsttest():
    import tempfile
    ok = rot = 0

    def pruef(name, ist, soll):
        nonlocal ok, rot
        if ist == soll:
            ok += 1; print("  [ok ] " + name)
        else:
            rot += 1; print("  [ROT] %s — erwartet %r, bekommen %r" % (name, soll, ist))

    d = tempfile.mkdtemp()
    os.makedirs(os.path.join(d, "slug"))
    t = os.path.join(d, "slug", "abc-123456789.jsonl")
    u = {"input_tokens": 1, "cache_read_input_tokens": 100, "cache_creation_input_tokens": 10, "output_tokens": 5}
    zeilen = [
        {"type": "assistant", "timestamp": "2026-10-01T10:00:00.100Z", "message": {"id": "m1", "usage": u}},
        {"type": "assistant", "timestamp": "2026-10-01T10:00:00.200Z", "message": {"id": "m1", "usage": u}},  # 2. Block
        {"type": "assistant", "timestamp": "2026-10-01T10:00:05.000Z", "message": {"id": "m2", "usage": u}},
        {"type": "assistant", "timestamp": "2026-10-01T11:00:00.000Z", "message": {"id": "m3", "usage": u}},  # ausserhalb
    ]
    io.open(t, "w", encoding="utf-8").write("\n".join(json.dumps(z) for z in zeilen) + "\n")
    os.makedirs(os.path.join(d, "slug", "abc-123456789", "subagents"))
    io.open(os.path.join(d, "slug", "abc-123456789", "subagents", "agent-x.jsonl"), "w", encoding="utf-8").write(
        json.dumps({"type": "assistant", "timestamp": "2026-10-01T10:00:02.000Z", "message": {"id": "a1", "usage": u}}) + "\n")
    r = messen(t, "2026-10-01T10:00:00Z", "2026-10-01T10:00:59Z")   # Sekundenform — wie aus der Quittung
    pruef("zwei Zeilen derselben Nachricht zaehlen EINMAL (2 Schritte)", r["haupt"]["schritte"], 2)
    pruef("Nachrichten-Summe 2 x 116", r["haupt"]["summe"], 232)
    pruef("Zeilen-Summe zum Vergleich 3 x 116", r["haupt"]["zeilen_summe"], 348)
    pruef("Nachricht ausserhalb des Fensters zaehlt nicht", r["haupt"]["bis"] < "2026-10-01T11", True)
    pruef("Subagent im Fenster gezaehlt", r["agenten"]["anzahl"], 1)
    pruef("Verlauf_max = 111", r["haupt"]["verlauf_max"], 111)
    q = os.path.join(d, "proj", ".claude-mind"); os.makedirs(q)
    io.open(os.path.join(q, "schritt-quittung.jsonl"), "w", encoding="utf-8").write("\n".join([
        '{"ereignis":"start","skill":"mind-all","ts":"2026-10-01T10:00:00Z","lauf":"L1-123456789"}',
        '{"ereignis":"schritt","name":"x","ts":"2026-10-01T10:00:40Z"}',
        '{"ereignis":"start","skill":"mind-all","ts":"2026-10-01T12:00:00Z","lauf":"L2-123456789"}']) + "\n")
    f, grund = fenster_aus_lauf(os.path.join(d, "proj"), "L1-123456789")
    pruef("Fenster aus der Lauf-ID: Start bis letzter Eintrag VOR dem naechsten Lauf",
          f, ("2026-10-01T10:00:00Z", "2026-10-01T10:00:40.999Z"))
    pruef("unbekannte Lauf-ID -> kein Fenster", fenster_aus_lauf(os.path.join(d, "proj"), "LX")[0], None)
    pruef("Sitzung aus der Lauf-Endung", [os.path.basename(x) for x in sitzung_aus_lauf("L1-123456789", d)],
          ["abc-123456789.jsonl"])
    print("\n  %d gruen · %d rot" % (ok, rot))
    return 0 if rot == 0 else 1


def main(argv):
    if "--selbsttest" in argv:
        return selbsttest()
    def wert(flag):
        return argv[argv.index(flag) + 1] if flag in argv and argv.index(flag) + 1 < len(argv) else None
    als_json = "--json" in argv
    if wert("--lauf"):
        lauf = wert("--lauf")
        projekt = wert("--projekt") or os.getcwd()
        f, grund = fenster_aus_lauf(projekt, lauf)
        if not f:
            sys.stderr.write("lauf_tokens: %s\n" % grund); return 2
        t = sitzung_aus_lauf(lauf)
        if len(t) != 1:
            sys.stderr.write("lauf_tokens: Sitzung zur Lauf-ID %s nicht eindeutig (%d Treffer)\n" % (lauf, len(t)))
            return 2
        von, bis = f
        transkript = t[0]
        bis = turn_ende(transkript, _ms(bis, ende=True))
        von = turn_start(transkript, _ms(von))
    elif wert("--transkript") and wert("--von") and wert("--bis"):
        transkript, von, bis = wert("--transkript"), wert("--von"), wert("--bis")
        if not os.path.isfile(transkript):
            sys.stderr.write("lauf_tokens: Transkript fehlt: %s\n" % transkript); return 2
    else:
        sys.stderr.write(__doc__.split("\n\n")[1] + "\n"); return 2
    r = messen(transkript, von, bis)
    if r["haupt"]["schritte"] == 0:
        sys.stderr.write("lauf_tokens: keine Assistenten-Nachricht im Fenster %s .. %s\n" % (von, bis))
        return 1
    if als_json:
        print(json.dumps(r, ensure_ascii=False, indent=1))
    else:
        bericht(r)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
