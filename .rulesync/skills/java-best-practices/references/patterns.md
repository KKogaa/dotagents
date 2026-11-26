# Java patterns

Code examples for each rule in `SKILL.md`. The underlying principles are language-agnostic (type-system discipline and boundary discipline).

## Sealed domain models

Model variants with `sealed interface` and `record` so contradictory states cannot be constructed.

```java
// Don't. Nullable fields allow contradictory states (loading + error + data).
record FetchState(boolean loading, Order order, String error) {}

// Do. Only valid states exist.
sealed interface FetchState permits FetchState.Loading, FetchState.Ready, FetchState.Failed {
    record Loading() implements FetchState {}
    record Ready(Order order) implements FetchState {
        public Ready { Objects.requireNonNull(order); }
    }
    record Failed(String message) implements FetchState {}
}
```

## Exhaustive switches

Omit `default` when switching over a `sealed` hierarchy so the compiler catches missing variants.

```java
// Don't. Adding a new FetchState variant silently falls into default.
String label = switch (state) {
    case FetchState.Loading l -> "loading";
    case FetchState.Ready r -> "ready: " + r.order().id();
    default -> "other";
};

// Do. Compiler enforces exhaustiveness (JDK 21+).
String label = switch (state) {
    case FetchState.Loading() -> "loading";
    case FetchState.Ready(var order) -> "ready: " + order.id();
    case FetchState.Failed(var msg) -> "failed: " + msg;
};
```

## Immutable value types

Validate invariants in compact constructors and defend against mutable collections at the boundary.

```java
// Don't. Mutable list escapes and invariant is unenforced.
record Invoice(String id, List<LineItem> items) {}

// Do. Invariant enforced once at construction; internal list is immutable.
record Invoice(String id, List<LineItem> items) {
    public Invoice {
        if (id == null || id.isBlank()) throw new IllegalArgumentException("id required");
        items = List.copyOf(items);
        if (items.isEmpty()) throw new IllegalArgumentException("at least one item required");
    }
}
```

## `Optional` discipline

Use `Optional` only as a return type for possibly-absent lookups.

```java
// Don't. Optional as field or parameter adds noise and still risks null Optional.
record Filter(Optional<String> status) {}
void search(Optional<String> status) {}

// Do. Nullable/overloaded params at boundary, Optional return on lookup.
Optional<Order> findById(OrderId id);
Order order = findById(id).orElseThrow(() -> new OrderNotFoundException(id));
```

## Boundary validation

Validate and parse external strings/primitives into named domain types once at the boundary.

```java
// Don't. Raw String IDs can be swapped across arguments.
void transfer(String fromAccountId, String toAccountId, BigDecimal amount) {}

// Do. Value records prevent argument mixups; validated once at parse time.
record AccountId(UUID value) {
    static AccountId parse(String raw) { return new AccountId(UUID.fromString(raw)); }
}
void transfer(AccountId from, AccountId to, Money amount) {}
```

## Exception integrity

Preserve original causes and avoid catching `Throwable` or swallowing errors.

```java
// Don't. Loses stack trace and swallows Error.
try {
    client.send(req);
} catch (Throwable t) {
    log.error("send failed: " + t.getMessage());
}

// Do. Specific catch, cause preserved.
try {
    client.send(req);
} catch (IOException e) {
    throw new GatewayException("failed sending request " + req.id(), e);
}
```

## Virtual threads (JDK 21-23)

Avoid blocking I/O inside `synchronized` blocks on JDK 21-23; use `ReentrantLock` instead.

```java
// Don't (pins carrier thread on JDK 21-23).
synchronized (lock) {
    return remoteClient.fetch(key);
}

// Do. Virtual-thread friendly across JDK 21+.
lock.lock();
try {
    return remoteClient.fetch(key);
} finally {
    lock.unlock();
}
```

## Annotation processors (JDK 23+)

Declare annotation processors explicitly in `pom.xml` or `build.gradle` because JDK 23+ defaults to `-proc:none`.

```xml
<plugin>
  <artifactId>maven-compiler-plugin</artifactId>
  <configuration>
    <release>25</release>
    <annotationProcessorPaths>
      <path>
        <groupId>org.mapstruct</groupId>
        <artifactId>mapstruct-processor</artifactId>
        <version>${mapstruct.version}</version>
      </path>
    </annotationProcessorPaths>
  </configuration>
</plugin>
```

## Structured logging & secrets

Override `toString()` on records carrying tokens, credentials, or signed URLs, and pass throwables as the final SLF4J argument.

```java
// Don't. Default record toString() leaks secrets into logs.
record SignedDownload(String documentId, String sasUrl, String bearerToken) {}

// Do. Safe toString() and parameterized SLF4J with cause.
record SignedDownload(String documentId, String sasUrl, String bearerToken) {
    @Override
    public String toString() {
        return "SignedDownload[documentId=" + documentId + ", sasUrl=<redacted>, bearerToken=<redacted>]";
    }
}

log.error("Upload failed for documentId={}", docId, ex);
```

## Real tests

Run real persistence/containers when available and assert observable outcomes rather than mock call counts.

```java
// Don't. Mock-heavy test that passes even if the SQL query is broken.
when(repo.findActive()).thenReturn(List.of(order));
assertEquals(1, service.activeCount());

// Do. Real database via Testcontainers or in-memory test DB.
repo.save(Order.active("o-1"));
repo.save(Order.cancelled("o-2"));
assertEquals(1, service.activeCount());
```
