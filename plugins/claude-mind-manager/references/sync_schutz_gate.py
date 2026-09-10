#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Ist die Version, auf der eine LAUFENDE Sitzung steht, vor dem Aufraeumer geschuetzt?

⛔ DER VORFALL, GEGEN DEN DAS GEBAUT IST — zweimal passiert:

    19.08.2026  Der zweite Sync-Lauf entfernte 5.3.1, auf der die Sitzung lief.
                Alle Hooks waren danach stumm. `KEEP_VERSIONS=2` haelt genau
                EINEN Durchlauf. Steht in `memory/sync-loescht-laufende-version.md`.
    10.09.2026  5.70.0 stand NICHT in `.sync-protect.json` — die Version, auf der
                drei Sitzungen gleichzeitig liefen. Sie ueberlebte als
                zweithoechste zufaellig; mit der naechsten Version waere sie die
                dritte gewesen und weg.

⭐ **Der Schutz ist seit dem 19.08.2026 dokumentiert und wurde trotzdem nicht
   eingetragen.** Er haengt an einem Handgriff im Ablauf, den niemand prueft —
   und genau das ist der Unterschied zwischen einer Regel und einer Ratsche.
   `kontext-anlegen.md`: was ERZWUNGEN werden muss, gehoert in ein Werkzeug.

## ⛔ HIER STAND EINE STUNDE LANG "UNGEMESSEN" — UND DAS WAR FALSCH

Die erste Fassung sagte: *„welche Version eine laufende Sitzung haelt, ist von
aussen UNGEMESSEN"*, und nahm die **registrierte** Version als Ersatz.

⭐ **Claude Code schreibt es auf die Platte.** Jede Cache-Version traegt ein
Verzeichnis `.in_use/<pid>` mit `{"pid":…, "procStartFt":…}` — **eine Datei je
laufendem Prozess, der diese Version haelt.** Gemessen 10.09.2026:

    5.2.0    6 Eintraege, davon LEBEND 6      <- 72 Versionen alt, ungeschuetzt
    5.70.0   7 Eintraege, davon LEBEND 7
    5.74.0   6 Eintraege, davon LEBEND 6
    5.43.0   6 Eintraege, davon LEBEND 0      <- Leichen, kein Schutzgrund

⛔ **Der Ersatz war schlechter als die Sache selbst.** Der registrierte Stand
kennt genau EINE Version; gemessen halten die Prozesse **sechs** gleichzeitig,
darunter eine, die kein Aufraeumer je auf dem Schirm hatte.

## ⛔ WAS DAS ERKLAERT — drei offene Fragen auf einmal

1. **Warum 5.2.0 jeden Aufraeumer ueberlebt:** sechs lebende Prozesse halten sie.
   ⚠ Das Sync-Skript kennt `.in_use` mit **0 Treffern** und meldet trotzdem
   `removed: 5.2.0` — eine Aufraeumung, die stillschweigend nichts tut.
2. **Warum ihr Ordner das heutige Datum traegt:** die Prozesse schreiben ihre
   Eintraege nach.
3. **Warum ein Skill aus ihr geladen werden kann:** sie ist da und gilt als
   benutzt. ⛔ **Ein Loeschen waere hier aktiv falsch**, solange die Prozesse
   laufen — es nimmt sechs Sitzungen ihre Hooks.

## Was das Gate prueft

**Jede Version mit mindestens einem LEBENDEN Eintrag muss geschuetzt sein.**

⚠ **Fail-safe nach oben:** laesst sich die Lebendigkeit einer PID nicht
feststellen, gilt sie als LEBEND. Zu viel Schutz kostet Platz, zu wenig kostet
eine Sitzung.

## Aufruf

    python references/sync_schutz_gate.py <marketplace> <plugin>

Rueckgabe: 0 = geschuetzt · 1 = ⛔ NICHT geschuetzt · 2 = Aufruffehler
           3 = ⛔ nicht messbar (Dateien fehlen) — KEIN bestandenes Gate
