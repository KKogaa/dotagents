---
name: java-best-practices
description: Java best practices (JDK 8-25). Use when reading, writing, or reviewing any .java file, pom.xml, or build.gradle. Pair with quarkus-best-practices for Quarkus services.
targets:
  - '*'
---

# Java best practices

Apply type-system discipline and boundary discipline first. Match the project's JDK release, build tool, formatter, and test libraries before writing code.

| Rule | Summary |
|------|---------|
| JDK release gate | Check `maven.compiler.release` or `java.toolchain` first. Never use a feature newer than the project's floor (11: `var`/`List.of`, 17: `record`/`sealed`, 21: pattern `switch`/virtual threads, 25: scoped values). Avoid preview APIs like `StructuredTaskScope` unless opted in. |
| Sealed domain models | Model variants with `sealed interface` + `record` implementations so impossible states can't be represented. No nullable-field bags. |
| Exhaustive switches | Switch over `sealed` types and enums without a catch-all `default` arm so the compiler errors when a new variant is added. |
| Immutable value types | Use `record` for DTOs and value objects, `final` fields on classes, and `List.copyOf` / `Map.copyOf` at boundaries. Validate invariants in compact constructors. |
| `Optional` discipline | Return `Optional<T>` from lookups that may be empty. Never use `Optional` for fields, method parameters, or collection elements. Never call `.get()` without proving presence. |
| Boundary validation | Parse and validate external inputs once into named domain types. Fail fast with specific exceptions and never expose raw stack traces. |
| Exception integrity | Never swallow exceptions or catch `Throwable`/`Error`. Always preserve causality (`new DomainException("...", cause)`). |
| Virtual threads (JDK 21-23) | Blocking I/O inside `synchronized` pins carrier threads on JDK 21-23 (fixed in JDK 24+, JEP 491). Use `ReentrantLock` around blocking calls on JDK 21-23. |
| Annotation processors (JDK 23+) | JDK 23+ defaults to `-proc:none`. Declare processors explicitly (`annotationProcessorPaths` in Maven, `annotationProcessor` in Gradle) instead of relying on classpath discovery. |
| No speculative dependencies | Prefer the JDK standard library and explicit code. Never add Lombok or new runtime dependencies unless the project already uses them. |
| BOM alignment | Align multi-artifact versions (JUnit, Testcontainers, framework BOMs) via `dependencyManagement` or Gradle platforms instead of scattering versions. |
| Structured logging & secrets | Use parameterized SLF4J (`log.error("...", id, ex)`), never `System.out`. Override `toString()` on records/DTOs carrying tokens, secrets, or signed URLs, and always pass the exception as the final argument. |
| Real tests | Prefer JUnit 5 + Testcontainers for persistence and integration boundaries. Don't mock what you can run locally. Verify with `./mvnw -B verify` or `./gradlew build`. |

Examples: `references/patterns.md`.
<!-- Distilled from github/awesome-copilot (skills/java-development, MIT). See THIRD_PARTY_LICENSES.md. -->
