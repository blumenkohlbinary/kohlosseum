# Complete Refactoring Guide

Reference catalog for safe, disciplined code refactoring across all programming languages.

---

## 1. Fowler's Refactoring Catalog: 7 Core Operations

Refactoring = "A change to the internal structure that makes software easier to understand and cheaper to maintain, without changing its observable behavior." (Martin Fowler)

### Extract Method (Extract Function)

Fowler's most frequent operation: Code fragment requiring a comment → function with descriptive name. Target: methods <= 20 lines, ideally <= 6 lines.

```python
# BEFORE: One long function doing multiple things
def print_owing(invoice):
    print("**************************")
    print("***** Customer Owes ******")
    print("**************************")
    outstanding = 0
    for order in invoice.orders:
        outstanding += order.amount
    print(f"name: {invoice.customer}")
    print(f"amount: {outstanding}")

# AFTER: Each function does exactly one thing
def print_owing(invoice):
    print_banner()
    outstanding = calculate_outstanding(invoice)
    print_details(invoice, outstanding)

def print_banner():
    print("**************************")
    print("***** Customer Owes ******")
    print("**************************")

def calculate_outstanding(invoice):
    return sum(order.amount for order in invoice.orders)

def print_details(invoice, outstanding):
    print(f"name: {invoice.customer}")
    print(f"amount: {outstanding}")
```

### Extract Class

Split class with too many responsibilities. Example: `Person` with phone and address fields → `Person` + `TelephoneNumber` + `Address`.

### Inline Method

Reverse of Extract Method: function is as trivial as its name → eliminate indirection. Example: `more_than_five_late_deliveries(driver)` that only returns `driver.number_of_late_deliveries > 5`.

### Move Method

Move method to the class whose data it primarily uses. `Account.overdraft_charge()` accesses `AccountType` fields → move to `AccountType`, delegate from `Account`.

### Replace Conditional with Polymorphism

Type-checking if/elif cascades → distribute behavior into subclasses:

```python
# BEFORE: Type-checking cascade
class Bird:
    def speed(self):
        if self.type == "european":
            return self._base_speed()
        elif self.type == "african":
            return self._base_speed() - 1.5 * self.number_of_coconuts
        elif self.type == "norwegian_blue":
            return 0 if self.is_nailed else self._base_speed() * self.voltage / 100

# AFTER: Polymorphic classes
class EuropeanBird(Bird):
    def speed(self): return self._base_speed()

class AfricanBird(Bird):
    def speed(self): return self._base_speed() - 1.5 * self.number_of_coconuts

class NorwegianBlueBird(Bird):
    def speed(self): return 0 if self.is_nailed else self._base_speed() * self.voltage / 100
```

### Introduce Parameter Object

Same parameters travel together through multiple functions (`start_date, end_date` in `amount_invoiced()`, `amount_received()`, `amount_overdue()`) → `DateRange` dataclass. Reduces parameter count and reveals domain concepts.

### Replace Magic Number with Symbolic Constant

```python
# BEFORE                              # AFTER
return mass * 9.81 * height           GRAVITATIONAL_ACCELERATION = 9.81
                                      return mass * GRAVITATIONAL_ACCELERATION * height
```

**Core rules:** Function = one thing, one abstraction level, <= 3 parameters. Fowler: <= 6 lines preferred, <= 20 lines maximum. Nesting depth <= 2. Boolean parameter → split into two functions.

---

## 2. Code Smells: When Refactoring Is Needed

Kent Beck coined the term. Fowler's 2nd edition: 24 smells, each with concrete refactoring fixes.

| Code Smell | Definition | Fix |
|---|---|---|
| **Long Method** | Function mixes multiple abstraction levels | Extract Function, Decompose Conditional |
| **Feature Envy** | Method uses another class's data more than its own | Move Method |
| **Data Clumps** | Same fields/parameters always appear together | Introduce Parameter Object, Extract Class |
| **Primitive Obsession** | Strings for phone numbers, ints for money | Replace Primitive with Object |
| **God Class** | One class with dozens of responsibilities | Extract Class, Extract Interface |
| **Shotgun Surgery** | One feature requires changes in 5+ files | Move Method, Replace Conditional with Polymorphism |
| **Divergent Change** | Class changes for unrelated reasons | Extract Class (split by responsibility) |
| **Long Parameter List** | Functions with 4+ parameters | Introduce Parameter Object |
| **Repeated Switches** | Same switch on same discriminator in multiple places | Replace Conditional with Polymorphism |
| **Dead Code** | Unreachable code, unused variables, commented-out code | Delete — VCS preserves history |
| **Deep Nesting** | More than 3 levels of indentation | Guard Clauses, Extract Method |
| **Speculative Generality** | Abstractions "for the future" | Inline, remove unused hooks |
| **Middle Man** | Class delegates almost everything | Remove Middle Man |
| **Inappropriate Intimacy** | Classes access each other's private details | Move Method, Extract Class |

