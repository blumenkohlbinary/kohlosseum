---
name: audit
description: |
  Comprehensive UI/design audit dispatching 10 specialist auditors in parallel, then synthesizing findings via Opus-Critic. Use when user says: "audit", "review design", "check UI", "a11y check", "design lint", "CSS review", "überprüfe design", "auditiere", "review meine styles", "design forge", "forge audit", "lint my css", "wcag check", "accessibility audit". Output: triaged report (Blocker/High/Medium/Nitpick) with confidence-scored findings and auto-fix hints.
allowed-tools: Read, Grep, Glob, Task, Write, Bash
argument-hint: "[path-or-glob] [--scope=...] [--premium] [--since=<git-ref>]"
model: sonnet
---

# /design-forge:audit — Orchestrated Multi-Specialist UI Audit

## Purpose

Run 10 specialist auditors in parallel, each writing a JSON findings artifact. An Opus-powered design-critic then synthesizes, deduplicates, calibrates confidence, and produces a triaged consolidated report. All traces archived in `.design-forge/reports/` for incremental future runs.

## Trigger Conditions

**Explicit:**
- User invokes `/design-forge:audit` (with optional args)
- User says any trigger phrase listed in description

**Implicit (via hook, if enabled):**
- PostToolUse on Edit/Write/MultiEdit of CSS, HTML, JSX, TSX, Vue, Svelte — IF `.design-forge/` exists AND quick-validate.sh is enabled

## Arguments

- `$1` (optional): Path or glob. Default: project root.
- `--scope=<set>`: Comma-separated subset of auditors to run. Options: css, a11y, color, typography, layout, system, performance, motion, interaction, visual, all. Default: all.
- `--premium`: Force Opus for all auditors (not just critic). Default: Sonnet + Opus-critic only.
- `--since=<git-ref>`: Incremental mode — only files changed since ref (e.g. HEAD, main, v1.0.0).

## Orchestration — Step by Step

### Step 1: Ensure Output Directory

```bash
mkdir -p .design-forge/findings .design-forge/reports .design-forge/screenshots
```

### Step 2: Context Loading

Read `.design-forge/system.md` if exists. Extract:
- `rules.spacing_grid`, `rules.breakpoints`, `rules.contrast_min_ratio`, `rules.icon_sizes`
- `tokens.semantic.*` token names
- `decisions[]` for context

If missing: Warn user: "No `.design-forge/system.md` found. For best results, first invoke /forge-init to create one. Proceeding with built-in defaults."

### Step 3: Scope Resolution

If `--since=<ref>` provided:
```bash
git diff --name-only --diff-filter=ACM <ref> | grep -E '\.(css|scss|sass|html|jsx|tsx|vue|svelte)$'
```

Else: expand `$1` glob or default to project root with frontend-extension filter.

Report resolved scope count to user before dispatch.

### Step 4: Parallel Dispatch via Task-Tool

Launch all 10 auditors in a **single assistant turn** with multiple Task-Tool calls in parallel:

- `Task(subagent_type="css-auditor", description="CSS-Audit", prompt=<scope-brief>)`
- `Task(subagent_type="a11y-auditor", description="A11y-Audit", prompt=<scope-brief>)`
- `Task(subagent_type="color-auditor", description="Color-Audit", prompt=<scope-brief>)`
- `Task(subagent_type="typography-auditor", description="Typography-Audit", prompt=<scope-brief>)`  [M2]
- `Task(subagent_type="layout-auditor", description="Layout-Audit", prompt=<scope-brief>)`
- `Task(subagent_type="system-auditor", description="System-Audit", prompt=<scope-brief + system.md>)`
- `Task(subagent_type="performance-auditor", description="Perf-Audit", prompt=<scope-brief>)`  [M2]
- `Task(subagent_type="motion-auditor", description="Motion-Audit", prompt=<scope-brief>)`  [M2]
- `Task(subagent_type="interaction-auditor", description="Interaction-Audit", prompt=<scope-brief>)`  [M2]
- `Task(subagent_type="visual-auditor", description="Visual-Audit", prompt=<scope-brief>)`  [M5]

If `--scope=<set>`: only dispatch agents in set.
If a requested agent does not exist yet (pre-M2 M5 milestone), skip gracefully and note in coverage.

**Scope-Brief Template** (identical across agents, parameterized):

```
Audit scope: <resolved paths/files>
Memory baseline: .design-forge/system.md (status: found|missing)
Mode: standard | --premium | --since=<ref>

Your job:
- Run YOUR rule-set strictly within YOUR domain.
- Write findings to .design-forge/findings/<your-agent-name>.json per schemas/finding.schema.json.
- Include coverage object with rules_executed count.
- Stay in scope — delegate cross-domain concerns in evidence.context, do not flag them.
- Report back: total findings count + coverage summary.
```

### Step 5: Gather Artifacts

After all Task-Tool calls complete, list findings:

```bash
ls -la .design-forge/findings/*.json 2>/dev/null
```

Compare against dispatched agents. If mismatch, log gap.

### Step 6: Dispatch Critic

```
Task(
  subagent_type="design-critic",
  description="Synthese der Auditor-Reports",
  prompt="""
Read ALL artifacts from .design-forge/findings/*.json.

Your job per your system prompt:
1. Coverage analysis (expected vs actual agents)
2. Deduplication (same file+line+root-cause from multiple agents → merge)
3. Cross-agent confidence calibration
4. False-positive filtering via anti-patterns + decision-log
5. Severity recalibration per triage matrix
6. 5D quality score computation
7. Write: .design-forge/reports/audit-<timestamp>.json AND .md

Mode: <standard|premium>
System-md status: <found|missing>
"""
)
```

### Step 7: Present Result

Read `.design-forge/reports/audit-<latest>.md` and display to user:

```
## Audit Report — <timestamp>

### Triage
- 🔴 Blocker: N
- 🟠 High:    N
- 🟡 Medium:  N
- 🔵 Nitpick: N

### Top Blockers
(top 3 with file:line + fix-hint)

### Coverage
- Agents reported: N/10
- Rules executed: total
- Completeness: N%

### Quality Overall: N% {✅|⚠️|❌}

### Next Steps
- Full report: .design-forge/reports/audit-<ts>.md
- To fix safe issues: ask "fix the safe design-forge findings"
- For interactive review: ask "walk me through the medium-severity findings"
```

## Error Handling

- Task-Tool failure on any agent: log, continue with remaining, report in coverage gap
- Critic failure: fallback — concatenate raw findings with warning banner
- Empty scope: "No files matched" + exit gracefully, no artifact written
- `.design-forge/` not writable: prompt user to check permissions

## Incremental Mode

When `--since=<ref>`:
1. Filter scope via git diff
2. Load previous latest report: `.design-forge/reports/audit-<latest>.json`
3. Compute delta: newly-introduced vs resolved findings
4. Pass delta-context in scope-brief
5. Critic outputs "changed since <ref>" section in MD report

## Premium Mode

`--premium` overrides `model: sonnet` to `model: opus` on all auditors.

Warning: ~10× cost. Intended for pre-release audits.

## Verification

Before completing:
- `.design-forge/reports/audit-<ts>.md` readable
- `.design-forge/reports/audit-<ts>.json` schema-valid
- All expected agents present OR documented in coverage.gaps
- Summary message to user includes actionable next-steps

## Related Skills

Invoke via natural language (not slash commands — these are hidden skills):
- Fix findings → design-fixer agent
- Initialize system.md → forge-init skill
- Extract tokens from existing code → forge-extract skill
- Check status → forge-status skill
- Health check → forge-doctor skill
