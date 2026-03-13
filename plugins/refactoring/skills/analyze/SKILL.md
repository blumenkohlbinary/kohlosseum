---
name: analyze
description: "Analyze code for smells, complexity, performance anti-patterns, concurrency issues, error-handling defects, testing quality, and architecture problems without making any changes. Use when the user says 'analyze code', 'find code smells', 'code quality check', 'assess code quality', 'code analyse', or wants a read-only quality report."
---

# /refactor:analyze -- Code Quality Analysis (Read-Only)

Perform a thorough code quality analysis WITHOUT modifying any files. This produces a structured report of code smells, complexity metrics, and prioritized improvement recommendations with confidence scores.

## Workflow

1. **Identify target** -- user-specified files/directories or search via Glob
2. **Spawn the code-analyzer agent** for systematic deep analysis
3. **Present the structured report** to the user

## What Gets Analyzed

CoT:LongMethod|GodClass|DeepNesting|FeatureEnvy|DuplicateLogic|DeadCode|MagicNumbers|PoorNames|LongParams|RepeatedSwitch|N+1Query|BlockingIO|EmptyCatch|ResourceLeak|CircularDep|TestWithoutAssert?

- **Code Smells**: Long Method (>50 LOC), God Class (>500 LOC), Deep Nesting (>3 levels), Feature Envy, Data Clumps, Primitive Obsession, Dead Code, Repeated Switches, Shotgun Surgery, Long Parameter Lists (>4 params)
- **Performance Anti-Patterns**: N+1 Query, Blocking I/O in Async, O(n^2) Nested Loops, String Concat in Loop, Unbounded Collection, Event Listener Leak
- **Concurrency Issues**: TOCTOU, Shared Mutable State, Non-Atomic Increment, Deadlock Risk
- **Error Handling Smells**: Empty Catch, Generic Catch-All, Swallowed Exception, Resource Leak, Unhandled Promise, Lost Stack Trace
- **Testing Quality** (if test files present): Test without Assertion, Assertion Roulette, Sleepy Test, Mystery Guest, Conditional Test Logic
- **Architecture Issues**: Circular Dependencies, Excessive Coupling (CBO >20), Layer Violations, Unnecessary Abstractions
- **Principle Violations**: DRY, KISS, SOLID (SRP, OCP), Clean Code
- **Metrics**: Cyclomatic Complexity, Cognitive Complexity, LOC/method, LOC/class, nesting depth, assertion density, coupling (CBO)
- **Works with any language**: Python, JavaScript/TypeScript, Java, C#, C++, Go, Rust, PHP, Ruby, Lua, and more

## Confidence Scoring

Every finding includes a confidence score (0-100):
- **90-100 [CERTAIN]**: Mechanically verifiable (LOC count, empty catch, no assertion)
- **70-89**: High confidence pattern match (N+1 in loop, TOCTOU, resource leak)
- **50-69 [NEEDS REVIEW]**: Heuristic/semantic (feature envy, unnecessary abstraction)
- **Below 50**: Not reported (too speculative)

## Output Format (mandatory)

```
## Code Smell Analysis

### HIGH IMPACT (start here):
| File:Line | Smell | Confidence | Why It Matters | Recommended Fix | Ref |
|-----------|-------|------------|----------------|-----------------|-----|

### MEDIUM IMPACT:
| File:Line | Smell | Confidence | Why It Matters | Recommended Fix | Ref |
|-----------|-------|------------|----------------|-----------------|-----|

### LOW IMPACT (consider skipping):
| File:Line | Smell | Confidence | Why It Matters | Recommended Fix | Ref |
|-----------|-------|------------|----------------|-----------------|-----|

Metrics Summary:
- Estimated Cyclomatic Complexity: X (target: <10)
- Largest method: X LOC (target: <25)
- Largest class: X LOC (target: <500)
- Deepest nesting: X levels (target: <3)
- Assertion Density: X per function (target: >=2, NASA P10 R5)
- Coupling (CBO): X (target: <20)
- Findings reported: X total (Y high-confidence >=70, Z needs-review 50-69)

Recommendation: [Which HIGH items to address first and why]
```

## Rules

- **Read-only** -- do NOT modify any files
- Every finding MUST include a file:line reference and confidence score
- Prioritize by impact: pain points, change frequency, leverage
- Use the 80/20 principle: focus on what gives maximum improvement
- Reference CWE/NASA/CERT/MISRA standards where applicable
- After the report, suggest running `/refactor` to apply the recommended fixes
