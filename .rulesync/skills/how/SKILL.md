---
name: how
description: >-
  Read-only codebase walkthrough for "how does X work", onboarding mental models,
  and placement/ownership/layering questions ("where should this live", "which
  package owns this", "is this the right layer"). Explains subsystem architecture,
  runtime flow, and gotchas with file:line citations. Use `why` for historical
  motivation and `blast-radius` for change risk.
targets:
  - '*'
---
# How

Explore the codebase to answer "how does X work?" or "where should this live?" questions. Read-only: never edit files.

If the scope is ambiguous, state your interpretation and explore. The user can redirect.

## 1. Explore and explain

When the harness supports read-only subagents (Claude Code: `Agent` with `subagent_type: Explore`; Antigravity: `invoke_subagent` with `TypeName: research`), spawn one read-only subagent to explore and explain in one pass so bulk file reading stays out of the main thread. Otherwise, explore directly.

Brief:

> You are writing an architectural explanation for a senior engineer unfamiliar with this area. Explore the codebase read-only and write an explanation that leaves them with a solid mental model so they can work in it confidently. Cite real `file:line` paths for every claim; never invent symbols or flows. Structure the explanation as:
> - **Overview**: what the subsystem owns and its boundaries
> - **Key concepts & data shapes**: the core types, state, and invariants
> - **How it works**: end-to-end runtime flow (entrypoints -> core logic -> side effects/storage)
> - **Where things live**: the key files/modules and what each owns
> - **Gotchas**: non-obvious couplings, ordering constraints, edge cases, or traps

## 2. Present

Present the explanation cleanly (light edits for clarity or conversation context are fine; keep all `file:line` citations). For placement/layering questions, end with a concrete recommendation naming the exact module/folder and why.
