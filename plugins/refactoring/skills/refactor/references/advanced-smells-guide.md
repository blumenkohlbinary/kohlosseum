# Advanced Code Smells Guide

Reference catalog for performance, concurrency, error-handling, testing, and architecture smells. Complements `refactoring-guide.md` with detection patterns, multi-language code examples, and fix strategies.

**Read this guide when the code-analyzer flags issues in these categories. Each smell includes: definition, detection rule, code examples across languages, and the recommended transformation.**

---

## 1. Performance Anti-Patterns

### 1.1 N+1 Query
**CWE-1073** | **Confidence: 80-95** | **Priority: HIGH**

A database query executes inside a loop, causing N+1 total queries instead of 1.

**Detection:** DB query call or ORM lazy-load attribute access inside `for`/`while` loop body.

```python
# BAD -- N+1: 1 query for users + N queries for profiles
users = User.objects.all()
for user in users:
    print(user.profile.bio)  # Each access triggers a query

# GOOD -- 1 query with eager loading
users = User.objects.select_related('profile').all()
for user in users:
    print(user.profile.bio)  # No additional queries
```

```javascript
// BAD -- N+1 with Sequelize
const orders = await Order.findAll();
for (const order of orders) {
    const items = await order.getItems();  // Query per order
}

// GOOD -- Eager loading
const orders = await Order.findAll({ include: [Item] });
```

```java
// BAD -- JPA lazy loading in loop
List<Order> orders = em.createQuery("SELECT o FROM Order o").getResultList();
for (Order o : orders) {
    o.getItems().size();  // Triggers lazy load per order
}

// GOOD -- JOIN FETCH
List<Order> orders = em.createQuery(
    "SELECT o FROM Order o JOIN FETCH o.items"
).getResultList();
```

**Fix:** Replace with eager loading (`select_related`, `prefetch_related`, `JOIN FETCH`, `include`), batch query, or single query with JOIN.

---

### 1.2 Blocking I/O in Async Context
**CWE-834** | **Confidence: 85-95** | **Priority: HIGH**

Synchronous I/O call inside an async function blocks the event loop.

**Detection:** Known sync functions (`readFileSync`, `time.sleep()`, `requests.get()`) inside `async def`/`async function`.

```python
# BAD -- blocks the event loop
async def fetch_data():
    time.sleep(5)  # Blocks entire event loop
    data = requests.get(url)  # Sync HTTP in async context

# GOOD -- async alternatives
async def fetch_data():
    await asyncio.sleep(5)
    async with aiohttp.ClientSession() as session:
        data = await session.get(url)
```

```javascript
// BAD -- sync file read in Express handler
app.get('/data', async (req, res) => {
    const data = fs.readFileSync('/large-file.json');  // Blocks
    res.json(JSON.parse(data));
});

// GOOD -- async file read
app.get('/data', async (req, res) => {
    const data = await fs.promises.readFile('/large-file.json');
    res.json(JSON.parse(data));
});
```

**Fix:** Replace sync call with async equivalent. Use `await` with async I/O libraries.

---

### 1.3 O(n squared) Nested Loop
**CWE-407** | **Confidence: 75-90** | **Priority: HIGH**

Nested loops iterate over the same or related collection, creating quadratic complexity.

**Detection:** Two nested `for`/`while` loops over the same collection, or `list.__contains__` / `.includes()` / `.indexOf()` inside a loop.

```python
# BAD -- O(n^2) linear search in loop
def find_duplicates(items):
    duplicates = []
    for i in range(len(items)):
        for j in range(i + 1, len(items)):
            if items[i] == items[j]:
                duplicates.append(items[i])
    return duplicates

# GOOD -- O(n) with Set
def find_duplicates(items):
    seen = set()
    duplicates = set()
    for item in items:
        if item in seen:
            duplicates.add(item)
        seen.add(item)
    return list(duplicates)
```

