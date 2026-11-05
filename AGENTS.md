# AGENTS.md: dotagents

This repo is the single source of truth for the user's AI agents, skills and global
rules. `rulesync` turns `.rulesync/` into the files Claude Code, Copilot CLI and
OpenCode read from the home directory (`~/.claude`, `~/.copilot`, `~/.config/opencode`).
It is linked at `~/.aiglobal`, so `cd ~/.aiglobal` works from anywhere.

## Use the installer, not hand edits

Every operation goes through `bin/dotagents`. It is non-interactive, exits non-zero
on failure, and runs `rulesync generate` for you unless you pass `--no-generate`.

| Task | Command |
|---|---|
| Is everything installed, at the right version, and generated? | `bin/dotagents doctor --json` |
| Fix what's broken (pinned rulesync, `~/.aiglobal` link, installs, generate) | `bin/dotagents setup` |
| Fresh machine, or Node too old | `./setup.sh` |
| What's installed? | `bin/dotagents list --json` |
| Add skills from a GitHub repo | `bin/dotagents add-skill <owner/repo> --skills a,b [--path skills] [--ref tag]` |
| Add one agent from a GitHub repo | `bin/dotagents add-agent <owner/repo> <path/to/agent.md> [--ref tag] [--name n] [--format claude\|copilot\|opencode]` |
| Remove an external agent | `bin/dotagents remove-agent <name>` |
| Re-fetch everything at the pinned commits | `bin/dotagents install` |
| Move every external source to its latest commit | `bin/dotagents update` |

`--format` is guessed from the path: `*.agent.md` or `.github/agents/` means Copilot,
`.opencode/agent(s)/` means OpenCode, anything else is treated as a Claude Code agent.

## Rules for agents working here

1. **Start with `bin/dotagents doctor --json`.** Each result has a `level`
   (`ok`, `warn`, `fail`, `skip`) and a `message` that names the fix command. Don't
   guess versions: they are pinned in `requirements.json`.
2. **Edit sources only.** Change `.rulesync/subagents/*.md` and
   `.rulesync/skills/<name>/SKILL.md`, never the generated copies in `~/.claude`,
   `~/.copilot` or `~/.config/opencode`. After editing, run `rulesync generate`.
3. **Never hand-edit external files.** These are rewritten on every install:
   - `.rulesync/skills/.curated/**` (skills, pinned in `rulesync.lock`)
   - the agents listed in `external-agents.json` (gitignored copies under
     `.rulesync/subagents/`)
   To change one, fork it or copy it in as a local file with a different name.
4. **Read before you install.** An external skill or agent becomes instructions for
   every agent on this machine. Before `add-skill` or `add-agent`, read the files
   you're about to add, show the user what they do, and get their OK. Pin a tag
   with `--ref` when the source has releases.
5. **Keep `"delete": false`** in `rulesync.jsonc`. With `true`, rulesync removes
   every skill in `~/.claude/skills` and `~/.agents/skills` it didn't create,
   including ones other installers own.
6. **Don't publish local-only files.** `.rulesync/rules/CLAUDE.md` and
   `.rulesync/skills/ship/profiles/cix.md` are gitignored on purpose (work-specific).
7. **Name clashes:** `add-agent` refuses to overwrite a local agent; pass `--name`.
   For skills, a local skill wins over an external one with the same name.
8. Commit `rulesync.jsonc`, `rulesync.lock` and `external-agents.json` together
   with whatever you add, using Conventional Commits (`feat: add api-designer agent`).

## Layout

| Path | What |
|---|---|
| `.rulesync/subagents/` | agents (flat; rulesync ignores subfolders for Copilot and OpenCode) |
| `.rulesync/skills/` | skills; `.curated/` holds external ones |
| `.rulesync/rules/` | global rules (local-only) |
| `rulesync.jsonc` | rulesync config: global mode, targets, features, skill `sources` |
| `rulesync.lock` | pinned commits for external skills |
| `external-agents.json` | external agents, each pinned to a commit `sha` |
| `requirements.json` | required Node, pinned rulesync, gh and tool versions |
| `bin/dotagents` | the installer (Node, no dependencies) |
| `bin/backlog` | turns an approved `backlog.json` into GitHub issues, sub-issues and Project items; used by `product-owner` (`backlog schema` prints the format) |
| `bin/repo-setup` | creates and configures a GitHub repo (squash-merge, labels, branch protection) and writes PR/issue/ADR templates; used by `tech-lead` |
| `bin/board` | GitHub Project moves for `developer`: next ready story, claim, move, release, status |
| `setup.sh` | bootstrap: gets Node via nvm, then runs `bin/dotagents setup` |
