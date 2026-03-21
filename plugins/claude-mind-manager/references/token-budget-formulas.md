# Token Budget Formulas Quick Reference

## No Programmatic Token Access

- No API, CLI command, or env var to query per-file token usage
- `/context` shows visual color grid only, no JSON/log output
- Transcript (`transcript_path`) may contain session data but token counts are undocumented
- Best approach: line counting + estimation formulas

## Token Estimation Formulas

| Source | Lines | Tokens | Rate |
|--------|-------|--------|------|
| MEMORY.md | 200 | ~1,500 | **7.5 T/line** |
| CLAUDE.md (unoptimized) | 200 | ~4,500 | **22.5 T/line** |
| CLAUDE.md (optimized) | 200 | ~1,800 | **9 T/line** |

Key insight: 60% token reduction possible through better structure alone (same line count).

### Conservative Estimation Script
```bash
LINES=$(wc -l < "$MEMORY_FILE")
TOKENS=$((LINES * 8))  # conservative ~7.5 rounded up
```

## Overhead Sources

| Source | Token Cost |
|--------|-----------|
| 1 MCP server (tool definitions) | ~14,000 T |
| All skill descriptions | ~2% of context |
| Auto-compaction triggers at | ~167K / 200K T (~83.5%) |

## Warning Thresholds for Optimizer

| File | Threshold | Action |
|------|-----------|--------|
| MEMORY.md | > 180 lines | Warn: approaching 200-line hard limit |
| CLAUDE.md | > 150 lines | Recommend splitting via @import or rules |
| Rules total | > 250 lines | Warn: truncation risk |

## SFEIR Compliance Curve

| CLAUDE.md Length | Instruction Compliance |
|-----------------|----------------------|
| < 200 lines | 92-96% |
| > 400 lines | ~71% |

Progressive disclosure pattern: keep only essentials in CLAUDE.md, offload details to @import files or rules.

## Compaction Mechanics

- Auto-compaction threshold: ~167K of 200K tokens (community observation, not configurable)
- No official mechanism to mark information as compaction-resistant

### Compaction-Resistant Workarounds
1. **MEMORY.md** -- re-injected every session, survives compaction
2. **PreCompact hook** -- analyze transcript and save insights before compaction
3. **CLAUDE.md** -- always loaded, compaction-resistant by definition

### PreCompact Hook Capabilities
- Read transcript via `transcript_path`
- Read/write arbitrary files (extract insights, create diary entries)
- Distinguish `trigger`: "manual" vs "auto"
- Read `custom_instructions` for manual compact
- Whether exit 2 aborts compaction: UNKNOWN
- Whether hook can influence compaction prompt: UNKNOWN

## Budget Planning Formula

```
Total context cost =
  MEMORY.md lines x 7.5
  + CLAUDE.md lines x 9 (optimized) or x 22.5 (unoptimized)
  + Rules lines x 10 (estimate)
  + MCP servers x 14,000
  + Skills x ~2% of 200K
```

Target: keep total well under 167K to avoid premature auto-compaction.
