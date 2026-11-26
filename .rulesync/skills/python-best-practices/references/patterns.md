# Python patterns

Code examples for each rule in `SKILL.md`. The underlying principles are language-agnostic (type-system discipline and boundary discipline).

## Modern type hints & `object` over `Any`

Use built-in generics and `X | None`; avoid letting `Any` propagate past boundaries.

```python
# Don't. Legacy typing imports and Any disables static checking.
from typing import Any, Dict, List, Optional

def active_emails(users: List[Dict[str, Any]]) -> Optional[List[str]]:
    ...

# Do. Modern 3.10+ syntax and concrete domain models.
def active_emails(users: list[User]) -> list[str]:
    return [u.email for u in users if u.is_active]
```

## Discriminated unions & exhaustiveness

Combine `Literal` discriminants, frozen dataclasses, `match`, and `assert_never`.

```python
from dataclasses import dataclass
from typing import Literal, assert_never

# Don't. Optional-field bag permits contradictory states.
@dataclass
class JobState:
    running: bool
    result: str | None = None
    error: str | None = None

# Do. Only valid states exist; type checker enforces exhaustiveness.
@dataclass(frozen=True, slots=True)
class Running:
    kind: Literal["running"] = "running"

@dataclass(frozen=True, slots=True)
class Succeeded:
    output: str
    kind: Literal["succeeded"] = "succeeded"

@dataclass(frozen=True, slots=True)
class Failed:
    reason: str
    kind: Literal["failed"] = "failed"

type JobState = Running | Succeeded | Failed

def describe(state: JobState) -> str:
    match state:
        case Running():
            return "running"
        case Succeeded(output=out):
            return f"ok: {out}"
        case Failed(reason=err):
            return f"err: {err}"
        case _:
            assert_never(state)
```

## Structural interfaces (`Protocol`)

Accept narrow `Protocol` interfaces so callers and tests don't need inheritance.

```python
from typing import Protocol

class Clock(Protocol):
    def now_epoch(self) -> float: ...

def is_expired(expires_at: float, clock: Clock) -> bool:
    return clock.now_epoch() >= expires_at
```

## Schemas at boundaries

Parse external payloads once at the boundary into a validated model; trust types inside.

```python
from pydantic import BaseModel

class WebhookPayload(BaseModel):
    event_id: str
    user_id: str
    amount_cents: int

def handle_webhook(raw_body: bytes) -> None:
    payload = WebhookPayload.model_validate_json(raw_body)
    process_payment(payload)  # downstream trusts WebhookPayload
```

## No mutable defaults

```python
# Don't. Shared list mutates across calls.
def add_tag(tag: str, tags: list[str] = []) -> list[str]:
    tags.append(tag)
    return tags

# Do. Fresh list per call.
def add_tag(tag: str, tags: list[str] | None = None) -> list[str]:
    result = list(tags) if tags is not None else []
    result.append(tag)
    return result
```

## Explicit exceptions & chaining

Always chain exceptions with `from err` and never use bare `except:`.

```python
# Don't. Swallows KeyboardInterrupt and hides root cause.
try:
    data = json.loads(raw)
except:
    raise ConfigError("bad config")

# Do. Narrow catch, cause preserved.
try:
    data = json.loads(raw)
except json.JSONDecodeError as err:
    raise ConfigError(f"invalid JSON in {path}") from err
```

## Sync vs async separation & structured concurrency

Keep blocking calls off the event loop and use `asyncio.TaskGroup` so errors cancel siblings cleanly.

```python
import asyncio

# Don't. Blocks the event loop and leaks sibling tasks on failure.
async def fetch_all(urls: list[str]) -> list[str]:
    tasks = [asyncio.create_task(fetch(u)) for u in urls]
    return [await t for t in tasks]

# Do. Structured concurrency; offload sync CPU/I/O with asyncio.to_thread.
async def fetch_all(urls: list[str]) -> list[str]:
    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(fetch(u)) for u in urls]
    return [t.result() for t in tasks]

async def hash_file(path: Path) -> str:
    return await asyncio.to_thread(compute_sha256_sync, path)
```

## Single timeout & retry layer

Set explicit timeouts and avoid stacking application retries on top of client retries.

```python
# Don't. Client already retries 3x; decorator turns that into 9x.
@retry(stop=stop_after_attempt(3))
def call_api(client: RetryingHttpClient, url: str) -> Response:
    return client.get(url)  # no timeout either

# Do. One retry policy, explicit timeout, idempotent calls only.
def call_api(client: httpx.Client, url: str) -> httpx.Response:
    return client.get(url, timeout=5.0)
```

## Modern stdlib & structured logs

```python
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

# Don't
with open(os.path.join(base_dir, "config.json")) as f:
    print("loaded", f.name)

# Do
config_path = Path(base_dir) / "config.json"
raw = config_path.read_text(encoding="utf-8")
logger.info("config_loaded", extra={"path": str(config_path)})
```
