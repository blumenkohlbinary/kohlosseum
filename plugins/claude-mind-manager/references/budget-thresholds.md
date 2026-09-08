# Budget Thresholds — Token & Compliance Data

## SFEIR Institute Compliance Measurements

| Configuration | Lines | Compliance Rate | Source |
|--------------|-------|-----------------|--------|
| 5 rule files x 30 lines | 150 total | **96%** | SFEIR Institute |
| Single CLAUDE.md | <200 | **92%** | SFEIR Institute |
| Single CLAUDE.md | >400 | **71%** | SFEIR Institute |

**Key insight:** Modularizing into 5 separate rule files gains +4% compliance over a single file with the same content.

## Recommended Line Limits

| File | Optimal | Acceptable | Warning | Critical |
|------|---------|------------|---------|----------|
| CLAUDE.md (project) | <60 (HumanLayer) | <150 | 150-200 | >200 |
| CLAUDE.md (total across scopes) | <100 | <200 | 200-400 | >400 (71% compliance) |
| MEMORY.md | <150 | <180 | 180-195 | >195 (near hard 200 limit) |
| Single rule file | <30 | <50 | >50 | >100 |
| Topic files | <200 | <500 | >500 | — |

## Token Estimation Formulas

| Content Type | Tokens/Line | Source |
|-------------|-------------|--------|
| MEMORY.md (mixed) | ~7.5 | SFEIR (200 lines = 1,500 tokens) |
| CLAUDE.md (optimized) | ~9 | SFEIR (60% reduction after optimization) |
| CLAUDE.md (unoptimized) | ~22.5 | SFEIR |
| **Conservative estimate** | **~10** | Safe default for all files |

**Practical formula:** `estimated_tokens = line_count * 10`

## Authority Recommendations

| Authority | Recommendation | Weight |
|-----------|---------------|--------|
| Boris Cherny (Claude Code creator) | <1,000 tokens | Highest |
| Anthropic (official docs) | <200 lines | High |
| HumanLayer (power user) | <60 lines | Aggressive but proven |

## System Context Budget

| Component | Token Cost | Notes |
|-----------|-----------|-------|
| Claude Code system prompt | ~50 instructions | Already consumes part of the 150-200 instruction budget |
| Each MCP server | ~14,000 tokens | Tool definitions only |
| All skill descriptions | ~2% of context | Frontmatter always loaded |
| Auto-compaction threshold | ~167K/200K tokens | 75-83.5% capacity |

**Effective instruction budget:** LLMs reliably follow ~150-200 instructions. System prompt uses ~50. Remaining: **~100-150 user instructions** across all CLAUDE.md files, rules, and memory combined.

## Health Score Calculation

### Structure Quality (0-30 points)
- Uses markdown headings: +10
- Uses bullet points (not prose): +10
- Logical section ordering: +5
- Uses **rules** for modularity: +5 — ⛔ **`@import` zaehlt NICHT mehr.** Offiziell: *"Splitting into @path imports helps organization but doesn't reduce context, since imported files load at launch."* Ein Punktesystem, das eine wirkungslose Sparmassnahme belohnt, belohnt Umraeumen statt Kuerzen.

### Budget Efficiency (0-30 points)
- CLAUDE.md < 150 lines: +15 (150-200: +10, 200-300: +5, >300: 0)
- MEMORY.md < 150 lines: +15 (150-180: +10, 180-195: +5, >195: 0)

### Hygiene (0-25 points)
- No stale/non-existent paths: +10
- No contradictions between files: +10
- No duplicate entries across files: +5

### Best Practices (0-15 points)
- Has .claudeignore: +5
- ⛔ **ENTFALLEN v5.43.0** (war: *Rules use `globs:` not `paths:`: +5*). Die Zeile belohnte genau die Umschreibung, die P1 gestoppt hat. `globs:` ist der Cursor-Feldname; die offizielle Doku kennt nur `paths:`.
- Progressive disclosure (**Skills oder Commands** — nicht `@import`): +5. ⚠ Nur was VERZOEGERT laedt, ist progressive disclosure. `@import` laedt beim Start mit.


## ⚠ Das Beschreibungsbudget — gemessen 08.09.2026

Alle Skill-`description` zusammen konkurrieren um ein Budget. Bei Ueberlauf wirft
Claude Code Beschreibungen weg, **beginnend mit den am seltensten aufgerufenen** —
der Name bleibt stehen, die Beschreibung faellt. Es schreibt dabei eine Warnung ins
Debug-Log (`--debug`).

```
15 Skills insgesamt      7 396 Zeichen
davon dieses Plugin      5 740 Zeichen   = 78 %
laengste                 mind-update 893 · mind-memory 640 · mind-cleaner 627
```

⛔ **Wie voll das Budget ist, haengt an einer ungeklaerten Frage.** Offiziell heisst
es „1 % of the model's context window". Issue #57941 belegt empirisch, dass gegen
eine **feste ~200K-Basis** gerechnet wird, nicht gegen das echte Fenster:

| Lesart | Budget | wir liegen bei |
|---|---:|---:|
| 1 % des echten Fensters (1M) | ~15 000 | **39 %** |
| feste 200K-Basis (#57941) | ~8 000 | **92 %** |

⚠ **Fuenf Issues seit Mai 2026, keines geloest.** Solange das offen ist, ist die
zweite Lesart die vorsichtige — und dann faellt als erstes `mind-compact` oder
`mind-session-log` weg, weil sie am seltensten gerufen werden.

⭐ **Das ist eine MESSUNG, kein Defekt.** Nichts ist zu tun, solange nichts
ueberlaeuft. Die Zahl steht hier, damit sie beim naechsten Mal gefunden wird —
und der Pruefweg ist `--debug`, nicht Raten.