```javascript
// BAD -- O(n^2) with includes
function findCommon(listA, listB) {
    return listA.filter(a => listB.includes(a));  // includes is O(n)
}

// GOOD -- O(n) with Set
function findCommon(listA, listB) {
    const setB = new Set(listB);
    return listA.filter(a => setB.has(a));  // has is O(1)
}
```

**Fix:** Replace inner loop with Set/Map lookup (O(1) per check), batch API, or SQL JOIN.

---

### 1.4 String Concatenation in Loop
**CWE-407** | **Confidence: 85-95** | **Priority: MEDIUM**

String `+=` inside a loop creates N intermediate string objects.

**Detection:** `+=` on a string variable inside a loop body.

```python
# BAD -- O(n^2) string building
result = ""
for line in lines:
    result += line + "\n"  # Creates new string each iteration

# GOOD -- O(n) with join
result = "\n".join(lines)
```

```java
// BAD -- String concat in loop
String result = "";
for (String s : items) {
    result += s + ",";  // Creates new String each time
}

// GOOD -- StringBuilder
StringBuilder sb = new StringBuilder();
for (String s : items) {
    sb.append(s).append(",");
}
String result = sb.toString();
```

**Fix:** Use `StringBuilder` (Java), `join()` (Python/JS), `strings.Builder` (Go), or array + join.

---

### 1.5 Unbounded Collection
**CWE-401** | **Confidence: 70-85** | **Priority: MEDIUM**

Static cache or collection grows without limit, causing memory leak.

**Detection:** Static/global `Map`/`Dict`/`Object` with `set()`/`put()` calls but no eviction policy, TTL, or max-size.

```python
# BAD -- unbounded cache
_cache = {}
def get_user(user_id):
    if user_id not in _cache:
        _cache[user_id] = db.fetch_user(user_id)  # Grows forever
    return _cache[user_id]

# GOOD -- LRU cache with max size
from functools import lru_cache
@lru_cache(maxsize=1000)
def get_user(user_id):
    return db.fetch_user(user_id)
```

**Fix:** Add LRU/TTL wrapper, max-size limit, or WeakReference where appropriate.

---

### 1.6 Event Listener Leak
**CWE-401** | **Confidence: 75-90** | **Priority: MEDIUM**

Event listener registered without corresponding removal in cleanup lifecycle.

**Detection:** `addEventListener`/`on()` without matching `removeEventListener`/`off()` in unmount/destroy/cleanup.

```javascript
// BAD -- listener never removed
useEffect(() => {
    window.addEventListener('resize', handleResize);
    // Missing cleanup -- listener accumulates on every re-render
}, []);

// GOOD -- cleanup in return
useEffect(() => {
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
}, []);
```

**Fix:** Add cleanup in component unmount, `dispose()`, or use `AbortController`.

---

## 2. Concurrency Issues

### 2.1 TOCTOU Race Condition
**CWE-367** | **Confidence: 70-85** | **Priority: HIGH**

Time-of-Check to Time-of-Use: gap between checking a condition and acting on it allows another thread/process to change the state.

**Detection:** Check-then-act sequence on shared resource without atomicity.

```python
# BAD -- TOCTOU: file might be deleted between check and open
if os.path.exists(filepath):
    with open(filepath) as f:  # Race: file could be gone
        data = f.read()

# GOOD -- EAFP: try directly, handle failure
try:
    with open(filepath) as f:
        data = f.read()
except FileNotFoundError:
    data = None
```

**Fix:** Use atomic operations, EAFP (try/except), database transactions with proper isolation, or locks.

---

### 2.2 Shared Mutable State Without Synchronization
**CWE-362/567** | **Confidence: 65-80** | **Priority: HIGH**

Non-const global or static variable accessed from multiple threads without synchronization.