Fowler's 2nd edition renamed: "Switch Statements" → **"Repeated Switches"** — a single switch is ok; the smell occurs when the same switch appears in multiple places.

---

## 3. DRY, KISS, YAGNI, Boy-Scout-Rule

### DRY — Don't Repeat Yourself

"Every piece of knowledge has a single, unambiguous, authoritative representation in the system." (Hunt & Thomas, 1999)

DRY concerns **duplicated knowledge, not duplicated code**. Two identical functions with different business meaning do NOT violate DRY. **Rule of Three**: abstract only after the third repetition.

```javascript
// WET: Duplicated fetch logic
async function getUsers() {
    const response = await fetch('/api/users');
    if (!response.ok) throw new Error('Failed');
    return response.json();
}
async function getProducts() {
    const response = await fetch('/api/products');
    if (!response.ok) throw new Error('Failed');
    return response.json();
}

// DRY: Shared helper (only after 3rd occurrence!)
async function fetchData(endpoint) {
    const response = await fetch(`/api/${endpoint}`);
    if (!response.ok) throw new Error(`Failed to fetch ${endpoint}`);
    return response.json();
}
```

**Warning — Premature Abstraction:** "Wrong abstraction" couples unrelated modules. Kent C. Dodds: **AHA (Avoid Hasty Abstractions)** — optimize for change first, abstract when the pattern is clear.

### KISS — Keep It Simple, Stupid

Systems work better when kept simple. Typical KISS violation: Factory + Strategy for trivial addition.

```python
# OVER-ENGINEERED
class OperationFactory:
    @staticmethod
    def create_operation(op_type):
        if op_type == "add": return AddStrategy()
        raise ValueError(f"Unknown: {op_type}")

class AddStrategy:
    def execute(self, a, b): return a + b

result = OperationFactory.create_operation("add").execute(2, 3)

# KISS
def add(a, b): return a + b
```

### YAGNI — You Aren't Gonna Need It

Implement functionality only when it is actually needed. An MVP `UserProfile` does not need `blockchain_wallet`, `vr_avatar_settings`, or `export_to_pdf()`.

### Boy-Scout-Rule

"Leave the code cleaner than you found it." (Robert C. Martin). Micro-improvements (rename variable, replace magic number, delete dead code) accumulate over time.

---

## 4. SOLID Principles

Robert C. Martin (2000), acronym by Michael Feathers (2004). They combat design smells: rigidity, fragility, immobility, unnecessary complexity.

### SRP — Single Responsibility Principle

"A class has exactly one reason to change."

```python
# VIOLATION: FileManager handles I/O and compression
class FileManager:
    def read(self, encoding="utf-8"): ...
    def write(self, data): ...
    def compress(self): ...     # Different reason to change
    def decompress(self): ...

# CORRECT: Separated responsibilities
class FileManager:
    def read(self, encoding="utf-8"): ...
    def write(self, data): ...

class ZipFileManager:
    def compress(self): ...
    def decompress(self): ...
```

### OCP — Open/Closed Principle

"Open for extension, closed for modification." (Bertrand Meyer, 1988)

```python
# VIOLATION: New shape requires modifying calculate_area()
class Shape:
    def calculate_area(self):
        if self.shape_type == "rectangle": return self.width * self.height
        elif self.shape_type == "circle":  return pi * self.radius**2

# CORRECT: New shapes = new classes, no existing code touched
class Shape(ABC):
    @abstractmethod
    def calculate_area(self): pass

class Circle(Shape):
    def calculate_area(self): return pi * self.radius**2

class Rectangle(Shape):
    def calculate_area(self): return self.width * self.height
```

