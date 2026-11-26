---
name: fleet
description: >-
  Route software work to the dotagents agent fleet (the software factory)
  instead of choosing an approach yourself: product-owner for ideas and
  backlogs, tech-lead for project setup and technical decisions, developer
  (using pstack playbooks and skills inside the dotagents SDLC shell) to
  implement a story or task through to a PR, reviewer to review it. Also covers
  running that work in Agent Orchestrator (ao) sessions, one per repo, with a
  prompt that names the agent. Use whenever the user asks to plan, build,
  implement, change, fix or review software, to "use my agents / fleet /
  factory", or to run a task "in ao".
targets:
  - '*'
---
# Fleet: route work to the software factory

The software factory is the set of agents installed from dotagents. Your job is to
pick the right one, hand it everything it needs, and keep the human in the loop.
Don't do the work yourself with ad-hoc tools when one of these agents owns it, and
don't substitute another workflow for it.

## Which agent

| The work | Agent | Notes |
|---|---|---|
| A rough idea, "explore this", a new epic, "create the backlog" | `product-owner` | Runs `product-explorer` subagents for discovery, then writes epics and stories on a GitHub Project after the human approves. |
| A new project: stack, ADRs, repo setup, walking skeleton, CI, AGENTS.md; or one technical decision that needs an ADR | `tech-lead` | Run after `product-owner` for a new product. |
| Implement a story, bug, refactor, or task through to a PR; "work on #N", "next story", "keep going"; follow up on a PR's CI and review comments | `developer` | Uses pstack playbooks (`feature`, `bug-fix`, `refactoring`, `investigation`) and principles inside the dotagents SDLC shell: runs `e2e` when `.claude/fleet.md` has an E2E section, verifies acceptance criteria and checks, asks before pushing, opens the PR, and runs the single reviewer gate. |
| Review a PR or branch, or re-review after fixes | `reviewer` | Single verifier gate to move a story to Done. Delegates to CIX's `inic-pr-review` (`cix-pr-reviewer` + `cix-pr-verifier`) for non-personal projects, and runs the built-in generic review (`review-verifier`) for personal projects (`origin` owned by `KKogaa`). Posts to the PR only after the human confirms. In non-personal projects, passing review **never** merges the PR into `develop` — merging always stays with the human. |

The order for a new product is product-owner → tech-lead → developer (one story at a
time, verified by `reviewer` before Done). For greenfield design and architectural
health, use `grill-with-docs` (backed by `grilling` and `domain-modeling` for
`GLOSSARY.md` + ADRs), `codebase-design`, and `improve-codebase-architecture`. For
an existing repo, start at developer (or use the standalone pre-dev & craft skills
directly: `sharpen`, `reframe`, `how`, `why`, `architect`, `blast-radius`, `tdd`,
`correct`, `unslop`, plus the language best-practices skills `typescript-best-practices`,
`java-best-practices`, `quarkus-best-practices`, `python-best-practices`,
`go-best-practices`).

Agents meant to be called only by another agent: `product-explorer` (by
product-owner and tech-lead), `e2e` (by developer), `review-verifier` (by
`reviewer` in personal projects), and `cix-pr-verifier` (internally by
`cix-pr-reviewer` in non-personal projects).

## Profiles and project config

Two kinds of file tell the agents how a project works; they read them themselves,
but name them in a handoff when the work depends on them:

- **Profiles** in this skill's `profiles/` folder: one per GitHub owner (`personal.md`
  for `KKogaa`; local-only ones such as `cix.md` for `CIX-SOFTWARE-LABS`). Each sets the
  GitHub account, base branch, branch name and PR format. Pick by the owner of the
  repo's `origin` remote (`git remote get-url origin`), never by folder path, so the
  choice is the same in any clone, ao worktree or machine. No `origin`: ask which
  profile applies.
