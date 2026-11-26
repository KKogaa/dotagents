# Quarkus patterns

Code examples for each rule in `SKILL.md`. Pair with `java-best-practices/references/patterns.md`.

## CDI scopes & constructor injection

Avoid reading public fields on `@ApplicationScoped` beans: CDI injects a client proxy whose fields stay at default values.

```java
// Don't. Reading bean.counter from another bean or test reads the proxy (0).
@ApplicationScoped
public class MetricsHolder {
    public int counter;
}

// Do. Constructor injection and method access through the proxy.
@ApplicationScoped
public class OrderService {
    private final OrderRepository orders;

    public OrderService(OrderRepository orders) {
        this.orders = orders;
    }
}
```

## Build-time bean retention

Mark beans that are only resolved dynamically so ArC does not prune them at build time.

```java
@ApplicationScoped
@Unremovable
public class CustomPluginHandler implements PluginHandler {
    // Looked up via Arc.container().instance(CustomPluginHandler.class)
}
```

## Typed config & Dev Services

Use `@ConfigMapping` for grouped settings and leave `%dev`/`%test` URLs unset so Dev Services auto-provision containers.

```java
@ConfigMapping(prefix = "app.billing")
public interface BillingConfig {
    URI endpoint();
    @WithDefault("5s")
    Duration timeout();
}
```

```properties
# Don't. Setting a %dev URL disables PostgreSQL Dev Services.
# %dev.quarkus.datasource.jdbc.url=jdbc:postgresql://localhost:5432/app

# Do. Safe default + prod-only env bindings; dev/test use Dev Services.
quarkus.hibernate-orm.schema-management.strategy=none
%dev.quarkus.hibernate-orm.schema-management.strategy=drop-and-create
%test.quarkus.hibernate-orm.schema-management.strategy=drop-and-create
%prod.quarkus.datasource.jdbc.url=${DB_URL}
%prod.quarkus.datasource.username=${DB_USER}
%prod.quarkus.datasource.password=${DB_PASSWORD}
```

## Panache repository pattern & DTO boundaries

Keep entities decoupled from transport shapes and map to `record` DTOs inside the transactional boundary.

```java
@ApplicationScoped
public class BookRepository implements PanacheRepository<Book> {
    public List<Book> findByAuthor(String author) {
        return list("author", author);
    }
}

public record BookResponse(Long id, String title, String author) {
    static BookResponse from(Book b) {
        return new BookResponse(b.id, b.title, b.author);
    }
}
```

## Transactions & worker contexts

Non-HTTP threads (schedulers, queue consumers, async callbacks) have no active HTTP request context.

```java
// Don't. Fails in a scheduler/consumer with ContextNotActiveException or LazyInitializationException.
@Scheduled(every = "5m")
void sweepExpired() {
    bookRepository.list("expired = true").forEach(this::archive);
}

// Do. Activate a transaction on the worker thread.
@Scheduled(every = "5m")
@Transactional
void sweepExpired() {
    bookRepository.list("expired = true").forEach(this::archive);
}
```

Use `QuarkusTransaction.requiringNew().call(() -> ...)` when you need an explicit programmatic transaction boundary.

## Never block the event loop

Keep blocking JDBC/HTTP calls off Vert.x event-loop threads, and never mix `@NonBlocking` with `@Blocking` or `@RunOnVirtualThread`.

```java
// Don't. Blocking Panache call on event loop throws IllegalStateException.
@GET
@Path("/{id}")
public Uni<BookResponse> getBook(@PathParam("id") Long id) {
    return Uni.createFrom().item(() -> BookResponse.from(repo.findById(id)));
}

// Do. Imperative blocking ORM on a virtual thread (JDK 21+).
@GET
@Path("/{id}")
@RunOnVirtualThread
public BookResponse getBook(@PathParam("id") Long id) {
    Book book = repo.findByIdOptional(id).orElseThrow(NotFoundException::new);
    return BookResponse.from(book);
}
```

## Reactive Messaging rules

Distinct channel names mapped to the same topic go through the broker; reusing one channel name stays in-memory.

```properties
mp.messaging.outgoing.orders-out.connector=smallrye-kafka
mp.messaging.outgoing.orders-out.topic=orders
mp.messaging.incoming.orders-in.connector=smallrye-kafka
mp.messaging.incoming.orders-in.topic=orders
mp.messaging.incoming.orders-in.failure-strategy=dead-letter-queue
```

```java
@Incoming("orders-in")
@Blocking
@Transactional
public void handle(OrderEvent event) {
    orderService.record(event);
}
```

## Real verification

Use `@QuarkusTest` with Dev Services and `Awaitility` for async checks instead of mocking the entire persistence/messaging stack.

```java
@QuarkusTest
class BookResourceTest {
    @Test
    void createsAndFetchesBook() {
        given()
            .contentType(ContentType.JSON)
            .body("""{"title":"Dune","author":"Frank Herbert"}""")
        .when().post("/books")
        .then().statusCode(201);
    }
}
```
