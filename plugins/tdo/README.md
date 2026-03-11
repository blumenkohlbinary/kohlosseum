# TDO v11.2 — Text Density Optimizer Plugin

## Uebersicht

| Feature | Beschreibung |
|---------|-------------|
| Kompression | 45-55% verlustfrei, 6-Stufen Engine |
| Fusion | 8-Stufen Multi-Agent Pipeline |
| Verifikation | 5 Gates + CoVe + Self-Consistency |
| Modelle | 2x Opus, 4x Sonnet, 2x Haiku |

## Commands

| Command | Beschreibung |
|---------|-------------|
| `/tdo:compress` | Einzeldokument-Kompression (45-55%, verlustfrei) |
| `/tdo:fuse-docs` | Multi-Dokument-Fusion (8-Stufen-Pipeline) |

## Pipeline-Stufen

1. **Parser** (haiku) — Strukturextraktion aus Dokumenten in JSON
2. **Dedup** (sonnet) — Woertliche + semantische Deduplizierung, UNIQUE-Tagging
3. **Contradiction** (opus) — 6-Typ NLI-Widerspruchserkennung
4. **Merger** (sonnet) — Graph-of-Thoughts + DARE-Text + TDO-Kompression
5. **Architect** (sonnet) — Blueprint-Erstellung, Order Type Detection
6. **Coherence** (sonnet) — Patchwork-Eliminierung, Ton-Harmonisierung
7. **Verification** (opus) — 5 Gates + CoVe + Self-Consistency
8. **Finalizer** (haiku) — Reines Dokument + Pipeline-Report

## Skills (5)

| Skill | Typ | Beschreibung |
|-------|-----|-------------|
| compress | User-facing | Einzeldokument-Kompression |
| fuse-docs | User-facing | Multi-Dokument-Fusion mit Orchestrierung |
| text-density-optimizer | Intern | 6-Stufen Compression Engine (CoD, Protected Registry) |
| dare-text-merger | Intern | DARE-Text Fusion (BASE + DELTAS + Reskalierung) |
| cove-verifier | Intern | Chain-of-Verification Fact-Check |

## Agents (9)

Alle Agents haben:
- `permissionMode: acceptEdits` — Keine Permission-Prompts
- `disallowedTools: Agent` — Kein Sub-Agent-Spawning
- `color` — Visuelle Identifikation

| Agent | Model | Color | Stufe |
|-------|-------|-------|-------|
| doc-parser-agent | haiku | cyan | 1 |
| semantic-dedup-agent | sonnet | blue | 2 |
| contradiction-detector-agent | opus | red | 3 |
| graph-merger-agent | sonnet | green | 4 |
| doc-architect-agent | sonnet | magenta | 5 |
| coherence-agent | sonnet | blue | 6 |
| verification-agent | opus | yellow | 7 |
| doc-finalizer-agent | haiku | green | 8 |
| doc-fusion-orchestrator | opus | cyan | Protokoll |

## Output

- `stage-8-final.md` — Reines Enddokument (ohne Tags, ohne Metriken)
- `stage-8-report.md` — Pipeline-Report (Source Coverage, Widerspruchsindex, Metriken)

## Version

v11.2.0 (2026-03-11)