- **Project config** `.claude/fleet.md` in a repo or a workspace folder: how the repos relate, verification commands (full and
  fast), safety limits, review checklist, what a push deploys, and the E2E section.
  Template:

  ```markdown
  # Fleet config for <project>
  ## Layout
  <single repo | workspace: the repos and each one's base branch>
  ## How the repos relate
  <who calls whom (HTTP, queues, events), shared libraries, shared tables>
  ## Verification
  <full checks (whole suite, coverage, lint, static analysis) and fast checks (affected tests only) per stack>
  ## Review checklist
  <project rules the reviewer must check>
  ## Deployment
  <what a push or merge to each branch deploys>
  ## E2E
  <environment, allowed resources, secrets, trigger, observe, test data, limits>
  ```

  When a project has none and you had to guess something important (base branch,
  how to test), offer to write one.

## Work without a GitHub issue

`developer` expects a story on the repo's GitHub Project. When the work is tracked
somewhere else (for example a Jira ticket) or is only a description, tell it so in
the prompt: there is no GitHub issue, skip the board moves, use the ticket id for the
branch name and PR title, and give it the acceptance criteria. If the human gave none,
write them from the request and confirm them before handing off.

## Before handing off

Subagents and new sessions don't see this conversation. A good handoff carries:

- the goal and the acceptance criteria (what "done" means);
- what you already found: the files and patterns to reuse, the root cause (for
  multi-service bugs, trace the observed vs. expected timeline against actual code in
  every involved repo before proposing a new column or cross-repo contract), data or
  environment facts (scrub real PII/phone numbers from incident traces or flag them as
  never-commit), and the decisions the human has made;
- open decisions, with your recommendation, for the agent to confirm with the human;
- the repo(s), base branch, ticket id, and paths to project config the agent might not
  find on its own (see AO below);
- safety limits: what must not run locally, which environments are off limits, and
  whether anything may send real messages or touch production data.

If the request is still vague, ask the human the one or two questions that change the
plan before handing off. Don't make them write the prompt.

## Running the work in Agent Orchestrator (ao)

ao is the default place the fleet works. When `ao status` reports `ready`, send
implementation and review work to ao sessions instead of running the agent in this
session. Run it here only when ao isn't installed or running, when the human asks for
it, or for read-only questions and discovery you need before writing the handoff. If
you are already inside an ao worker (the prompt or rules say so), do the work here with
the agent you were given; don't spawn yourself again.

- Setup: `~/.aiglobal/bin/ao-setup check <repo-or-workspace>` shows whether the repos
  are registered with the fleet rules; `ao-setup apply <repo-or-workspace>` registers
  them, sets the base branch (develop when the repo has one) and writes the rules. It
  is local and idempotent: run `apply` yourself when a repo isn't set up, and say so.
- One worker per repo: `ao project ls` lists registered projects. A change across
  repos gets one session per repo (spawned in parallel when independent), and every
  prompt carries the same **cross-repo contract block** so producer and consumer stay
  aligned:
  ```markdown
  ## Cross-repo contract
  - Contract: <topic/queue/endpoint, payload fields, filter/subject, error/idempotency rules>
  - Repos & merge order: 1. <consumer-repo> (PR #...) -> 2. <producer-repo> (PR #...)
  - Review gate: each repo passes its own reviewer (`cix-pr-reviewer` in non-personal repos) before merge
  ```
- Pick the harness and model with `fleet-route` (see "Choosing the model" below), then
  spawn with the agent named in the first line of the prompt:

  ```bash
  ao spawn --project <project-id> --mode chat \
    $(~/.aiglobal/bin/fleet-route pick developer --ao-flags) \
    --name "<repo>: <short task>" \
    --prompt "Use the developer agent to implement this. <handoff>"
  ```

  Write long prompts to a file and pass `--prompt "$(cat <file>)"`.
- ao worktrees live outside the workspace folder (under `~/.ao/data/worktrees/`), so
  workspace-level config isn't found by walking parent directories. `ao-setup` writes
  the workspace path into each project's rules; still name any file the task depends on
  in the prompt.