### LSP — Liskov Substitution Principle

"Subtypes must be substitutable for their base types." (Barbara Liskov, 1987)

Classic violation: Square extends Rectangle. Fix: Rectangle and Square as siblings under a shared Shape interface.

### ISP — Interface Segregation Principle

"Clients should not depend on methods they don't use."

```java
// VIOLATION: Fat interface forces RobotWorker to implement eat()
interface Worker { void work(); void eat(); }
class RobotWorker implements Worker {
    public void work() { /* ok */ }
    public void eat() { throw new UnsupportedOperationException(); }
}

// CORRECT: Segregated role interfaces
interface Workable { void work(); }
interface Feedable { void eat(); }
class HumanWorker implements Workable, Feedable { /* both */ }
class RobotWorker implements Workable { /* only work */ }
```

### DIP — Dependency Inversion Principle

"High-level modules should not depend on low-level modules. Both should depend on abstractions."

```python
# VIOLATION: App instantiates FXConverter directly
class App:
    def start(self):
        converter = FXConverter()  # Tight coupling
        converter.convert('EUR', 'USD', 100)

# CORRECT: Depend on abstraction, implementation injected
class CurrencyConverter(ABC):
    @abstractmethod
    def convert(self, from_c, to_c, amount): pass

class App:
    def __init__(self, converter: CurrencyConverter):  # Injected
        self.converter = converter
    def start(self):
        self.converter.convert('EUR', 'USD', 100)
```

---

## 5. Clean Code: Naming, Functions, Comments, Error Handling

### Naming Rules

Names reveal intent — if a name needs a comment, it's wrong. Classes are **nouns** (`Customer`, `Account`), methods are **verbs** (`postPayment`, `deletePage`). **One word per concept**: don't mix `fetch`, `retrieve`, and `get` for the same operation.

Name length proportional to scope size: Loop variable `i` is ok; a global variable needs `headerBounceAnimationDuration`. For functions: public methods get short names (`open`, `read`), private helpers get long descriptive names (`parseColumnHeader`).

### Function Rules

One thing, one abstraction level, 0-3 parameters. Boolean arguments → function does two things → split. Nesting depth <= 1-2.

### Comment Philosophy

"Don't comment bad code — rewrite it." (Kernighan & Plaugher). Good comments: legal headers, explanations of **why** (not what), warnings about consequences, TODOs. Bad comments: redundant restatements, commented-out code, closing brace markers.

```java
// BAD: Comment compensates for bad names
if ((employee.flags & HOURLY_FLAG) && (employee.age > 65))

// GOOD: Self-documenting — no comment needed
if (employee.isEligibleForFullBenefits())
```

### Error Handling

Exceptions over return codes. Don't return `null` → empty collections or Special-Case pattern. Don't pass `null`. Extract try/catch bodies into separate functions so the happy path stays visible.

---

## 6. Advanced Techniques

### Guard Clauses / Early Return

```java
// NESTED: Pyramid of Doom
public double getPayAmount() {
    double result;
    if (isDead) { result = deadAmount(); }
    else {
        if (isSeparated) { result = separatedAmount(); }
        else {
            if (isRetired) { result = retiredAmount(); }
            else           { result = normalPayAmount(); }
        }
    }
    return result;
}

// GUARD CLAUSES: Flat and readable
public double getPayAmount() {
    if (isDead)      return deadAmount();
    if (isSeparated) return separatedAmount();
    if (isRetired)   return retiredAmount();
    return normalPayAmount();
}
```

### Law of Demeter — "Only talk to immediate friends"

Method may only call: itself, its parameters, objects it creates, direct fields. Avoid **Train Wrecks**: `currentUser.getAccount().getCreditCard().charge(price)` → delegate: `currentUser.chargeForPlan()`.

### Command-Query Separation (CQS)

Every method is either a **Command** (mutates state, returns void) or a **Query** (returns data, no side effects) — **never both**.

### Tell, Don't Ask

```python
# ASK: External decision logic
if wallet.balance < amount:
    raise "Not enough funds"
wallet.balance -= amount

# TELL: Object manages its own state
wallet.debit(amount)  # Wallet handles validation internally
```

### Composition over Inheritance

Gang of Four (1994): "Favor object composition over class inheritance." Inheritance creates tight coupling and the diamond problem. Composition: contained objects replaceable at runtime.

