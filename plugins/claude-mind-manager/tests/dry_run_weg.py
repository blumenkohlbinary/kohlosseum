# -*- coding: utf-8 -*-
u"""Prueft per SYNTAXBAUM, dass `dry_run` in rollback.py kein Code mehr ist.

⛔ WARUM NICHT GREPPEN. Mein erster Anlauf zaehlte `dry_run` mit `grep -v '^\\s*#'` und war
   rot — der Treffer stand in einem DOCSTRING, der genau erklaert, dass der Parameter
   entfallen ist. Ein grep unterscheidet Prosa nicht von Code; er sieht das Wort.
⭐ Der Parser unterscheidet: gefragt wird nach ARGUMENTEN und NAMEN im Baum, nicht nach
   Zeichen in einer Zeile. Damit darf der Docstring den Entfall beschreiben, ohne dass die
   Pruefung darauf anschlaegt — und ein wirklich zurueckgebauter Parameter faellt auf.
⚠ Die einzige erlaubte Fundstelle ist der Abbruch: die Zeichenkette `--dry-run` in der
  Argumentpruefung. Zeichenketten sind keine Namen, der Baum sieht sie getrennt.

Aufruf: python tests/dry_run_weg.py <pfad zu rollback.py>   -> 0 sauber, 1 Fund, 2 Aufruffehler
"""
import ast
import io
import sys


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("Aufruf: dry_run_weg.py <datei>\n")
        return 2
    try:
        quelle = io.open(argv[1], encoding="utf-8").read()
    except IOError as e:
        sys.stderr.write("nicht lesbar: %s\n" % e)
        return 2
    try:
        baum = ast.parse(quelle)
    except SyntaxError as e:
        sys.stderr.write("parst nicht: %s\n" % e)
        return 2

    funde = []
    for k in ast.walk(baum):
        if isinstance(k, (ast.FunctionDef, ast.AsyncFunctionDef)):
            for a in list(k.args.args) + list(k.args.kwonlyargs):
                if a.arg == "dry_run":
                    funde.append((a.lineno, "Parameter von %s()" % k.name))
        elif isinstance(k, ast.Name) and k.id == "dry_run":
            funde.append((k.lineno, "Name"))
        elif isinstance(k, ast.keyword) and k.arg == "dry_run":
            funde.append((getattr(k.value, "lineno", 0), "Schluesselwort-Argument"))

    if funde:
        for z, was in sorted(funde):
            sys.stderr.write("  Zeile %d: %s\n" % (z, was))
        sys.stderr.write("  %d Fund(e) — `dry_run` ist noch Code, nicht nur Prosa.\n" % len(funde))
        return 1
    print("dry_run kommt im Syntaxbaum nicht vor (Docstrings und Zeichenketten zaehlen nicht)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
