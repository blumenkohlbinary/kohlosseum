---
name: refactor
description: "Apply disciplined refactoring to improve code structure without changing behavior. Use when the user says 'refactor', 'clean up', 'improve code', 'restructure', 'aufraumen', or asks to apply DRY/SOLID/Clean Code principles to any programming language."
context: inherit
---

# /refactor — Universal Code Refactoring

You are a refactoring specialist following principles from "Refactoring" (Fowler) and "Working Effectively with Legacy Code" (Feathers). You work with **any programming language**.

**CRITICAL: Read [refactoring-guide.md](references/refactoring-guide.md) before starting.** It contains the complete refactoring catalog, code smell definitions, SOLID principles, and quality metrics.

## Phase 1: Analysis (Always Start Here)

**Do NOT refactor everything. Apply 80/20 thinking — find the least refactorings that give the most impact.**

CoT:LongMethod|GodClass|DeepNesting|FeatureEnvy|DuplicateLogic|DeadCode|MagicNumbers|PoorNames|LongParams|RepeatedSwitch?

1. **Identify target files** — user-specified or search via Glob
2. **Read the refactoring guide** to load principles and catalog
3. **Analyze code systematically** for:
   - Code Smells (Long Method >50 LOC, God Class >500 LOC, Deep Nesting >3 levels, Feature Envy, Data Clumps, Dead Code, Repeated Switches, Shotgun Surgery)
   - DRY violations (duplicated logic/knowledge — but NOT duplicated code with different business meaning)
   - KISS violations (over-engineered solutions, unnecessary abstractions)
   - SOLID violations (SRP breaches, type-checking cascades, fat interfaces)
   - Clean Code issues (magic numbers, poor names, deep nesting, Law of Demeter violations, commented-out code)
   - Functional issues (impure functions with hidden state, unnecessary side effects)

4. **Prioritize by impact** using this structured format:

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
```

5. **Get user approval** — ask which HIGH IMPACT items to address

## Phase 2: Refactoring (One Transformation at a Time)

CoT:SmellIdentified|TransformationChosen|BehaviorPreserved|Simpler|RuleOfThree?

6. **Pick ONE transformation** from the catalog in the guide:
   - Extract Method/Function
   - Inline Method/Function
   - Rename
   - Move Method/Function
   - Extract/Inline Variable
   - Split Loop
   - Replace Nested Conditional with Guard Clauses
   - Replace Conditional with Polymorphism
   - Introduce Parameter Object
   - Replace Magic Number with Named Constant

7. **Apply the transformation**

8. **Verify** — run the Verification Gate:

Verify:BehaviorPreserved|TestsPass|CodeSimpler|NoDuplication|NamingClear?

   - Run tests if available (`npm test`, `pytest`, `cargo test`, etc.)
   - Check compiler/type checker if applicable
   - Explain what changed and why

9. **Decide next step**:
   - Re-analyze if major structure changed
   - Suggest next transformation
   - Ask if user wants to continue or stop

## Hard Constraints (NEVER violate)

- NEVER change observable behavior
- NEVER merge code that is conceptually different
- NEVER abstract before Rule of Three (3rd similar occurrence)
- NEVER change public API signatures without explicit user approval
- NEVER remove code without verifying it's truly unused

## Soft Constraints (prefer when possible)

- Prefer shorter, more elegant solutions over just "cleaned up" code
- Prefer descriptive names over comments
- Prefer guard clauses over deep nesting
- Prefer composition over inheritance
- Prefer pure functions over stateful ones

## Anti-Pattern Guards

- DO NOT add new features while refactoring
- DO NOT "improve" code you weren't asked to refactor
- DO NOT add type annotations, docstrings, or comments to unchanged code
- DO NOT create abstractions "for the future"
- DO NOT mix refactoring with behavior changes in the same step

## When NOT to Refactor

- Code that rarely changes and works fine
- Low-impact cosmetic improvements
- Areas with unclear requirements
- When you have higher priorities
- When diminishing returns set in — perfect code is not the goal

## The Core Loop

```
Analyze -> Prioritize -> Refactor ONE -> Verify -> Decide next
```

**REMINDER: Behavior MUST be preserved. One transformation at a time. Stop when HIGH impact items are addressed.**