### Strategy Pattern for Replacing Conditionals

When if/elif chooses between 3+ algorithm variants → Strategy. New strategies require zero changes to existing code (OCP).

### Null Object Pattern

Replace null references with a neutral object that provides default behavior. Eliminates null checks throughout the codebase.

### Pure Functions and Immutability

Pure Function: deterministic (same inputs → same output), no side effects. Enables memoization, parallelization, easy testing.

```python
# IMPURE: Mutates global state
total_price = 0
def add_item(price, tax_rate):
    global total_price
    total_price += price * (1 + tax_rate)

# PURE
def calculate_item_total(price, tax_rate):
    return price * (1 + tax_rate)

def calculate_cart_total(prices, tax_rate):
    return sum(calculate_item_total(p, tax_rate) for p in prices)
```

---

## 7. Quality Metrics: 6 Essential Measures

| Metric | Formula/Method | Good | Warning | Critical |
|--------|---------------|------|---------|----------|
| **Cyclomatic Complexity** | Decision points + 1 | 1-10 | 11-20 | 21+ |
| **Cognitive Complexity** | Nesting-weighted branching | <15/method | 15-25 | 25+ |
| **Maintainability Index** | Composite (Halstead, CC, LOC) | 20-100 (green) | 10-19 (yellow) | 0-9 (red) |
| **Lines of Code** | Count | <=25/function, <=500/class | 25-50/function | 50+/function |
| **Coupling (Ce)** | Efferent dependencies | <20 | 20-50 | 50+ |
| **Cohesion (LCOM)** | Methods without shared fields | 0 (ideal) | 1-3 | 4+ |

---

## 8. Code Smell → Transformation Quick Reference

| Code Smell | Threshold | Transformation | Priority |
|------------|-----------|----------------|----------|
| Long function | >50 lines | Extract Method | HIGH |
| Duplicated code | 3+ occurrences | Extract Method → Unify | HIGH |
| Deep nesting | >3 levels | Guard Clauses | HIGH |
| God class | >500 lines | Extract Class | HIGH |
| Unclear name | — | Rename | MEDIUM |
| Complex expression | — | Extract Variable | MEDIUM |
| Code in wrong file | Feature Envy | Move Function | MEDIUM |
| Loop does too much | — | Split Loop | MEDIUM |
| Long parameter list | >4 params | Introduce Parameter Object | MEDIUM |
| Magic numbers | any literal | Named Constant | LOW |
| Repeated switches | 2+ same switch | Polymorphism | HIGH |
| Dead code | unused | Delete | LOW |
| Deep call chain | >2 dots | Delegate / Law of Demeter | MEDIUM |
| Boolean parameter | any | Split into two functions | LOW |


---

## 9. Industry Standards for Code Quality

### NASA JPL Power of Ten (applicable rules)

| Rule | Description | Threshold | Refactoring Action |
|------|-------------|-----------|-------------------|
| R1 | No unbounded recursion | All recursion must have provable termination | Convert to iteration or add depth counter |
| R4 | Max function length | 60 lines per function | Extract Method |
| R5 | Assertion density | >=2 assertions per non-trivial function | Introduce Guard Assertion |
| R6 | Variable scope | Declare at smallest possible scope | Narrow Variable Scope |
| R7 | Check all return values | Every non-void return must be checked | Add error handling |

### CERT Secure Coding (applicable rules)

| Rule | Description | Pattern | Refactoring Action |
|------|-------------|---------|-------------------|
| ERR33-C | Check return values | Unchecked return from file/network/alloc | Add error checking after every call |
| DCL30-C | Narrow variable scope | Variable declared broader than needed | Move to smallest enclosing block |
| MSC12-C | Detect dead code | Unreachable code after return/throw | Delete dead code |
| ENV33-C | Avoid banned APIs | gets(), strcpy(), sprintf() and equivalents | Replace with safe alternatives |

### MISRA Concepts (transferable to high-level languages)

| Concept | MISRA Rule | High-Level Equivalent |
|---------|-----------|----------------------|
| Switch must have default | R16.4 | All switch/match statements need default/else |
| No implicit type conversion | R10.x | Use === not == in JS; explicit casts in TS |
| All warnings as errors | R1.1 | Enable strict mode, treat linter warnings as errors |
| Minimal variable scope | Dir 4.12 | const/let over var; block-scoped declarations |

