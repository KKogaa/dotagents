# dotagents

My AI coding agents, skills and global rules, written once and installed into
**Claude Code**, **GitHub Copilot CLI** and **OpenCode** with
[rulesync](https://github.com/dyoshikawa/rulesync).

## What's in here

All sources live in `.rulesync/`:

| Folder | Contents |
|---|---|
| `subagents/` | `product-owner` and `product-explorer` (idea → discovery → GitHub backlog), `tech-lead` (decisions, repo, walking skeleton, CI), `developer` with its `frontend`, `backend` and `e2e` subagents (story → PR: push gate, e2e on the deployed environment, CI and review follow-up), `reviewer` (single verifier gate to Done: delegates to CIX's `cix-pr-reviewer` in non-personal projects, or runs with `review-verifier` in personal projects) |
| `skills/` | `fleet` (routes work to the agents above and picks the harness and model, in this session or in Agent Orchestrator `ao` sessions), `dotagents` (drives the installer) and `pr-to-develop`. `fleet/profiles/` holds one profile per GitHub owner (account, base branch, branch name, PR format) |
| `rules/` | global instructions (kept local, see below) |

Every agent here is standalone: it works in any repo, with no framework or project
scripts required beyond `gh` and this repo's `bin/` tools.

## Requirements

This repo is only the source files; it does nothing without
[rulesync](https://github.com/dyoshikawa/rulesync), the CLI that turns `.rulesync/`
into each tool's own format and folders. You need:

- **Node.js 22.22 or newer** (rulesync's stated minimum) and npm. Any installer works;
  I use nvm.
- **rulesync**, installed globally:
  ```bash
  npm install -g rulesync
  rulesync --version   # tested with 42.0.0
  ```
  Other options: `brew install rulesync`, or run it without installing via
  `npx rulesync <command>`.
- At least one of the target tools: Claude Code, GitHub Copilot CLI or OpenCode.

If you use nvm, rulesync is installed per Node version: after `nvm use <other>`,
reinstall it or the `rulesync` command won't be found.

## Install

```bash
git clone https://github.com/KKogaa/dotagents
cd dotagents && ./setup.sh
```

`setup.sh` gets Node 22.22+ through nvm if needed, then runs `bin/dotagents setup`.
That command installs the pinned rulesync, links `~/.aiglobal` to the repo, installs
the external skills and agents, generates every tool's files, and ends with
`doctor`. Re-run it any time to repair the setup; `./setup.sh --check` only checks.

`rulesync.jsonc` runs in global mode, so generating writes to your home directory:

| Tool | Agents | Skills | Rules |
|---|---|---|---|
| Claude Code | `~/.claude/agents/` | `~/.claude/skills/` | `~/.claude/CLAUDE.md` |
| Copilot CLI | `~/.copilot/agents/` | `~/.copilot/skills/` | `~/.copilot/copilot-instructions.md` |
| OpenCode | `~/.config/opencode/agents/` | `~/.config/opencode/skills/` | `~/.config/opencode/AGENTS.md` |

`delete` is off, so skills installed by other tools in those folders are left alone.

## Workflow

Edit files in `.rulesync/`, never the generated copies, then:

```bash
rulesync generate          # write every tool's files
bin/dotagents doctor       # versions, installs, and whether generated files are current
```

## Product backlog: idea to GitHub Project

Ask the `product-owner` agent with a rough idea. It runs three `product-explorer`
subagents in parallel (users, market and technical lenses), shows you the directions,
helps you choose and scope a first version, then writes
`docs/product/<slug>/brief.md` and `backlog.json` (epics → stories with acceptance
criteria, priority and size). After you approve the preview, it runs:

```bash
bin/backlog validate docs/product/<slug>/backlog.json   # format check, no network
bin/backlog plan  docs/product/<slug>/backlog.json      # what would be created
bin/backlog apply docs/product/<slug>/backlog.json      # issues, sub-issues, Project items
```

`apply` creates epics as issues with stories as sub-issues, links dependencies, and
creates the GitHub Project if missing, with Priority and Size fields. Re-running it
never duplicates: each issue carries a hidden `backlog-id`. GitHub Projects need the
`project` scope (`gh auth refresh -h github.com -s project`).

## Project setup: backlog to walking skeleton

After the backlog, the `tech-lead` agent makes the technical decisions with you
(recorded as ADRs in `docs/adr/`), creates and configures the repo, builds a
walking skeleton (structure, lint, a real test, hello world, CI, deploy), writes
`AGENTS.md` for the other agents, and adds technical notes to the first stories. The
GitHub part is scripted and idempotent:

```bash
bin/repo-setup check owner/repo                          # read-only report
bin/repo-setup apply owner/repo --create --private       # repo, squash-merge, labels
bin/repo-setup templates .                               # PR, issue and ADR templates
bin/repo-setup apply owner/repo --protect --require-check ci   # after CI exists
```

## Implementation: story to pull request

The `developer` agent takes the next ready story from the GitHub Project (or the one
you name), claims it, plans it, and delegates the code to the `frontend` and/or
`backend` subagents. When a story needs both, it writes the API contract first and
runs them in parallel. It then verifies every acceptance criterion and the project's
checks, opens the PR, and moves the card to review. Card moves are scripted:

```bash
bin/board next                  # next ready story: P0 first, smallest first, deps closed
bin/board claim 12              # assign yourself, move to In Progress
bin/board move 12 in-review
bin/board release 12            # give it back
bin/board status
```

## Review: verified PR reviews

The `reviewer` agent is the fleet's read-only code reviewer and **single verifier**
gate to move a story to Done:

- **Non-personal projects** (e.g. `CIX-SOFTWARE-LABS`): delegates to CIX Software Labs'
  `inic-pr-review` plugin (`cix-pr-reviewer` and its internal `cix-pr-verifier`).
- **Personal projects** (`origin` owned by `KKogaa`): runs the built-in
  generic review workflow verified by `review-verifier` (without calling CIX's plugin).
- `developer` runs `reviewer` on its PR after CI passes, fixes any confirmed
  **[Bloqueante]**/**[Blocker]** and **[Importante]**/**[Important]** findings, and
  re-reviews once.
- When `reviewer` passes (**Listo para fusionar** / **Ready to merge**, with CI green),
  the story's board card moves to **Done** (`bin/board move <issue> done`). With
  blockers or **Requiere discusión** / **Needs discussion**, it moves back to **In
  Progress**.
- Publishing comments to the PR still requires explicit human confirmation (comment
  only; never approve or merge). Supports re-review after new commits.

## Running the fleet in Agent Orchestrator (ao)

The `fleet` skill routes work to the agents above, and when the
Agent Orchestrator (`ao`) daemon is
running it sends implementation and review work to ao sessions: one worker per repo,
each prompt naming the agent (`Use the developer agent to ...`), with `reviewer`
running inside the developer flow as the single verifier gate to Done. ao is optional;
without it the fleet runs agents in the current session.

Set up a repo, or a workspace folder of repos, in one command:

```bash
bin/ao-setup check ~/projects/acme     # read-only: what's registered, what's missing
bin/ao-setup apply ~/projects/acme     # register + configure (idempotent)
```

`apply` registers each repo as an ao project, sets the worker and orchestrator harness
(`--agent`, default `claude-code`), sets the base branch for new worktrees (`--base`:
`auto` picks `develop` when the repo has one), and writes a managed block into the
project's standing rules that points sessions at the `fleet` skill. For a repo inside a
workspace, the block also names the workspace folder: ao worktrees live outside it, so
its `AGENTS.md` and `.claude/` config aren't found otherwise. Other rules already on
the project are kept.

`ao-agents` is a live terminal view of the agents running inside each ao session
(ao's sidebar shows sessions, not the subagents inside them). Run it in a terminal or
an ao terminal tab; `--once` prints a snapshot. `bin/dotagents setup` links both tools
into `~/.local/bin`, and `doctor` checks ao, its daemon and the links.

## Models: which harness runs what

The fleet runs on **Claude Code** and **agy** (Antigravity CLI). rulesync has no agy
target, so `bin/agy-plugin build` turns what rulesync generated for Claude Code into a
native agy plugin at `~/.gemini/config/plugins/dotagents/` (agents as `*.agent.md`,
skills, and the global rules as `rules/AGENTS.md`), validates it with
`agy plugin validate --strict`, and installs it. `bin/dotagents install|setup` run it
after `rulesync generate`, and `doctor` checks it's up to date. OpenCode and Copilot
CLI still get the generated files, but the fleet doesn't route work to them.

`fleet-models.json` lists, per role (`plan`, `review`, `implement`, `scout`), the
harness and model to try in order. Only three models are allowed (Claude Code Opus,
agy Gemini 4 Neon, agy Claude Opus 5.5) and roles differ by effort: Neon first (xhigh
for review, high for planning, medium for implementation, low for scouting), then
Claude Code Opus at the same effort, then agy's Opus. `bin/fleet-route` picks the first
that is installed, signed in and under its limits, and refuses any model outside the
file's `allowed` list:

```bash
fleet-route roles                          # the table
fleet-route pick developer --ao-flags      # --harness agy --model gemini-4-neon-high
fleet-route usage                          # Claude Code tokens per model, last 5h / 7d
fleet-route mark agy exhausted --for 5h    # agy hit its quota: skip it for 5 hours
```

Claude Code usage comes from the session transcripts (ao workers included); its plan
limits only show in `/usage`, so set `harnesses.claude-code.limits` in
`fleet-models.json` once you've compared the two. agy has no usage command, so a quota
error is recorded with `mark`. Inside a session, every agent runs on Opus in Claude Code and inherits the session's
model in agy.

## Adding external skills and agents

`bin/dotagents` installs skills and agents from other GitHub repos, pinned to a
commit so installs are reproducible:

```bash
bin/dotagents add-skill anthropics/skills --skills skill-creator
bin/dotagents add-agent VoltAgent/awesome-claude-code-subagents categories/01-core-development/api-designer.md
bin/dotagents list                 # what's installed, and at which commit
bin/dotagents update               # move everything to the latest commit
bin/dotagents remove-agent api-designer
```

- **Skills** use rulesync's own sources: they're added to `sources` in
  `rulesync.jsonc`, pinned in `rulesync.lock`, and installed into the gitignored
  `.rulesync/skills/.curated/`.
- **Agents** have no rulesync equivalent, so the script handles them. It fetches the
  file at a commit, converts it from Claude, Copilot or OpenCode format with
  `rulesync import` (`--format` overrides the guess from the path), and records the
  commit in `external-agents.json`. The converted copy is gitignored.

Commit `rulesync.jsonc`, `rulesync.lock` and `external-agents.json`: they're enough
to reinstall everything with `bin/dotagents install`.

## For agents

Agents can drive all of this. `AGENTS.md` (also read by Claude through `CLAUDE.md`)
is the reference for an agent working in this repo. The `dotagents` skill is
installed globally, so an agent in any project knows to `cd ~/.aiglobal` and use
the installer when you say "install this skill" or paste a GitHub link. `doctor`
and `list` take `--json`, and every command is non-interactive.

## Versions

`requirements.json` sets the required versions: Node 22.22+, rulesync pinned to an
exact version, gh, and minimum versions of Claude Code, Copilot CLI and OpenCode.
Only installed tools are checked, but at least one of the three is required. To
move to a new rulesync, bump the pin, run `bin/dotagents setup`, and check that
`doctor` passes.

## Local-only files

Work-specific files are gitignored and never published. rulesync still uses them on
the machine that has them:

- `.rulesync/rules/CLAUDE.md`: global rules (GitHub account and org setup)
- `.rulesync/skills/fleet/profiles/cix.md`: the work profile (CIX repos)

On a fresh clone, add your own `.rulesync/rules/*.md` (with `root: true` frontmatter)
and any extra profiles next to `.rulesync/skills/fleet/profiles/personal.md`. Projects
describe themselves in `.claude/fleet.md` (template in the `fleet` skill).

## Caveats

- Claude-specific frontmatter (tool lists, models) lives under a `claudecode:` key and
  only applies to Claude Code. In Copilot and OpenCode the "read-only" agents are
  read-only only by their instructions.