"""
import io
import json
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HOME = os.path.expanduser("~")


def registrierte_version(marktplatz, plugin):
    """Die Version, die JETZT registriert ist — der belastbare Ersatz."""
    p = os.path.join(HOME, ".claude", "plugins", "installed_plugins.json")
    if not os.path.isfile(p):
        return None, "installed_plugins.json fehlt: %s" % p
    try:
        d = json.load(io.open(p, encoding="utf-8"))
    except (ValueError, OSError) as e:
        return None, "installed_plugins.json unlesbar: %s" % e
    # ⛔ JSON WIRD GEPARST, NICHT GEGREPPT (`shell-windows.md`): die Maskierung
    #    der Windows-Pfade im JSON trifft kein Textmuster.
    eintraege = d.get("plugins", {}).get("%s@%s" % (plugin, marktplatz))
    if not eintraege:
        return None, "kein Eintrag fuer %s@%s" % (plugin, marktplatz)
    for e in eintraege:
        v = e.get("version")
        if v:
            return v, None
    return None, "Eintrag ohne version-Feld"


def _lebende_pids():
    """Die PIDs laufender Prozesse — oder None, wenn nicht feststellbar.

    ⚠ None heisst FAIL-SAFE NACH OBEN: dann gilt jeder Eintrag als lebend.
      Zu viel Schutz kostet Platz, zu wenig kostet einer Sitzung ihre Hooks.
    """
    import subprocess
    for befehl in (["tasklist", "/FO", "CSV", "/NH"], ["ps", "-e", "-o", "pid="]):
        try:
            p = subprocess.run(befehl, capture_output=True, text=True,
                               encoding="utf-8", errors="replace", timeout=20)
        except (OSError, subprocess.SubprocessError):
            continue
        if p.returncode != 0 or not p.stdout:
            continue
        pids = set()
        for zeile in p.stdout.splitlines():
            if befehl[0] == "tasklist":
                teile = [t.strip('" ') for t in zeile.split('","')]
                if len(teile) > 1 and teile[1].isdigit():
                    pids.add(teile[1])
            else:
                z = zeile.strip()
                if z.isdigit():
                    pids.add(z)
        if pids:
            return pids
    return None


def gehaltene_versionen(marktplatz, plugin):
    """{version: (eintraege, lebend)} aus `.in_use/<pid>` — was WIRKLICH laeuft."""
    wurzel = os.path.join(HOME, ".claude", "plugins", "cache", marktplatz, plugin)
    if not os.path.isdir(wurzel):
        return None
    lebend = _lebende_pids()
    out = {}
    for v in sorted(os.listdir(wurzel)):
        d = os.path.join(wurzel, v, ".in_use")
        if not os.path.isdir(d):
            continue
        try:
            eintraege = [x for x in os.listdir(d)]
        except OSError:
            continue
        if not eintraege:
            continue
        # ⚠ lebend is None -> ALLES gilt als lebend (fail-safe nach oben).
        n_leb = len(eintraege) if lebend is None else sum(
            1 for x in eintraege if x.split(".")[0] in lebend)
        out[v] = (len(eintraege), n_leb)
    return out


def geschuetzte_versionen(marktplatz, plugin):
    p = os.path.join(HOME, ".claude", "plugins", "cache", marktplatz, plugin,
                     ".sync-protect.json")
    if not os.path.isfile(p):
        return None, p
    try:
        return set(json.load(io.open(p, encoding="utf-8"))), p
    except (ValueError, OSError):
        return None, p


def main(argv):
    if len(argv) < 3:
        print("Aufruf: sync_schutz_gate.py <marketplace> <plugin>")
        return 2
    markt, plug = argv[1], argv[2]

    ver, fehler = registrierte_version(markt, plug)
    schutz, spfad = geschuetzte_versionen(markt, plug)

    print("=" * 74)
    print("  SYNC-SCHUTZ — laeuft eine Sitzung auf einer ungeschuetzten Version?")
    print("=" * 74)

    if ver is None:
        print("  ⛔ NICHT MESSBAR: %s" % fehler)
        print("     Das ist KEIN bestandenes Gate. Von Hand nachsehen.")
        return 3
    if schutz is None:
        print("  ⛔ NICHT MESSBAR: .sync-protect.json fehlt oder ist unlesbar")
        print("     %s" % spfad)
        print("     Das ist KEIN bestandenes Gate.")
        return 3

    gehalten = gehaltene_versionen(markt, plug)
    if gehalten is None:
        print("  ⛔ NICHT MESSBAR: Cache-Verzeichnis fehlt")
        return 3

    print("  registriert: %s   ·   geschuetzte Eintraege: %d" % (ver, len(schutz)))
    print()
    print("  Version   .in_use   lebend   geschuetzt")
    offen = []
    for v in sorted(gehalten, key=lambda x: [int(t) if t.isdigit() else 0
                                             for t in x.split(".")]):
        n, leb = gehalten[v]
        g = v in schutz
        if leb > 0 and not g:
            offen.append(v)
        print("  %-9s %6d %8d   %s%s" % (v, n, leb, "ja" if g else "NEIN",
                                         "   ⛔" if (leb > 0 and not g) else ""))
    print()

    # ⛔ Die registrierte Version bleibt ein zweites Signal — sie ist die, die
    #    jede nach dem Sync gestartete Sitzung laden wird.
    if ver not in schutz and ver not in offen:
        offen.append(ver)
        print("  ⛔ die REGISTRIERTE Version %s ist ebenfalls ungeschuetzt." % ver)

    if not offen:
        print("  ✅ Jede Version, die ein lebender Prozess haelt, ist geschuetzt.")
        print("  ⚠ Eintraege ohne lebende PID sind Leichen und KEIN Schutzgrund.")
        return 0

    print("  ⛔ UNGESCHUETZT, obwohl in Benutzung: %s" % ", ".join(offen))
    print("     Faellt eine davon aus den zwei hoechsten, sind die Hooks jeder")
    print("     darauf laufenden Sitzung stumm — gemessen 19.08.2026 und 10.09.2026.")
    print("  ⛔ NICHT LOESCHEN, um das zu 'loesen': solange Prozesse sie halten,")
    print("     kostet das Loeschen genau diese Sitzungen. Eintragen, nicht raeumen.")
    print()
    print("  Eintragen VOR dem Sync:")
    for v in offen:
        print("     python -c \"import io,json,os,time; p=os.path.expanduser("
              "'~/.claude/plugins/cache/%s/%s/.sync-protect.json'); "
              "d=json.load(io.open(p,encoding='utf-8')); d['%s']=time.time(); "
              "io.open(p,'w',encoding='utf-8',newline='\\n')"
              ".write(json.dumps(d,indent=2,sort_keys=True))\"" % (markt, plug, v))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
