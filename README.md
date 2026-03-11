# Kohlosseum

**Die Plugin-Arena fuer Claude Code.**

Hier treten Plugins an, die deinen Claude Code Workflow auf das naechste Level bringen — von Multi-Agent Pipelines ueber Dokumentverarbeitung bis hin zu AI-gesteuerten Entwickler-Tools. Gebaut von [HackJ](https://github.com/blumenkohlbinary).

## Installation

```bash
# 1. Marketplace registrieren
/plugin marketplace add https://github.com/blumenkohlbinary/kohlosseum.git

# 2. Plugin installieren (z.B. TDO)
/plugin install tdo@kohlosseum
```

Danach in **Anpassen** > **Plugins** aktivieren/deaktivieren.

---

## Plugins

### TDO v11.2 — Text Density Optimizer

Verlustfreie Dokumentkompression und Multi-Dokument-Fusion.

| Feature | Beschreibung |
|---------|-------------|
| `/tdo:compress` | Einzeldokument-Kompression (45-55%, verlustfrei) |
| `/tdo:fuse-docs` | Multi-Dokument-Fusion mit 8-Stufen-Pipeline |

**Architektur:**
- 5 Skills, 9 Agents (8 Pipeline-Stufen + 1 Orchestrator)
- Modelle: 2x Opus, 4x Sonnet, 2x Haiku
- Flache Orchestrierung (Nesting-Tiefe 1)
- Dateibasierte Kommunikation via `.tdo-pipeline/`

**Qualitaetssicherung:**
- 5-Gate-Verifikation (Faktisch, Strukturell, Qualitaet, Source Coverage, Reconstruction)
- Chain-of-Verification (CoVe) Fact-Check
- Self-Consistency-Check (3 Versionen, 20+ Fakten)
- Protected Registry (Zahlen, Daten, Zitate zeichenidentisch)

```
/tdo:compress @dokument.md
/tdo:fuse-docs @doc1.md @doc2.md @doc3.md
```

---

*Mehr Plugins kommen bald. Stay tuned.*

## Lizenz

MIT
