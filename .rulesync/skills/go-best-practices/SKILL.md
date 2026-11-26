---
name: go-best-practices
description: Idiomatic Go best practices. Use when reading, writing, or reviewing any .go file or go.mod.
targets:
  - '*'
---

# Go best practices

Apply type-system discipline and boundary discipline first. Read `go.mod` (and any `//go:build` tags) before writing code — the `go` directive is the module's compatibility floor.

| Rule | Summary |
|------|---------|
| Version gating | Never use stdlib symbols or language features newer than the `go` directive in `go.mod`, and never raise `go.mod` just for a convenience helper. Run `go vet ./...` (`stdversion`) to enforce. |
| Necessity ladder | Check in order: (1) does it need to exist, (2) codebase already has it, (3) stdlib (`net/http` ServeMux, `slog`, `slices`/`maps`/`cmp`, `errors.Join`, `sync.OnceValue`, `os.Root` on 1.24+), (4) existing `go.mod` dep, (5) minimal code. |
| Flat domain packages | Start flat; split one level deep by domain (`auth/`, `billing/`, `jobs/`) rather than horizontal layer folders (`controller/`, `service/`, `repository/`). Keep transport and infrastructure separated from domain logic via files and small consumer interfaces, and follow the repo's existing layout if it is already layered. Never create `utils/`, `helpers/`, or `common/`. |
| Consumer-defined interfaces | Accept interfaces, return structs. Define small (1-3 method) interfaces in the consumer package only when two real implementations or a test seam require it. |
| Useful zero values | Design structs so their zero value works safely (`sync.Mutex`, `bytes.Buffer`). Explicitly initialize maps and JSON-bound slices (`[]T{}`, `map[K]V{}`) to avoid nil-map panics and JSON `null` vs `[]`. |
| Clarity & early return | Return early and keep the happy path unindented (no `else` after `return`). Use `var` for zero-value intent, `:=` for non-zero, named fields in struct literals, and omit `Get` prefixes on getters. |
| Check & wrap errors | Never discard errors with `_`. Wrap with context using `fmt.Errorf("doing x: %w", err)` internally (`%v` at system boundaries to hide internals). Error strings are lowercase with no trailing punctuation. |
| Inspect errors safely | Use `errors.Is` for sentinels and `errors.As` (`errors.AsType[T]` on Go 1.26+) for typed errors — never `==` or bare type assertions. Combine independent errors with `errors.Join`. |
| Single handling rule | Handle every error once: log it OR return it, never both. Never use `panic` for expected error conditions; translate internal errors to safe messages at API boundaries. |
| Context first | Pass `context.Context` as the first argument on I/O, DB, and network calls; never store it in a struct. Always respect cancellation and deadlines. |
| Structured concurrency | Every goroutine must have an owner and clear exit (`ctx.Done()`, `errgroup.WithContext`, `SetLimit`). Only the sender closes a channel; declare channel direction (`chan<-`, `<-chan`); default to unbuffered channels. |
| Locks & timers | Keep shared state and its `sync.Mutex` together (never copy a mutex). Avoid `time.After` in loops (leaks timers) — use `time.NewTimer` + `Reset`. |
| Structured logging | Use `log/slog` (Go 1.21+) with stable low-cardinality messages and structured attributes; never `fmt.Println` in shipped code. |
| Real tests | Write table-driven tests with `t.Helper()` and `t.Cleanup()`. Run `go vet ./...`, `go test -race ./...`, and `golangci-lint` when configured. |

Examples: `references/patterns.md`.
<!-- Distilled from spf13/go-skills (MIT) and samber/cc-skills-golang (MIT). See THIRD_PARTY_LICENSES.md. -->
