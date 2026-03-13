---
name: analyze
description: "Analyze code for smells, complexity, and quality issues without making any changes. Use when the user says 'analyze code', 'find code smells', 'code quality check', 'assess code quality', 'code analyse', or wants a read-only quality report."
---

# /refactor:analyze — Code Quality Analysis (Read-Only)

Perform a thorough code quality analysis WITHOUT modifying any files. This produces a structured report of code smells, complexity metrics, and prioritized improvement recommendations.

## Workflow

1. **Identify target** — user-specified files/directories or search via Glob
2. **Spawn the code-analyzer agent** for systematic deep analysis
3. **Present the structured report** to the user

## What Gets Analyzed

CoT:LongMethod|GodClass|DeepNesting|FeatureEnvy|DuplicateLogic|DeadCode|MagicNumbers|PoorNames|LongParams|RepeatedSwitch?

- **Code Smells**: Long Method (>50 LOC), God Class (>500 LOC), Deep Nesting (>3 levels), Feature Envy, Data Clumps, Primitive Obsession, Dead Code, Repeated Switches, Shotgun Surgery, Long Parameter Lists (>4 params)
- **Principle Violations**: DRY, KISS, SOLID (SRP, OCP), Clean Code
- **Metrics**: Cyclomatic Complexity, Cognitive Complexity, LOC/method, LOC/class, nesting depth
- **Works with any language**: Python, JavaScript/TypeScript, Java, C#, C++, Go, Rust, PHP, Ruby, Lua, and more

## Output Format (mandatory)

```
## Code Smell Analysis

### HIGH IMPACT (start here):
| File:Line | Smell | Why It Matters | Recommended Fix |
|-----------|-------|----------------|-----------------|

### MEDIUM IMPACT:
| File:Line | Smell | Why It Matters | Recommended Fix |
|-----------|-------|----------------|-----------------|

### LOW IMPACT (consider skipping):
| File:Line | Smell | Why It Matters | Recommended Fix |
|-----------|-------|----------------|-----------------|

Metrics Summary:
- Estimated Cyclomatic Complexity: X (target: <10)
- Largest method: X LOC (target: <25)
- Largest class: X LOC (target: <500)
- Deepest nesting: X levels (target: <3)

Recommendation: [Which HIGH items to address first and why]
```

## Rules

- **Read-only** — do NOT modify any files
- Every finding MUST include a file:line reference
- Prioritize by impact: pain points, change frequency, leverage
- Use the 80/20 principle: focus on what gives maximum improvement
- After the report, suggest running `/refactor` to apply the recommended fixes
