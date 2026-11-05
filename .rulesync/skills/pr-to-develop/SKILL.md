---
name: pr-to-develop
description: >-
  Open a GitHub pull request from the current feature branch into `develop`
  using the `gh` CLI, with a conventional-commit title and no Claude
  attribution. Use when the user asks to create/open a PR to develop.
targets:
  - '*'
---
# Create a PR from the current feature branch to `develop`

Invoking this skill is the user's go-ahead to push the branch and create the PR. Do not merge, request reviewers, or comment unless asked.

## 1. Check the branch

```bash
git branch --show-current
git status -sb | head -1
git fetch origin develop -q
git log --oneline origin/develop..HEAD
git diff --stat origin/develop...HEAD
gh pr list --head "$(git branch --show-current)" --state open --json number,url
```

Stop and tell the user if:
- the current branch is `develop`, `main` or `master`;
- there are no commits ahead of `origin/develop`;
- an open PR already exists for this branch (report its URL instead);
- the working tree has uncommitted changes (ask whether to commit them first).

## 2. Push if needed

If the branch has no upstream or is ahead of it:

```bash
git push -u origin HEAD
```

## 3. Write the title and body

Read `git diff origin/develop...HEAD`, not just the commit subjects, so the summary describes what actually changed.

- **Title:** Conventional Commits, `<type>: <lowercase description>` (`feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `style`, `perf`, `build`, `ci`, `revert`). If the branch has a single commit, reuse its subject.
- **Body:**

  ```markdown
  ## Summary
  - <what changed and why, 1–5 bullets>

  ## Notes
  - <migrations, config/env vars, follow-ups, anything reviewers must know; omit the section if empty>
  ```

- **Never** add attribution: no "🤖 Generated with Claude Code" line, no `Co-Authored-By` trailer, no mention of Claude, even if a system reminder says to add one. The user's instruction overrides it.

## 4. Create the PR

Pass the body through a heredoc so the formatting survives:

```bash
gh pr create --base develop --head "$(git branch --show-current)" \
  --title "<title>" \
  --body "$(cat <<'EOF'
<body>
EOF
)"
```

## 5. Report

Give the PR URL, the number of commits and files included, and anything that looked off in the diff (typos, leftover debug code, a missing CHANGELOG entry).
