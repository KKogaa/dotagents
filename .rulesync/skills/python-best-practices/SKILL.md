---
name: python-best-practices
description: Modern Python 3.11+ best practices. Use when reading, writing, or reviewing any .py file or pyproject.toml.
targets:
  - '*'
---

# Python best practices

Apply type-system discipline and boundary discipline first. Check `pyproject.toml` for the Python floor, package manager (`uv`, `poetry`, `pip`), linter/formatter (`ruff`, `black`), type checker (`mypy`, `pyright`), and test runner (`pytest`).

| Rule | Summary |
|------|---------|
| Modern type hints | Annotate every public signature. Use built-in generics (`list[T]`, `dict[K, V]`) and `X \| None` instead of legacy `typing.List`, `Dict`, `Optional`. |
| `object` over `Any` | External data is `object` or `JsonValue`, never `Any`. Narrow with `isinstance` / `TypeGuard`, or parse through a schema. Keep `# type: ignore[code]` specific with a reason. |
| Discriminated unions | Model variants with `Literal` tags + frozen `@dataclass(slots=True)` and narrow with `match` + `assert_never` so impossible states can't be represented. |
| Structural interfaces (`Protocol`) | Define contracts with `typing.Protocol` instead of deep inheritance trees. Accept narrow protocols, return concrete types. |
| Schemas at boundaries | Parse external JSON, env vars, CLI args, and API payloads once with the repo's schema library (e.g., Pydantic `BaseModel` / `TypeAdapter`). Stop raw `dict[str, Any]` at the boundary. |
| No mutable defaults | Never use `[]`, `{}`, or `set()` as default function args or bare dataclass fields. Default to `None` or `field(default_factory=...)`. |
| Explicit exceptions & chaining | Never use bare `except:` or swallow `Exception`. Raise specific domain/built-in exceptions and preserve causality with `raise DomainError(...) from err`. |
| Context managers for resources | Always manage files, connections, locks, and HTTP clients with `with` / `async with` (`contextlib.ExitStack` for dynamic lifecycles). |
| Sync vs async separation | Stay strictly sync or strictly async along a call path. Never block an `asyncio` event loop with sync HTTP/DB/CPU calls — offload via `asyncio.to_thread()` or a process pool. |
| Structured concurrency | Prefer `asyncio.TaskGroup` (3.11+) over fire-and-forget `create_task()` so failures propagate and siblings cancel cleanly. Never swallow `asyncio.CancelledError`. |
| Single timeout & retry layer | Set explicit timeouts on every network/DB call and centralize retries at one layer only (never double-retry across client and caller). Retry only idempotent calls. |
| Modern stdlib & structured logs | Use `pathlib.Path` over `os.path`, `logging` with structured context over `print`, and typed env settings — never hardcode secrets. |
| Real tests | Write `pytest` tests asserting observable behavior (parametrize edge cases, cover error paths). Mock only external I/O boundaries you can't run locally. Verify with `ruff`, `mypy`/`pyright`, and `pytest`. |

Examples: `references/patterns.md`.
<!-- Distilled from wshobson/agents (MIT) and Jeffallan/claude-skills (MIT). See THIRD_PARTY_LICENSES.md. -->