```java
// BAD -- shared mutable state
static List<String> activeUsers = new ArrayList<>();  // Not thread-safe

void onLogin(String user) { activeUsers.add(user); }    // Thread A
void onLogout(String user) { activeUsers.remove(user); } // Thread B

// GOOD -- concurrent collection
static List<String> activeUsers = Collections.synchronizedList(new ArrayList<>());
```

**Fix:** Make immutable, use concurrent collections, add synchronization, or use thread-local storage.

---

### 2.3 Non-Atomic Increment
**CWE-366** | **Confidence: 80-90** | **Priority: HIGH**

Shared counter incremented with `++` or `+=` without atomic operation.

```java
// BAD -- non-atomic
static int requestCount = 0;
void handleRequest() { requestCount++; }  // Lost updates

// GOOD -- atomic
static AtomicInteger requestCount = new AtomicInteger(0);
void handleRequest() { requestCount.incrementAndGet(); }
```

**Fix:** Use `AtomicInteger` (Java), `atomic` (C++), `threading.Lock` (Python), or `sync/atomic` (Go).

---

### 2.4 Deadlock Risk -- Lock Ordering
**CWE-833** | **Confidence: 60-75** | **Priority: MEDIUM**

Multiple locks acquired in different orders across different code paths.

```java
// BAD -- different lock ordering
void transferAtoB() { synchronized(lockA) { synchronized(lockB) { /* ... */ } } }
void transferBtoA() { synchronized(lockB) { synchronized(lockA) { /* ... */ } } }

// GOOD -- consistent ordering (always lock lower ID first)
void transfer(Account from, Account to) {
    Account first = from.id < to.id ? from : to;
    Account second = from.id < to.id ? to : from;
    synchronized(first.lock) { synchronized(second.lock) { /* ... */ } }
}
```

**Fix:** Enforce consistent lock ordering, use `tryLock` with timeout, or reduce lock granularity.

---

## 3. Error Handling Smells

### 3.1 Empty Catch Block
**CWE-1069** | **Confidence: 95-100** | **Priority: HIGH**

Catch block with empty body or only a comment -- exception is silently swallowed.

```java
// BAD
try { parseConfig(file); }
catch (Exception e) { }  // Silent failure

// GOOD
try { parseConfig(file); }
catch (ParseException e) {
    logger.error("Config parse failed: {}", file, e);
    throw new ConfigurationException("Invalid config", e);
}
```

```python
# BAD
try:
    process(data)
except:
    pass  # Swallows ALL exceptions

# GOOD
try:
    process(data)
except ValueError as e:
    logger.warning("Invalid data: %s", e)
    return default_value
```

**Fix:** Add logging + rethrow, handle specifically, or add a comment explaining intentional suppression.

---

### 3.2 Generic Catch-All
**CWE-396** | **Confidence: 85-95** | **Priority: HIGH**

Catching the base exception class without specific handling.

```python
# BAD -- catches everything including SystemExit
try:
    result = compute(data)
except:
    return None

# GOOD -- catch specific types
try:
    result = compute(data)
except (ValueError, TypeError) as e:
    logger.warning("Computation failed: %s", e)
    return None
```

**Fix:** Replace with specific exception types, re-raise unknown exceptions.

---

### 3.3 Swallowed Exception
**CWE-390** | **Confidence: 70-85** | **Priority: MEDIUM**

Exception is logged but not propagated in a critical code path.

```java
// BAD -- critical payment exception swallowed
try { paymentGateway.charge(amount); }
catch (PaymentException e) {
    logger.error("Payment failed", e);
    // Execution continues as if payment succeeded!
}

// GOOD -- propagate
try { paymentGateway.charge(amount); }
catch (PaymentException e) {
    logger.error("Payment failed", e);
    throw new OrderException("Payment processing failed", e);
}
```

**Fix:** Rethrow, return error, or convert to appropriate exception for the abstraction level.

---

### 3.4 Lost Stack Trace
**Confidence: 80-90** | **Priority: MEDIUM**

New exception thrown without wrapping the original as the cause.

