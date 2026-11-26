---
name: quarkus-best-practices
description: Quarkus 3.x best practices for CDI (ArC), Quarkus REST, Hibernate ORM with Panache, Mutiny/virtual threads, Reactive Messaging, OIDC, Dev Services, and testing. Use when reading or editing a Quarkus project. Pair with java-best-practices.
targets:
  - '*'
---

# Quarkus best practices

Pair with `java-best-practices` for plain Java rules. Read `pom.xml` or `build.gradle` first for `quarkus.platform.version`, Java release, and installed extensions.

| Rule | Summary |
|------|---------|
| Extensions via CLI/BOM | Add extensions with `quarkus extension add <name>` or `./mvnw quarkus:add-extension -Dextensions=<name>`. Never hand-guess coordinates or versions; let the Quarkus BOM manage them. |
| Native Jakarta only | Use `jakarta.*` imports and native Quarkus extensions. Never add `quarkus-spring-*` compatibility extensions unless the project already uses them. |
| CDI scopes & constructor injection | Default to `@ApplicationScoped` with constructor injection (`@Singleton` only for plain stateless holders). Never read or write public fields on an `@ApplicationScoped` bean from another bean or test — you hit the client proxy, not the instance. |
| Build-time bean retention | ArC removes unused beans at build time. Annotate beans looked up only programmatically (`Arc.container()`, `Instance<T>`) with `@Unremovable`. |
| Typed config & Dev Services | Group config in `@ConfigMapping` interfaces (`@ConfigProperty` only for single values). Never configure DB/broker/OIDC URLs in `%dev` or `%test` — that disables Dev Services. |
| Panache repository pattern | Prefer `PanacheRepository<Entity>` over active-record `PanacheEntity` for non-trivial domains (plain POJOs, mockable with `@InjectMock`). Stay on `quarkus-hibernate-orm-panache` (avoid experimental `quarkus-data-hibernate`). |
| Transactions & worker contexts | Annotate service write methods with `@Transactional` (`jakarta.transaction`). Non-HTTP threads (schedulers, queue/Kafka consumers, async callbacks) have no HTTP request context — wrap DB work in `@Transactional` or `@ActivateRequestContext`. |
| Schema & DTO boundaries | Use Flyway or Liquibase in production (`schema-management.strategy=none`; `drop-and-create` in `%dev`/`%test` only). Map entities to `record` DTOs before returning from resources; fetch lazy relations inside the transaction (no open-in-view). |
| Imperative + virtual threads first | Default to blocking ORM + `@RunOnVirtualThread` (Java 21+) for I/O-heavy endpoints. Pick Hibernate Reactive only when the entire call chain is non-blocking. |
| Never block the event loop | Never call blocking JDBC/Panache, `Thread.sleep`, or `Uni.await().indefinitely()` on `@NonBlocking` or `Uni`/`Multi` event-loop methods. Never combine `@NonBlocking` with `@Blocking` or `@RunOnVirtualThread` (fails the build). |
| Mutiny discipline | Nothing executes until subscribed (returning a `Uni` from a resource subscribes it). Keep `Uni.createFrom().item(supplier)` suppliers non-blocking because they run on the subscribing thread. |
| Reactive Messaging rules | Set `mp.messaging.<dir>.<channel>.connector` explicitly when >1 messaging connector is on the classpath. Add `@Blocking` or `@Transactional` to async consumers touching JDBC. Reusing the same channel name for `@Outgoing` and `@Incoming` stays in-memory and skips the broker. Always configure a dead-letter/failure strategy in production. |
| Security & secrets | Use `quarkus-oidc` and `@RolesAllowed` on endpoints, enforce per-record authorization in services, and never commit secrets in `application.properties`. |
| Real verification | Write `@QuarkusTest` integration tests with Dev Services (`@TestTransaction` for rollback, `Awaitility`/`InMemoryConnector` for messaging) and verify with `./mvnw verify`. |

Examples: `references/patterns.md`.
<!-- Distilled from github/awesome-copilot (skills/quarkus-application-development, MIT). See THIRD_PARTY_LICENSES.md. -->
