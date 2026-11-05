---
name: ship
description: >-
  Take a task from description to pull request by orchestrating subagents - plan
  (ship-planner), implement (ship-implementer), verify (ship-verifier), review
  (ship-reviewer), fix loop, commit, push, e2e on the real deployed environment
  (ship-e2e), open a PR per affected repo, then follow CI and review comments.
  Works in single-repo and multi-repo projects. Use when the user runs /ship or
  asks to "ship" a task, or take a bug/feature end to end to a PR.
targets:
  - '*'
claudecode:
  argument-hint: <task description | issue URL |
  disable-model-invocation: true
---
# /ship: plan → implement → verify → review → PR

You are the orchestrator. Subagents do the work in their own contexts; you hold the plan, move results between them, manage git, and talk to the user. Don't implement or review code yourself: an independent implementer, verifier and reviewer are the point of this workflow.

Task: $ARGUMENTS

If the task is empty, ask what they want to do in a sentence or two; the details come out in step 2. The task doesn't have to be well-formed: a rough idea, a bug symptom, or a pasted message is fine. Step 2 turns it into something plannable through conversation.

### GitHub issues

The task can be a GitHub issue: a URL, `owner/repo#123`, or `#123` (meaning the current repo; in a multi-repo project, ask which repo). Pick the profile first (next section) so you use the right GitHub account, then read it:

```bash
gh issue view <ref> -R <owner>/<repo> --comments --json number,title,body,labels,assignees,state,url,comments
```

- The issue title, body **and comments** are the task. Comments often hold the clarifications that change the plan; pass them to the planner.
- If the issue is closed, or already has a linked open PR (`gh pr list -R <owner>/<repo> --search "<number> in:body" --state open`), tell the user before planning.
- Remember the issue reference for branch naming (step 4), the PR body (step 8) and the issue comment (step 8).

Reading the issue is free; anything that writes to it (comments, labels, assignees, closing) waits for the user's yes at step 8.

## Profile