```java
// BAD -- original stack trace lost
catch (SQLException e) {
    throw new ServiceException(e.getMessage());  // Cause lost!
}

// GOOD -- preserve cause chain
catch (SQLException e) {
    throw new ServiceException("DB operation failed", e);  // Cause preserved
}
```

**Fix:** Always pass the original exception as the `cause` parameter.

---

### 3.5 Resource Leak
**CWE-772** | **Confidence: 80-95** | **Priority: HIGH**

Resource opened but not guaranteed to close on all code paths.

```python
# BAD -- resource leak on exception
f = open("data.txt")
data = f.read()  # If this throws, file handle leaks
f.close()

# GOOD -- context manager
with open("data.txt") as f:
    data = f.read()  # Guaranteed close
```

```java
// BAD
Connection conn = DriverManager.getConnection(url);
Statement stmt = conn.createStatement();  // If this throws, conn leaks

// GOOD -- try-with-resources
try (Connection conn = DriverManager.getConnection(url);
     Statement stmt = conn.createStatement()) {
    // Both auto-close
}
```

**Fix:** Wrap in `try-with-resources` (Java), `with` (Python), `using` (C#), or `defer` (Go).

---

### 3.6 Unhandled Promise
**CWE-755** | **Confidence: 80-90** | **Priority: HIGH**

Promise chain without error handler, or async call without await.

```javascript
// BAD -- floating promise, errors silently lost
fetchData().then(data => process(data));

// GOOD -- error handling
fetchData()
    .then(data => process(data))
    .catch(err => logger.error('Fetch failed:', err));

// OR -- async/await with try-catch
try {
    const data = await fetchData();
    process(data);
} catch (err) {
    logger.error('Fetch failed:', err);
}
```

**Fix:** Add `.catch()` to promise chains, or use `try-catch` with `await`.

---

### 3.7 Exception as Flow Control
**CWE-248** | **Confidence: 70-85** | **Priority: LOW**

Exceptions used for normal control flow instead of conditional logic.

```python
# BAD -- exception as flow control
def find_item(items, target):
    try:
        for item in items:
            if item.id == target:
                raise FoundException(item)
    except FoundException as e:
        return e.item
    return None

# GOOD -- simple return
def find_item(items, target):
    for item in items:
        if item.id == target:
            return item
    return None
```

**Fix:** Replace with `return`, `break`, or conditional logic.

---

## 4. Testing Quality Smells

### 4.1 Test Without Assertion
**Confidence: 95-100** | **Priority: HIGH**

Test method runs code but never verifies the result.

```java
// BAD -- 100% coverage, 0% verification
@Test
void testCalculation() {
    calculator.compute(5, 3);  // No assertion!
}

// GOOD
@Test
void testCalculation() {
    int result = calculator.compute(5, 3);
    assertEquals(8, result);
}
```

**Fix:** Add meaningful assertions that verify the expected outcome.

---

### 4.2 Assertion Roulette
**Confidence: 80-90** | **Priority: MEDIUM**

Multiple assertions in one test without descriptive messages.

```java
// BAD -- which assertion failed?
@Test
void testUser() {
    assertEquals("John", user.getName());
    assertEquals(25, user.getAge());
    assertEquals("NYC", user.getCity());
    assertTrue(user.isActive());
    assertNotNull(user.getEmail());
    assertEquals("ADMIN", user.getRole());
}

// GOOD -- split or add messages
@Test
void testUserPersonalInfo() {
    assertEquals("John", user.getName(), "User name should be John");
    assertEquals(25, user.getAge(), "User age should be 25");
}
```

**Fix:** Split into focused tests or add descriptive assertion messages.

---

### 4.3 Sleepy Test
**Confidence: 90-95** | **Priority: MEDIUM**

Test uses `sleep()` to wait for async operations instead of proper synchronization.

```java
// BAD -- fragile, slow
@Test
void testAsyncProcess() {
    service.startAsync();
    Thread.sleep(5000);  // Hope it is done by now
    assertTrue(service.isComplete());
}

// GOOD -- polling with timeout
@Test
void testAsyncProcess() {
    service.startAsync();
    await().atMost(5, SECONDS).until(service::isComplete);
}
```

**Fix:** Use polling, `CountDownLatch`, `CompletableFuture`, mock timers, or `await()` utilities.

---

### 4.4 Mystery Guest
**Confidence: 70-80** | **Priority: MEDIUM**

Test depends on external resources without making it explicit.

```python
# BAD -- depends on file system state
def test_parse_config():
    result = parse_config("/etc/app/config.yaml")  # External dependency
    assert result["db_host"] == "localhost"

# GOOD -- explicit fixture
def test_parse_config(tmp_path):
    config_file = tmp_path / "config.yaml"
    config_file.write_text("db_host: localhost")
    result = parse_config(str(config_file))
    assert result["db_host"] == "localhost"
```

**Fix:** Use fixtures, mocks, or in-memory alternatives. Make all dependencies explicit.

---

### 4.5 Conditional Test Logic
**Confidence: 75-85** | **Priority: LOW**

Test contains `if`/`switch`/`try-catch` that makes the test path non-deterministic.

```java
// BAD -- test logic hides failures
@Test
void testFeature() {
    try {
        Result r = service.process(input);
        if (r.isSuccess()) {
            assertEquals("OK", r.getMessage());
        }
    } catch (Exception e) {
        // Test passes even on exception!
    }
}

// GOOD -- direct, deterministic
@Test
void testFeatureSuccess() {
    Result r = service.process(validInput);
    assertTrue(r.isSuccess());
    assertEquals("OK", r.getMessage());
}
```

**Fix:** Split into separate test cases -- one per scenario.

---

## 5. Architecture Issues

### 5.1 Circular Dependency
**CWE-1047** | **Confidence: 85-95** | **Priority: HIGH**

Modules import each other in a cycle (A -> B -> C -> A).

**Fix:** Extract shared interface/types into a third module, use dependency injection, or restructure the dependency direction.

---

### 5.2 Excessive Coupling (CBO > 20)
**CWE-1048** | **Confidence: 75-90** | **Priority: MEDIUM**

Class depends on more than 20 other types. CBO > 20 = warning, > 30 = critical.

**Fix:** Extract interfaces, split into smaller classes, use facade pattern, reduce parameter types.

---

### 5.3 Layer Violation
**Confidence: 65-80** | **Priority: MEDIUM**

Direct database access from controller/view layer, or UI imports in business logic.

```python
# BAD -- controller directly queries DB
@app.route('/users')
def get_users():
    users = db.session.execute("SELECT * FROM users")  # Layer violation!
    return render_template('users.html', users=users)

# GOOD -- service layer
@app.route('/users')
def get_users():
    users = user_service.get_all()  # Controller calls service
    return render_template('users.html', users=users)
```

**Fix:** Move data access to repository/service layer. Enforce import boundaries.

---

### 5.4 Unnecessary Abstraction
**Confidence: 60-75** | **Priority: LOW**

Interface or abstract class with only one implementation -- premature abstraction.

```java
// BAD -- only one implementation
interface UserRepository { List<User> findAll(); }
class UserRepositoryImpl implements UserRepository { /* ... */ }

// GOOD -- use concrete class until 2nd impl needed
class UserRepository { List<User> findAll() { /* ... */ } }
```

**Fix:** Inline the interface. Extract again only when a second implementation is genuinely needed.

---

### 5.5 Unbounded Recursion
**NASA P10 R1** | **Confidence: 70-85** | **Priority: MEDIUM**

Recursive function without provable termination or depth limit.

```python
# BAD -- no depth limit
def flatten(nested):
    result = []
    for item in nested:
        if isinstance(item, list):
            result.extend(flatten(item))  # Could overflow
        else:
            result.append(item)
    return result

# GOOD -- depth limit
def flatten(nested, max_depth=100):
    if max_depth <= 0:
        raise RecursionError("Max nesting depth exceeded")
    result = []
    for item in nested:
        if isinstance(item, list):
            result.extend(flatten(item, max_depth - 1))
        else:
            result.append(item)
    return result
```

**Fix:** Add depth counter, convert to iterative with explicit stack, or prove termination.

---

## 6. Confidence Scoring Reference

| Detection Method | Confidence Range | Examples |
|-----------------|-----------------|----------|
| **Mechanical / metric-based** | 90-100 | LOC count >50, empty catch block, test without assertion, missing close() call |
| **AST pattern matching** | 80-95 | N+1 query in loop, blocking I/O in async, string concat in loop, generic catch-all |
| **Cross-file pattern** | 70-89 | Circular dependency, TOCTOU, layer violation, resource leak across methods |
| **Semantic / heuristic** | 50-69 | Feature envy, unnecessary abstraction, swallowed exception severity, deadlock risk |
| **Speculative** | 30-49 | Possible over-engineering, unclear naming impact, potential future maintenance issue |

**Threshold Rules:**
- **Report**: Only findings with confidence >= 50
- **Mark**: Findings 50-69 as `[NEEDS REVIEW]`
- **Highlight**: Findings >= 90 as `[CERTAIN]`

---

## 7. CWE / Standard Cross-Reference

| Smell | CWE | NASA P10 | CERT | MISRA | Google |
|-------|-----|----------|------|-------|--------|
| Long Method | CWE-1080 | R4 (60 lines) | -- | -- | Yes |
| God Class | CWE-1086 | -- | -- | -- | Yes |
| Deep Nesting | -- | R4 | -- | -- | Yes |
| Dead Code | -- | -- | MSC12-C | R14.3 | Yes |
| Magic Numbers | -- | -- | -- | -- | Yes |
| N+1 Query | CWE-1073 | -- | -- | -- | -- |
| Blocking I/O in Async | CWE-834 | -- | -- | -- | -- |
| O(n^2) Nested Loop | CWE-407 | -- | -- | -- | -- |
| String Concat in Loop | CWE-407 | -- | -- | -- | -- |
| Unbounded Collection | CWE-401 | -- | -- | -- | -- |
| Event Listener Leak | CWE-401 | -- | -- | -- | -- |
| TOCTOU | CWE-367 | -- | FIO45-C | -- | -- |
| Shared Mutable State | CWE-362 | -- | CON43-C | -- | -- |
| Non-Atomic Increment | CWE-366 | -- | CON02-C | -- | -- |
| Deadlock Risk | CWE-833 | -- | CON35-C | -- | -- |
| Empty Catch Block | CWE-1069 | -- | ERR00-J | -- | Yes |
| Generic Catch-All | CWE-396 | -- | ERR07-J | -- | Yes |
| Swallowed Exception | CWE-390 | -- | -- | -- | Yes |
| Resource Leak | CWE-772 | -- | -- | -- | -- |
| Unhandled Promise | CWE-755 | -- | -- | -- | -- |
| Exception as Flow Control | CWE-248 | -- | -- | -- | -- |
| Circular Dependency | CWE-1047 | -- | -- | -- | Yes |
| Excessive Coupling | CWE-1048 | -- | -- | -- | -- |
| Unbounded Recursion | -- | R1 | -- | -- | -- |
| Missing Assertions | -- | R5 (>=2/fn) | -- | -- | -- |
| Broad Variable Scope | -- | R6 | DCL30-C | Dir 4.12 | -- |
| Unchecked Return Value | -- | R7 | ERR33-C | R17.7 | Yes |
| Banned Unsafe API | -- | R8 | ENV33-C | R21.x | -- |
| Missing Switch Default | -- | -- | -- | R16.4 | -- |
