# dotagents

My AI coding agents, skills and global rules, written once and installed into
**Claude Code**, **GitHub Copilot CLI** and **OpenCode** with
[rulesync](https://github.com/dyoshikawa/rulesync).

## What's in here

All sources live in `.rulesync/`:

| Folder | Contents |
|---|---|
| `subagents/` | `ship-*` (planner, implementer, verifier, reviewer, e2e) and the specflow team: `orchestrator`, `conductor`, `worker`, `backend`, `frontend`, `reviewer` |
| `skills/` | `ship`, `pr-to-develop`, and the specflow skills (`kickoff`, `plan-feature`, `implement-issue`, `review-pr`, `open-pr`, `openspec-*`, ...) |
| `rules/` | global instructions (kept local, see below) |

The specflow agents and skills come from [KKogaa/specflow](https://github.com/KKogaa/specflow).

## Install

```bash
npm install -g rulesync
git clone https://github.com/KKogaa/dotagents
ln -s "$PWD/dotagents" ~/.aiglobal   # optional, a stable path
cd dotagents && rulesync generate
```

`rulesync.jsonc` runs in global mode, so `generate` writes to your home directory:

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
rulesync generate --check  # exit 1 if anything is out of date
```

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
- The specflow skills expect a specflow project (`openspec/`, its scripts and
  `AGENTS.md`). Outside one, they won't have what they need.