Personal and work projects use different GitHub accounts, base branches and PR formats. Pick the profile before anything else. Each file in `profiles/` (relative to this skill's directory) starts with an "Applies to" line naming a working-directory prefix and an `origin` owner: list them, and pick the one whose prefix contains the working directory, then the one whose owner matches `origin`. `profiles/personal.md` is always there; other profiles (such as a work one) are local files that may exist only on this machine.

If none matches, or the two signals disagree, ask the user which profile to use. Read the chosen profile file (relative to this skill's directory) and state which one you're using in your first message.

## Ground rules

- **Precedence:** project config > profile > defaults below. Look for `.claude/ship.md` in the working directory and each parent directory up to the filesystem root or your home directory; read every one found, outermost first, so a workspace file (e.g. `acme/.claude/ship.md`) applies to all its repos and a repo's own file refines it. Read them after the profile; it can set the repo layout, base branch, verification commands, review checklist and deployment notes, and overrides the profile where they conflict. Without it, rely on the profile, the project's `CLAUDE.md` / `AGENTS.md`, and what you detect.
- **Two human gates:** plan approval (step 3) and push/PR (step 8). Before them, step 2 is a conversation with the user to shape the task. Everything between the two gates runs without asking. After the push/PR gate, follow-up fix pushes to the same branch (steps 8.4 and 9) are covered by that yes; replies to review threads still ask.
- **Never commit to or push the base branch.** In many projects merging or pushing it deploys.
- Subagents don't see this conversation. Every delegation prompt must carry what they need: the plan, the repos/packages they own, the branch, the base branch, any findings to fix, and the paths to the profile file and `.claude/ship.md` if it exists (those files are how the generic agents learn the project).
- Commit messages and PR text follow the user's global conventions (Conventional Commits, no Claude attribution).

## 1. Preflight

Work out the layout:
- **Single repo:** the project root is a git repo (`git rev-parse --show-toplevel`).
- **Multi-repo:** the root is not a git repo, but direct child directories are. Run every git command with `git -C <repo>`.
- **Repo inside a workspace:** the working directory is a repo, but its parent holds sibling repos (e.g. `acme/acme-api-auth`). Treat the parent as the workspace so the change can span repos; the current repo is just the most likely starting point.

For each repo: base branch from `.claude/ship.md`, else the profile's rule, else `git -C <repo> symbolic-ref --short refs/remotes/origin/HEAD` (strip `origin/`), else ask. Then `git -C <repo> status -s`, current branch, and `git -C <repo> fetch -q origin`.

Note any repo with uncommitted changes or not on its base branch. The affected repos aren't known until there's a plan, so only flag these now and resolve them in step 4.

### Missing AGENTS.md

`AGENTS.md` is how the subagents learn a repo, so a repo without one gets one. Check the current repo now, and any other repo once the plan names it as affected. If it has no `AGENTS.md`, spawn a **general-purpose** agent to draft one into the session scratchpad (`<scratchpad>/<repo>/AGENTS.md`), not into the repo, so the working tree stays clean for step 4. Its prompt says:
- **Sources:** `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, the manifest (`package.json`, `pom.xml`, `pyproject.toml`, ...), CI workflows, lint/format configs, `.github/copilot-instructions.md` and `.github/instructions/`, and the source tree layout. In a workspace, use a sibling repo's `AGENTS.md` as the format template, so the repos read alike.
- **Contents:** what the service does and what it talks to (HTTP, queues/topics, DB tables), architecture and folder layout, build/test/lint commands as the manifest and CI actually define them, code and test conventions, env vars by name, and what not to run locally (needs cloud resources, a DB, real secrets).
- **Rules:** only facts found in the repo; link to existing instruction files instead of copying them; never copy values from `.env`, `local.settings.json` or other secret files; mark anything it couldn't confirm as `TODO: confirm`.

Pass the draft's path to every subagent in place of the missing file. It's committed in step 4.

Check GitHub access once with the account the profile says to use (e.g. prefix the profile's `GH_TOKEN=...`): `gh repo view --json viewerPermission` inside a repo. If it's not WRITE/MAINTAIN/ADMIN, tell the user at the plan gate that the PR step will fail as things stand.

## 2. Shape the task

Before planning, make sure the task says **what should change, where, and how you'd know it's done**. A well-written issue usually does; a one-line idea usually doesn't.

The user shouldn't have to write the whole story up front. Get to the brief by talking it through with them: they give fragments, you do the legwork in the code and turn them into requirements.

1. **Scout.** Spawn **Explore** (read-only, cheap) to find where the task lands in the workspace: the code involved and which repos it touches. In a workspace, have it search **all** sibling repos for the things the task affects (endpoints, queue or topic names, shared package imports, DTOs, DB tables, env vars), because a change to a producer usually needs a matching change in its consumers. Scout again whenever the conversation brings in code you haven't looked at.
2. **Talk it through.** Unless the task is already clear (then skip to 3), go back and forth until goal, behavior, scope and "done when" are settled. Each of your turns is short:
   - **What I understand so far:** 2-4 lines, in the user's terms, updated with their last answer.
   - **What the code says:** the findings that matter for the decision, e.g. "the `transaction-credit-delayed` event already carries `error.message`; `payments-api` publishes it."
   - **Questions:** 1-3 at a time, the most important first, each with your proposed answer so the user can reply "yes", "2 no, it should …", or just keep describing:
     > 1. Should failed payouts be retried automatically, or only flagged? **Proposed: flagged, no retry.**
     > 2. This also changes the response of `GET /payments/:id`, which `checkout-web` reads. Update the webview in the same change? **Proposed: yes.**

   Accept answers in any shape: fragments, pasted messages or logs, "like we did for X", or a change of mind. Look things up in the code yourself rather than asking the user. Don't ask anything the code answers, don't run a questionnaire, and don't ask for the sake of asking. If the user says "go" / "just plan it" at any point, stop asking: fill the gaps with your proposed answers and list them as assumptions in the brief.
3. **Write the brief.** This is what the planner receives. Show it to the user and ask whether it's right before planning; one quick confirmation, not another round of questions (unless they correct something). Put any assumptions you made under **Behavior** or **Out of scope**, marked `(assumed)`.

```markdown
## Task brief
**Goal:** <the outcome the user wants, in their terms>
**Why:** <problem or motivation, if known>
**Behavior:** <what should happen after the change; include examples/inputs where useful>
**Out of scope:** <what not to touch>
**Repos:** <repo>: <role in this change: producer/consumer/shared lib/...>, ...
**Done when:** <acceptance criteria the reviewer can tick off>
**Source:** <issue ref, or "user request">
```

## 3. Plan (gate)

Spawn **ship-planner** with the brief, the layout from preflight, and the config file paths.

Show the user the brief and the plan together, and ask them to approve, edit, or stop. If an `AGENTS.md` was drafted, say so, give its path and list its `TODO: confirm` lines; the user can edit it, or drop it from the PR. Don't continue without approval. If they edit either, apply the edits to your copy; that copy is the plan from now on.

For a **multi-repo** plan, also show at this gate:
- **Merge order** (e.g. shared lib → API → consumers) and whether each PR is safe to deploy alone. Prefer backward-compatible steps (add the new field/endpoint first, remove the old one later) so the repos can merge and deploy independently; if the planner couldn't avoid a lockstep change, flag it plainly.
- **Tracking:** if the task didn't come from an issue, offer to save the brief as one, in the repo where the change starts (or the one the user names), with a checklist of one line per repo. All PRs then reference it. Creating the issue writes to GitHub, so only on an explicit yes; declining is fine.

## 4. Branch

Branch name: use the profile's branch format if it has one. Otherwise `<type>/<short-kebab-slug>` from the plan's commit line, e.g. `fix/worker-state-race`, or `<type>/<issue-number>-<slug>` when working from an issue, e.g. `fix/42-worker-state-race`.

For each affected repo:
- If it has uncommitted changes, stop and ask the user: stash, commit separately, or abort. Don't stash on your own.
- `git -C <repo> switch <base> && git -C <repo> pull --ff-only && git -C <repo> switch -c <branch>`
- If an `AGENTS.md` was drafted for it (and not dropped at the gate), copy it to the repo root and commit it on its own first: `git -C <repo> add AGENTS.md && git -C <repo> commit -m "docs: add agents.md"`. A separate commit keeps it easy to review or revert apart from the change.

## 5. Implement

Spawn **ship-implementer** with the full plan, the repos/packages it owns, and the branch.

- Use one implementer per repo or package when their steps are independent, and run them in parallel.
- If steps cross boundaries (shared types, an API and its client), use one implementer for all of them so the change stays consistent.

If the project config has an `## E2E` section and the change is observable from outside (a new or changed event, endpoint, message, or row), spawn **ship-e2e** in **design mode** at the same time, with the brief, the acceptance criteria, the config paths and a scratchpad path for the scenarios. Don't give it the plan's steps or the diff; it designs from the requirement alone.

## 6. Verify and review

Run in parallel:
- **ship-verifier**: the plan's Verification section, the changed repos/packages, and any verification commands from `.claude/ship.md`.
- **ship-reviewer**: the plan (goal, steps, acceptance criteria), the changed repos, the branch and the base branch.

## 7. Fix loop (max 2 rounds)

If the verifier says FAIL or the reviewer says CHANGES REQUESTED:
1. Send the failure details and blocking/should-fix findings to the implementer. Resume the same implementer with SendMessage so it keeps its context; spawn a new one only if that fails.
2. Re-run step 6.

After 2 rounds, stop and show the user the remaining failures and findings, and ask how to proceed. Nits never block; list them in the PR body instead.

## 8. Commit, push, PR (gate)

For each affected repo:
1. `git -C <repo> add -A && git -C <repo> commit -m "<type(scope): subject>"`
2. Show the user a summary per repo: branch, `git -C <repo> diff --stat <base>...HEAD`, verifier result, reviewer verdict, and remaining nits. If working from an issue, also show the comment you'd post on it. If the project config says what a push deploys (e.g. feature branches → a shared dev environment), say it plainly. If there are e2e scenarios, list them with their real side effects (who gets a message). Ask for one confirmation covering: push (and the deploy it triggers), the e2e run, follow-up fix pushes to this same branch (steps 8.4 and 9), opening the PR and (if applicable) commenting on the issue. This writes to GitHub and the environment, so wait for an explicit yes; the user may approve some of these and not others.
3. On yes, push, using the GitHub account from the profile (or `.claude/ship.md` if it overrides it): `git -C <repo> push -u origin <branch>`.
4. **E2E (if approved and scenarios exist):**
   - Wait for the deploy of the pushed commit: find the run with `gh run list -R <owner>/<repo> --branch <branch> --commit <sha> --json databaseId,workflowName,status`, then `gh run watch <id> -R <owner>/<repo> --exit-status`. If it fails, treat it like a verifier FAIL (pull `gh run view <id> --log-failed`).
   - Spawn **ship-e2e** in **run mode** with the scenarios file, repo, branch, head commit, deploy run id and config paths.
   - **FAIL:** run the fix loop (step 7, including step 6's checks), commit, push, wait for the deploy, and re-run e2e. Max 2 rounds, then stop and ask.
   - **BLOCKED / INCONCLUSIVE:** show the user why and ask. If the environment is shared and someone else's deploy replaced yours, re-pushing would replace theirs, so don't do it without a yes.
5. Open the PR:
   ```bash
   gh pr create -R <owner>/<repo> --base <base> --head <branch> --title "<type(scope): subject>" --body "<body>"
   ```
   Title and body follow the profile's PR format. Put the e2e result (environment, deployed commit, one line per scenario, or why it was skipped) under Notes. If the PR adds a generated `AGENTS.md`, say so in the body and ask reviewers to check it. If several repos are affected, link the sibling PRs in each body and state the merge order when one depends on another.
6. **When working from an issue:**
   - Link it in the PR body: `Closes #<n>` for an issue in the same repo, `Closes <owner>/<repo>#<n>` otherwise. GitHub only auto-closes the issue when the PR merges into the repo's **default** branch; if the base isn't the default (e.g. `develop` when the default is `main`), write `Refs` instead of `Closes` and say in the report that the issue must be closed by hand. In a multi-repo change, use `Closes` in only one PR (the last to merge) and `Refs` in the rest.
   - If approved, comment on the issue with the PR link(s) and a 2-3 line summary: `gh issue comment <n> -R <owner>/<repo> --body "<text>"`. No Claude attribution.

## 9. Follow the PR

The PR isn't done when it opens: CI (security scans, tests, deploy) and automated reviewers (e.g. Copilot) report afterwards. For each PR:
1. Wait for checks: `gh pr checks <n> -R <owner>/<repo> --watch --fail-fast`, bounded to about 30 minutes. For each failure, pull `gh run view <run-id> --log-failed` (HTTP 410 means the logs expired; say so). Also read open code-scanning alerts on the PR: `gh api 'repos/<owner>/<repo>/code-scanning/alerts?ref=refs/pull/<n>/merge&state=open'`.
2. Read unresolved review threads with the GraphQL query from the user's global instructions. Triage each: **fix** (a real problem), **reply** (disagree, or out of scope; draft the reply with the reason), or **ignore** (outdated, or already handled).
3. Send failures and **fix** threads to the implementer, re-run step 6, commit, and push (covered by the step-8 yes). If the fix changes behavior and e2e ran, re-run step 8.4.
4. Replying to threads and resolving the ones you fixed is outward-facing: show the batch (thread, action, reply text) and ask once.

Max 2 rounds, then stop and report what's left. Human reviews can take days; don't wait for them. Offer to re-check later with `/loop` instead.

## 10. Report

End with one line per PR (URL) with its checks status, e2e result and open threads, and anything the user must do: merge order, config or env changes to apply, skipped checks. Merging stays with the user.

## Project config template

If a project has no `.claude/ship.md` and you had to guess something important (base branch, GitHub account, how to test), offer to create one at the end:

```markdown
# Ship config for <project>

## Layout
<single repo | multi-repo: list repos, base branch for each>

## How the repos relate
<who calls whom (HTTP, queues, events), shared libraries and who imports them, shared DB tables; this is what lets /ship spot multi-repo changes>

## GitHub
<account or token command to use for push/PR, if not the active gh account>

## Verification
<commands that must pass; what not to run (needs DB, hits prod)>

## Review checklist
<project-specific risks: concurrency, shared types, migrations, env vars in deploy manifests>

## Deployment
<what merging/pushing does>

## E2E
<the real environment ship-e2e tests against after the push deploys the branch; ship-e2e never uses mocks or containers. Allowed resources (and that nothing else may be touched), where secrets come from, how to check which commit is deployed, how to trigger (publish/call) and observe (DB, logs, DLQ), test data and the only allowed recipients of real messages, max messages per run, known gotchas>
```
