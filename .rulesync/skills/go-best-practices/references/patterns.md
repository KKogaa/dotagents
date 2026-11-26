# Go patterns

Code examples for each rule in `SKILL.md`. The underlying principles are language-agnostic (type-system discipline and boundary discipline).

## Flat domain packages

Separate transport and storage from domain logic inside vertical domain packages instead of horizontal Java-style layer folders (`controller/`, `service/`, `repository/`).

```text
// Don't. Horizontal layer packages force exports, pass-throughs, and import cycles.
controller/order_controller.go
service/order_service.go
repository/order_repository.go
domain/order.go

// Do. Vertical domain packages; transport and adapters stay separate from pure logic.
orders/
  order.go     // pure domain logic + small Store interface
  http.go      // thin HTTP handler delegating to domain functions
  postgres.go  // persistence adapter implementing Store
```

If an existing repository already uses a hexagonal or layered package tree, follow its convention instead of fighting it.

## Consumer-defined interfaces

Define small interfaces where they are consumed, not preemptively beside the concrete implementation.

```go
// Don't. Producer defines a wide interface with one implementation.
package store
type UserStoreInterface interface {
    Get(id string) (*User, error)
    Create(u *User) error
    Delete(id string) error
    List() ([]*User, error)
}

// Do. Consumer declares the minimal interface it actually needs; producer returns concrete struct.
package auth
type UserLookup interface {
    FindUser(ctx context.Context, id string) (*User, error)
}
```

## Useful zero values & slice/map initialization

Design zero-value-safe types, and initialize maps and JSON slices explicitly.

```go
// Do. Zero value is immediately usable.
type Counter struct {
    mu    sync.Mutex
    count int
}

func (c *Counter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

// Don't. Nil slice marshals as JSON null; nil map panics on write.
var items []Item
var counts map[string]int

// Do. Empty slice marshals as []; map is writable.
items := make([]Item, 0, len(ids))
counts := map[string]int{}
```

## Clarity & early return

Keep the happy path flush-left and use named fields in struct literals.

```go
// Don't. Deep nesting and positional struct literal.
func loadConfig(path string) (*Config, error) {
    if path != "" {
        data, err := os.ReadFile(path)
        if err == nil {
            return parseConfig(data)
        } else {
            return nil, err
        }
    }
    return &Config{"localhost", 8080}, nil
}

// Do. Early returns, named struct fields.
func loadConfig(path string) (*Config, error) {
    if path == "" {
        return &Config{Host: "localhost", Port: 8080}, nil
    }
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("read config %s: %w", path, err)
    }
    return parseConfig(data)
}
```

## Check, wrap, and inspect errors safely

Use `%w` internally, `%v` at boundaries where you don't want to expose internal error chains, and handle each error once.

```go
// Don't. Logs AND returns (duplicate logs), uppercase/punctuated, bare == check.
if err != nil {
    slog.Error("Failed to load user!", "err", err)
    return fmt.Errorf("Failed to load user: %s.", err)
}
if err == sql.ErrNoRows { ... }

// Do. Single handling rule, lowercase no punctuation, errors.Is/As.
if err != nil {
    return fmt.Errorf("load user %s: %w", id, err)
}
if errors.Is(err, sql.ErrNoRows) {
    return nil, ErrUserNotFound
}
```

## Structured concurrency & context

Always bound goroutine lifetimes with `errgroup.WithContext` and `ctx.Done()`.

```go
// Don't. Unbounded goroutines with no cancellation or error propagation.
for _, id := range ids {
    go func(id string) {
        _ = syncItem(id)
    }(id)
}

// Do. Bounded concurrency, context cancellation, first error returned.
g, ctx := errgroup.WithContext(ctx)
g.SetLimit(8)
for _, id := range ids {
    g.Go(func() error {
        return syncItem(ctx, id)
    })
}
if err := g.Wait(); err != nil {
    return fmt.Errorf("sync batch: %w", err)
}
```

## Locks & timers

Avoid `time.After` inside loops (allocates a new timer every iteration until expiry).

```go
// Don't. Leaks timers in hot loops.
for {
    select {
    case msg := <-ch:
        handle(msg)
    case <-time.After(5 * time.Second):
        return ErrTimeout
    }
}

// Do. Reuse a single timer and stop it on exit.
timer := time.NewTimer(5 * time.Second)
defer timer.Stop()
for {
    select {
    case <-ctx.Done():
        return ctx.Err()
    case msg := <-ch:
        if !timer.Stop() {
            select {
            case <-timer.C:
            default:
            }
        }
        timer.Reset(5 * time.Second)
        handle(msg)
    case <-timer.C:
        return ErrTimeout
    }
}
```

## Structured logging

Keep log messages constant (low cardinality) and attach dynamic values as attributes.

```go
// Don't. High-cardinality message breaks log grouping.
slog.Error(fmt.Sprintf("order %s failed for user %s: %v", orderID, userID, err))

// Do. Stable message + structured attributes.
slog.Error("order processing failed",
    "order_id", orderID,
    "user_id", userID,
    "err", err,
)
```

## Real tests

Use table-driven subtests, `t.Helper()`, `t.Cleanup()`, and run with `-race`.

```go
func TestParseAmount(t *testing.T) {
    cases := []struct {
        name    string
        input   string
        want    int64
        wantErr bool
    }{
        {name: "valid dollars", input: "12.50", want: 1250},
        {name: "negative rejected", input: "-1.00", wantErr: true},
    }
    for _, tc := range cases {
        t.Run(tc.name, func(t *testing.T) {
            got, err := ParseAmount(tc.input)
            if (err != nil) != tc.wantErr {
                t.Fatalf("ParseAmount(%q) err = %v, wantErr = %v", tc.input, err, tc.wantErr)
            }
            if got != tc.want {
                t.Errorf("ParseAmount(%q) = %d, want %d", tc.input, got, tc.want)
            }
        })
    }
}
```