- `--base` defaults to the project's configured base branch; pass it only to override.
- `developer` runs the single verification gate before moving a story to Done
  (invoking CIX's `cix-pr-reviewer` directly in non-personal projects, or `reviewer`
  in personal projects), so the orchestrator doesn't need to spawn a duplicate reviewer
  session after every worker PR. Spawn a standalone reviewer session only for an
  external PR or an on-demand review:
  `ao spawn --project <project-id> --claim-pr <pr> --review $(~/.aiglobal/bin/fleet-route pick reviewer --ao-flags) --name "<repo>: review #<pr>" --prompt "Use the reviewer agent to review PR #<pr>."`
- Follow up with `ao session ls`, `ao session history <id>` and `ao send --session <id> --message "..."`.
  Relay the worker's questions to the human; never answer a plan or approval gate on
  their behalf.
- To see which agents are running inside each session (Claude Code and Antigravity),
  the human can run `ao-agents` (`~/.aiglobal/bin/ao-agents`, linked into `~/.local/bin`
  by `dotagents setup`) in a terminal or an ao terminal tab. Mention it when you start
  workers.

## Choosing the model

The fleet runs on two harnesses: **Claude Code** and **agy** (Antigravity CLI). Don't
use other harnesses (OpenCode, Copilot, Codex) unless the human asks. Both have every
fleet agent and skill: Claude Code through rulesync, agy through the `dotagents` plugin
that `bin/agy-plugin` builds.

`~/.aiglobal/fleet-models.json` lists, for each role, the harness and model to try in
order; `~/.aiglobal/bin/fleet-route` picks the first one that is installed, signed in
and under its limits:

Only three models are used: **Claude Code Opus**, **agy Gemini 4 Neon** and **agy
Claude Opus 5.5**. Roles differ by effort, not by model (`allowed` in the file; any
other model is refused):

| Role | Agents | First choice | Then |
|---|---|---|---|
| `plan` | product-owner, tech-lead, developer | agy `gemini-4-neon-high` | Claude Code `opus` (high), agy `claude-opus-5-5-high` |
| `review` | reviewer (and `cix-pr-reviewer` in non-personal projects) | agy `gemini-4-neon-xhigh` | Claude Code `opus` (xhigh), agy `claude-opus-5-5-high` |
| `implement` | standalone focused implementation (medium effort) | agy `gemini-4-neon-medium` | Claude Code `opus` (medium), agy `claude-opus-5-5-medium` |
| `scout` | product-explorer, review-verifier, lookups | agy `gemini-4-neon-low` | Claude Code `opus` (low), agy `claude-opus-5-5-low` |

The file is the source of truth; this table is a summary. Never pass `--model` to a
subagent or pick Sonnet, Haiku, Gemini Flash or any other model yourself. Inside a
session, every fleet agent runs on Opus in Claude Code and inherits the session's model
in agy, so only the top-level agent of a session is routed, and its subagents share the
session's effort.

- `fleet-route pick <role|agent> --ao-flags` prints the `--harness`, `--model` and
  `--effort` flags for `ao spawn`; `--json` gives the choice and why others were skipped.
  Exit code 3 means nothing is available: tell the human rather than picking a model
  yourself.
- `fleet-route usage` shows Claude Code tokens per model over the last 5h and 7d, ao
  workers included. Claude's plan limits only show in `/usage` inside Claude Code; until
  the human sets them in `fleet-models.json`, usage is reported but doesn't block.
- agy has no usage command. When an agy worker stops on a quota or "out of credits"
  error, run `fleet-route mark agy exhausted --for 5h --reason "<the error>"`, then
  start the work again with the next choice (`fleet-route pick <role> --skip agy`).
  `fleet-route mark agy ok` clears it early. Do the same for Claude Code when it reports
  a usage limit.
- A session can't change harness. To move work to another harness, give the new session
  the handoff plus what the stopped one already did (`ao session history <id>`).
