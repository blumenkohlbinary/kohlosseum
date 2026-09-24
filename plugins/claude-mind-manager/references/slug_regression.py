#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gegenprobe fuer hash_project_dir() aus hooks/lib.sh (NEU v5.7.0).

WOZU. Bis v5.6.0 ersetzte die Funktion nur `[\\: ()]` durch Bindestriche. Claude Code
ersetzt aber JEDES Nicht-Alphanumerische. Die Folge war kein Absturz, sondern etwas
Schlimmeres: `get_memory_dir` fiel still in den Fallback, und der Skill arbeitete an einem
anderen Ort als dem, an dem die Erinnerungen liegen. Aufgefallen ist es nur, weil in
`Entwicklung&Forschung` bei JEDEM Lauf eine Warnung erschien.

DIE PRUEFUNG MUSS SCHEITERN KOENNEN. Deshalb faehrt sie am Ende die ALTE Regel gegen
dieselben Faelle. Besteht die alte Regel, misst dieser Prueftand nichts und alle
Ergebnisse sind ungueltig (Rueckgabewert 3).

⛔ WAS ES BIS v5.132.0 NICHT MASS (Etappe 44, Udos Fund): dieses Skript spiegelte die
   REGEL in Python — und Python ersetzt ZEICHENweise. Die Implementierung in `lib.sh`
   lief ueber `sed`, das in MSYS BYTEWEISE ersetzt: `ü` = `c3 bc` = zwei Striche. Der
   Spiegel war also gruen, waehrend die Funktion log. Ein Gate, das nur die Regel prueft
   und nie die Implementierung, kann diese Klasse nicht finden.
   Seit v5.133.0 faehrt `--bash` die ECHTE Funktion aus `hooks/lib.sh` gegen dieselben
   Vektoren. ⚠ Ohne bash/lib.sh wird das AUSGEWIESEN, nicht stillschweigend uebersprungen.

Aufruf:
    python slug_regression.py                 # nur die festen Pruefvektoren
    python slug_regression.py --bash           # zusaetzlich gegen hash_project_dir in lib.sh
    python slug_regression.py --live <wurzel>  # zusaetzlich gegen ~/.claude/projects

