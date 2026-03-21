# Prompt Quality Guide for CLAUDE.md Generation

Reference for `/mind:generate` — how to write high-quality instructions that Claude follows reliably.

## Core Principle: Structured > Verbose

LLMs follow structured, dense instructions better than verbose prose.
- Bullet points > paragraphs (+20-30% instruction accuracy)
- MUST/NEVER keywords > polite suggestions (+15% compliance)
- One instruction per line > multi-sentence explanations

## The 5 Non-Negotiable Quality Criteria

### 1. Clear Structure
- Use H2/H3 headings for logical sections
- Group by topic: Commands → Architecture → Conventions → Gotchas
- Keep each section focused on ONE concern

### 2. Actionable Instructions
- Every line should be something Claude can ACT on
- Bad: "We value clean code and good practices"
- Good: "MUST use vitest for all tests. Run: `npm test`"

### 3. Optimal Length (Token Efficiency)
- CLAUDE.md sweet spot: 50-200 lines (~500-2000 tokens)
- >400 lines: compliance drops to ~71% (SFEIR data)
- Use @imports for detailed docs (architecture, database, deployment)
- Use .claude/rules/ for file-scoped conventions

### 4. Constraint Separation
- **Hard constraints** (MUST/NEVER): Non-negotiable rules
  - "NEVER commit .env files"
  - "MUST run tests before suggesting PR"
- **Soft constraints** (PREFER/AVOID): Flexible guidelines
  - "PREFER functional components over class components"
- **Safety constraints**: Security boundaries
  - "NEVER execute rm -rf without confirmation"

### 5. Specificity Over Generality
- Bad: "Use meaningful variable names" (linter job, not CLAUDE.md)
- Bad: "Write clean code" (too vague to act on)
- Good: "Error responses MUST use ApiError class from src/errors.ts"
- Good: "Database migrations: `npm run db:migrate` — NEVER edit migration files after merge"

## Anti-Patterns to Avoid

| Anti-Pattern | Why It Fails | Fix |
|---|---|---|
| Wall of prose | Claude skips/forgets middle sections | Use bullets + headings |
| Linter rules in CLAUDE.md | Redundant with tooling config | Reference config file instead |
| Duplicating README | Wastes token budget | @import README sections |
| Generic advice | No actionable value | Delete or make specific |
| Version numbers without context | Goes stale quickly | Use `node --version` or omit |
| Nested bullet points (>3 levels) | Hard to parse | Flatten or extract to separate file |

## Required Sections for Generated CLAUDE.md

Every generated CLAUDE.md MUST include:

1. **Build/Test Commands** — exact commands to build, test, lint, deploy
2. **Architecture Overview** — key directories, entry points, data flow (brief)
3. **Code Conventions** — naming, patterns, error handling specific to THIS project
4. **Common Gotchas** — things that break, non-obvious behaviors, known issues

Optional but recommended:
5. **@imports** — links to detailed docs (if they exist)
6. **Tech Stack** — framework versions, key dependencies
7. **Workflow** — PR process, branch naming, CI requirements

## Format Rules

- Start with project name as H1 (or skip H1, start with H2 sections)
- Use code blocks for commands: `` `npm run build` ``
- Use MUST/NEVER/PREFER for emphasis (not bold/italic)
- One blank line between sections, no blank lines between bullets
- Keep lines under 100 characters where possible
- No emojis in CLAUDE.md (noise, wastes tokens)

## Generation Checklist

Before finalizing a generated CLAUDE.md:
- [ ] All build/test commands are correct and runnable
- [ ] No generic advice that applies to any project
- [ ] No duplicated information from README or package.json
- [ ] Total lines < 200 (or uses @imports for overflow)
- [ ] Every instruction is specific to THIS project
- [ ] File paths referenced actually exist
- [ ] No secrets, tokens, or credentials included
