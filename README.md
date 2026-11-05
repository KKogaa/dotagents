# dotagents

My AI coding agents, skills and global rules, written once and installed into
**Claude Code**, **GitHub Copilot CLI** and **OpenCode** with
[rulesync](https://github.com/dyoshikawa/rulesync).

## What's in here

All sources live in `.rulesync/`:

| Folder | Contents |
|---|---|
| `subagents/` | `product-owner` and `product-explorer` (idea → discovery → GitHub backlog), `tech-lead` (decisions, repo, walking skeleton, CI), and `ship-*` (planner, implementer, verifier, reviewer, e2e) |
| `skills/` | `dotagents` (drives the installer), `ship` and `pr-to-develop` |
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
- `.rulesync/skills/ship/profiles/cix.md`: the work profile for `/ship`

On a fresh clone, add your own `.rulesync/rules/*.md` (with `root: true` frontmatter)
and any extra `/ship` profiles next to `profiles/personal.md`.

## Caveats

- Claude-specific frontmatter (tool lists, models) lives under a `claudecode:` key and
  only applies to Claude Code. In Copilot and OpenCode the "read-only" agents are
  read-only only by their instructions.
- `/ship` is written around Claude Code's subagents; elsewhere it's best-effort.