Rueckgabe: 0 = alles gruen  |  1 = Faelle rot  |  3 = Pruefstand ungueltig
"""
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", newline="")

BS = chr(92)


def neu(win_path):
    """Die Regel ab v5.7.0 — Spiegelbild von: sed 's|[^A-Za-z0-9]|-|g' | sed 's|^-*||'"""
    return re.sub(r"^-*", "", re.sub(r"[^A-Za-z0-9]", "-", win_path))


def alt(win_path):
    """Die Regel bis v5.6.0 — sed 's|[" + BS + BS + ": ()]|-|g'. Nur fuer die Gegenprobe."""
    return re.sub(r"^-*", "", re.sub(r"[" + BS + BS + r":\s()]", "-", win_path))


# (Eingabe, erwarteter Slug, warum dieser Fall drin ist)
VEKTOREN = [
    (r"C:\CD\KOHLEKTIV", "C--CD-KOHLEKTIV",
     "Grundfall: Doppelpunkt und Backslash"),
    (r"C:\CD\KOHLEKTIV\Entwicklung&Forschung", "C--CD-KOHLEKTIV-Entwicklung-Forschung",
     "DER Ausloeser: '&' schickte Memory in den Fallback"),
    (r"C:\CD\KOHLEKTIV\_claude_vm", "C--CD-KOHLEKTIV--claude-vm",
     "'_' wird ebenfalls ersetzt — von der alten Regel uebersehen"),
    (r"C:\CD\KOHLEKTIV\PC & Software\Virtuelle Box",
     "C--CD-KOHLEKTIV-PC---Software-Virtuelle-Box",
     "der Werkzeugkasten seit 15.09.2026: '&' mit Leerzeichen beidseits ergibt DREI Bindestriche"),
    (r"C:\CD\KOHLEKTIV\APP - Zustellplan", "C--CD-KOHLEKTIV-APP---Zustellplan",
     "Leerzeichen-Strich-Leerzeichen ergibt DREI Bindestriche"),
    (r"C:\CD\KOHLEKTIV\Plugin - Entwicklung\Claude Mind Manager",
     "C--CD-KOHLEKTIV-Plugin---Entwicklung-Claude-Mind-Manager",
     "dieses Projekt"),
    (r"C:\CD\KOHLEKTIV\Joplin\plugin-design", "C--CD-KOHLEKTIV-Joplin-plugin-design",
     "vorhandene Bindestriche bleiben Bindestriche"),
    (r"C:\CD\KOHLEKTIV\Entwicklung&Forschung\Pc Forschung",
     "C--CD-KOHLEKTIV-Entwicklung-Forschung-Pc-Forschung",
     "'&' und Leerzeichen zusammen"),
    (r"C:\CD\KOHLEKTIV\Tobis Tools\Namens ersteller",
     "C--CD-KOHLEKTIV-Tobis-Tools-Namens-ersteller",
     "mehrere Leerzeichen ueber zwei Ebenen"),
    (r"C:\a.b\c", "C--a-b-c", "Punkt wird ersetzt (.claude-worktrees)"),
    (r"C:\x(y)z", "C--x-y-z", "Klammern — die alte Regel konnte das schon"),
    (r"C:\a+b,c", "C--a-b-c", "Plus und Komma"),
    (r"\\server\freigabe", "server-freigabe", "UNC-Pfad: fuehrende Bindestriche fallen weg"),
    # v5.133.0 (Etappe 44): Mehrbyte-Zeichen. ⛔ Die Erwartung stammt aus dem ECHTEN
    # Ordnernamen unter ~/.claude/projects, nicht aus der Formel — drei Belege:
    # C--CD-KOHLEKTIV-B-rokratie, ...-Steuer--ELSTER-, ...-Wohngeld---Sonstiges.
    ("C:" + BS + "CD" + BS + "KOHLEKTIV" + BS + "Bürokratie", "C--CD-KOHLEKTIV-B-rokratie",
     "Udos Fund: ü ist EIN Zeichen, aber ZWEI Bytes (c3 bc) — sed machte zwei Striche"),
    ("C:" + BS + "CD" + BS + "KOHLEKTIV" + BS + "Bürokratie" + BS + "Steuer (ELSTER)",
     "C--CD-KOHLEKTIV-B-rokratie-Steuer--ELSTER-",
     "Umlaut UND Sonderzeichen in einem Pfad (echter Ordner)"),
    ("C:" + BS + "x" + BS + "Straße", "C--x-Stra-e",
     "ß ist ebenfalls zwei Bytes (c3 9f)"),
    ("C:" + BS + "x" + BS + "Café", "C--x-Caf-",
     "é (c3 a9) am Wortende — der Strich steht am Schluss"),
]


def main():
    rot = []
    print("=== Pruefvektoren (NEUE Regel) ===")
    for eingabe, soll, warum in VEKTOREN:
        ist = neu(eingabe)
        gut = ist == soll
        if not gut:
            rot.append((eingabe, soll, ist))
        print("  %s %-52s -> %s" % ("[ok ]" if gut else "[ROT]", warum, ist))
        if not gut:
            print("        erwartet: %s" % soll)

    # --- Negativkontrolle: die ALTE Regel MUSS durchfallen -------------------
    print()
    print("=== NEGATIVKONTROLLE: alte Regel muss scheitern ===")
    alt_rot = [e for e, s, _ in VEKTOREN if alt(e) != s]
    print("  alte Regel faellt bei %d von %d Faellen durch" % (len(alt_rot), len(VEKTOREN)))
    if not alt_rot:
        print()
        print("  ABBRUCH: die alte Regel besteht alle Faelle.")
        print("  Dieser Pruefstand misst nichts — alle Ergebnisse oben sind ungueltig.")
        return 3
    for e in alt_rot[:4]:
        print("     %s -> %s" % (e, alt(e)))

    # --- v5.133.0: gegen die ECHTE bash-Funktion ----------------------------
    # ⛔ DAS IST DER TEIL, DER DEN FEHLER FINDEN KANN. Alles oben prueft die Regel
    #    gegen sich selbst; hier laeuft `hash_project_dir` aus `hooks/lib.sh`.
    if "--bash" in sys.argv:
        import subprocess
        lib = os.path.join(os.environ.get("CLAUDE_PLUGIN_ROOT", ""), "hooks", "lib.sh")
        if not os.path.isfile(lib):
            lib = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                               "hooks", "lib.sh")
        print()
        print("=== Gegen die ECHTE Funktion (hooks/lib.sh) ===")
        bash = None
        for k in ("bash", "/usr/bin/bash", "C:/Program Files/Git/bin/bash.exe"):
            try:
                if subprocess.run([k, "-c", "exit 0"], capture_output=True).returncode == 0:
                    bash = k
                    break
            except OSError:
                continue
        if bash is None or not os.path.isfile(lib):
            print("  ⚠ UNGEPRUEFT: bash oder hooks/lib.sh nicht erreichbar (%s)." % lib)
            print("     Ein uebersprungener Fall ist KEIN bestandener.")
            rot.append(("--bash", "gefahren", "nicht erreichbar"))
        else:
            skript = (". '%s' >/dev/null 2>&1 || exit 9\n" % lib.replace("\\", "/")
                      + "while IFS= read -r p; do hash_project_dir \"$p\"; done")
            # ⛔ Abschluss-Zeilenumbruch: ohne ihn verschluckt `while read` die LETZTE Zeile.
            #    Eigener Fehlgriff beim Bau — der Café-Vektor kam leer zurueck, waehrend die
            #    Funktion selbst `C--x-Caf-` lieferte. Ein Pruefstand, der den letzten Fall
            #    verschluckt, meldet einen Fehler, den es nicht gibt.
            eingaben = "\n".join(e for e, _, _ in VEKTOREN) + "\n"
            r = subprocess.run([bash, "-c", skript], input=eingaben.encode("utf-8"),
                               capture_output=True)
            aus = r.stdout.decode("utf-8", "replace").split("\n")
            for i, (eingabe, soll, warum) in enumerate(VEKTOREN):
                ist = aus[i].strip() if i < len(aus) else "(keine Ausgabe)"
                gut = ist == soll
                if not gut:
                    rot.append((eingabe, soll, ist))
                print("  %s %-52s -> %s" % ("[ok ]" if gut else "[ROT]", warum, ist))
                if not gut:
                    print("        erwartet: %s" % soll)

    # --- Optional: gegen die real vorhandenen Claude-Code-Ordner -------------
    if "--live" in sys.argv:
        i = sys.argv.index("--live")
        wurzel = sys.argv[i + 1] if len(sys.argv) > i + 1 else None
        pd = os.path.expanduser("~/.claude/projects")
        if wurzel and os.path.isdir(wurzel) and os.path.isdir(pd):
            echte = {d for d in os.listdir(pd) if os.path.isdir(os.path.join(pd, d))}
            gefunden = verloren = 0
            for d, unter, _ in os.walk(wurzel):
                if d.count(os.sep) - wurzel.count(os.sep) > 2:
                    unter[:] = []
                    continue
                unter[:] = [u for u in unter if not u.startswith((".", "_"))]
                win = d.replace("/", BS)
                if neu(win) in echte:
                    gefunden += 1
                if alt(win) in echte and neu(win) not in echte:
                    verloren += 1
            print()
            print("=== Live gegen ~/.claude/projects ===")
            print("  neue Regel trifft %d vorhandene Ordner, verliert %d" % (gefunden, verloren))
            if verloren:
                rot.append(("live", "0 Verluste", "%d Verluste" % verloren))

    print()
    print("=" * 60)
    if rot:
        print("  ERGEBNIS: %d von %d ROT" % (len(rot), len(VEKTOREN)))
        return 1
    print("  ERGEBNIS: alle %d Faelle bestanden%s, Negativkontrolle greift"
          % (len(VEKTOREN), " (Regel UND bash)" if "--bash" in sys.argv else " (nur die REGEL — --bash prueft die Implementierung)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
