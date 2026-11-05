---
name: dotagents
description: "Install, update, remove or check the user's machine-wide AI agents and skills (shared by Claude Code, Copilot CLI and OpenCode) through the dotagents repo at ~/.aiglobal. Use when the user wants to add an external skill or agent from GitHub (\"install this skill\", \"add this agent\", a github.com link to a SKILL.md or agent .md), list what's installed, update external sources, check that rulesync and the tools are installed at the right versions, or fix the setup. Not for skills or agents that belong to a single project's repo."
targets:
  - '*'
---

# dotagents

The user keeps every machine-wide agent, skill and rule in one repo, linked at
`~/.aiglobal`. Its installer, `~/.aiglobal/bin/dotagents`, writes them into Claude
Code, Copilot CLI and OpenCode at once. Always go through it; never copy files into
`~/.claude`, `~/.copilot` or `~/.config/opencode` by hand.

Run every command from the repo: `cd ~/.aiglobal && bin/dotagents <command>`.

## Check first

```bash
cd ~/.aiglobal && bin/dotagents doctor --json
```

Each result has a `level` (`ok`, `warn`, `fail`, `skip`) and a `message` naming the
fix. If anything is `fail`, run `bin/dotagents setup`. If Node is too old, run
`./setup.sh` (it uses nvm), then check again. If `~/.aiglobal` doesn't exist, the
repo isn't set up on this machine: tell the user, don't create it.

## Add something

1. Work out the source from what the user gave you. From a link like
   `https://github.com/<owner>/<repo>/blob/<ref>/<path>`:
   - **skill** (a folder with `SKILL.md`): the source is `<owner>/<repo>`, the skill
     name is the folder name, and `--path` is the folder that contains it
     (default `skills`).
   - **agent** (a single `.md` file): the source is `<owner>/<repo>`, and the path
     is `<path>`.
2. **Read it before installing.** Fetch the file(s) (`gh api` or the raw URL), and
   tell the user in a few lines what it does, which tools it asks for, and anything
   risky: shell commands, network calls, instructions to ignore other rules. Only
   continue once they agree.
3. Install it, pinning a tag with `--ref` if the repo has releases:
   ```bash
   cd ~/.aiglobal
   bin/dotagents add-skill <owner/repo> --skills <name>[,<name>] [--path <dir>] [--ref <tag>]
   bin/dotagents add-agent <owner/repo> <path/to/agent.md> [--ref <tag>] [--name <new-name>]
   ```
   `add-agent` guesses the format from the path (`*.agent.md` is Copilot,
   `.opencode/agent/` is OpenCode, otherwise Claude); override with `--format`. If it
   says a local agent with that name exists, ask the user for another name and pass
   `--name`.
4. Confirm with `bin/dotagents doctor` and `bin/dotagents list`.
5. Commit in `~/.aiglobal` (Conventional Commits, e.g. `feat: add api-designer agent`).
   Don't push unless the user asks.

## Other tasks

| Task | Command |
|---|---|
| What's installed | `bin/dotagents list --json` |
| Remove an external agent | `bin/dotagents remove-agent <name>` (generated copies stay; say so) |
| Remove an external skill | delete its entry from `sources` in `rulesync.jsonc`, then `bin/dotagents install`; delete the generated skill folders by hand if asked |
| Update every external source | `bin/dotagents update`, then show `git diff rulesync.lock external-agents.json` |
| Re-install at pinned commits | `bin/dotagents install` |

## Rules

- Keep `"delete": false` in `rulesync.jsonc`.
- Don't edit `.rulesync/skills/.curated/` or the external agents listed in
  `external-agents.json`; they're overwritten on install. To customize one, copy it
  in as a local skill or agent under a new name.
- Generated copies don't carry Claude-only frontmatter (tools, model) to Copilot or
  OpenCode. Mention this when an agent depends on tool limits.
- `~/.aiglobal/AGENTS.md` has the full reference.