### Google Engineering Practices (applicable rules)

| Rule | Description | Refactoring Action |
|------|-------------|-------------------|
| No unnecessary abstractions | Interface with only 1 implementation | Inline the interface or defer until 2nd impl |
| Small focused changes | One concept per commit | Split large refactorings into atomic steps |
| Readability over cleverness | Prefer straightforward code | Simplify over-engineered patterns |

---

## 10. Extended Smell -> Transformation Reference (v2.0)

### Performance Anti-Patterns

| Smell | Threshold/Pattern | Transformation | Priority | CWE |
|-------|-------------------|----------------|----------|-----|
| N+1 Query | DB query in loop body | Fix N+1 Query (eager load / batch) | HIGH | CWE-1073 |
| Blocking I/O in Async | Sync call in async context | Replace Blocking with Async | HIGH | CWE-834 |
| O(n^2) Nested Loop | Nested loops on same collection | Convert Loop to Batch (Set/Map lookup) | HIGH | CWE-407 |
| String Concat in Loop | String += in loop | Use StringBuilder/join/array | MEDIUM | CWE-407 |
| Unbounded Collection | Cache without eviction | Add LRU/TTL/max-size | MEDIUM | CWE-401 |
| Event Listener Leak | addEventListener without remove | Add cleanup in unmount/destroy | MEDIUM | CWE-401 |

### Concurrency Issues

| Smell | Threshold/Pattern | Transformation | Priority | CWE |
|-------|-------------------|----------------|----------|-----|
| TOCTOU Race Condition | Check-then-act without atomicity | Use atomic operation or lock | HIGH | CWE-367 |
| Shared Mutable State | Non-const global with multi-thread access | Add synchronization or make immutable | HIGH | CWE-362 |
| Non-Atomic Increment | counter++ on shared variable | Use AtomicInteger/atomic/synchronized | HIGH | CWE-366 |
| Deadlock Risk | Lock acquisition in different orders | Enforce consistent lock ordering | MEDIUM | CWE-833 |

### Error Handling Smells

| Smell | Threshold/Pattern | Transformation | Priority | CWE |
|-------|-------------------|----------------|----------|-----|
| Empty Catch Block | catch/except with empty body | Add logging + rethrow or handle | HIGH | CWE-1069 |
| Generic Catch-All | catch(Exception)/except: | Replace Generic Catch (specific types) | HIGH | CWE-396 |
| Swallowed Exception | Logged but not propagated | Add rethrow or return error | MEDIUM | CWE-390 |
| Resource Leak | Open without close on error path | Fix Resource Leak (using/with/try-with) | HIGH | CWE-772 |
| Unhandled Promise | .then() without .catch() | Add error handler or await with try-catch | HIGH | CWE-755 |
| Lost Stack Trace | New exception without cause | Wrap original exception as cause | MEDIUM | -- |
| Exception as Flow Control | throw where break/return works | Replace with control flow | LOW | CWE-248 |

### Testing Quality

| Smell | Threshold/Pattern | Transformation | Priority |
|-------|-------------------|----------------|----------|
| Test without Assertion | Test method with no assert/expect | Add meaningful assertions | HIGH |
| Assertion Roulette | >5 assertions without messages | Split test or add messages | MEDIUM |
| Sleepy Test | sleep() in test | Replace with polling/mock/await | MEDIUM |
| Mystery Guest | Direct I/O in unit test | Extract fixture or add mock | MEDIUM |
| Conditional Test Logic | if/switch in test body | Split into separate test cases | LOW |

### Architecture Issues

| Smell | Threshold/Pattern | Transformation | Priority | Ref |
|-------|-------------------|----------------|----------|-----|
| Circular Dependency | A imports B imports A | Break Circular Dependency | HIGH | CWE-1047 |
| Excessive Coupling | CBO >20 | Extract interface, reduce dependencies | MEDIUM | CWE-1048 |
| Layer Violation | DB access from view/controller | Move to service/repository layer | MEDIUM | -- |
| Unnecessary Abstraction | Interface with 1 impl | Inline or defer until needed | LOW | -- |
| Unbounded Recursion | Recursion without termination proof | Add depth limit or convert to iteration | MEDIUM | NASA P10 R1 |
