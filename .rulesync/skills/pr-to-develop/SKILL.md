---
name: pr-to-develop
description: >-
  Open a GitHub pull request from the current feature branch into `develop`
  using the `gh` CLI, using the branch name as the PR title, a Spanish summary
  body, and no Claude attribution. Use when the user asks to create/open a PR to
  develop.
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

Read `git diff origin/develop...HEAD`, not just the commit subjects, so the summary describes what actually changed. Follow the active fleet profile (e.g. `cix.md`) when present; defaults for `develop` PRs:

- **Title:** Use the current branch name (e.g. `feature/WTDC-535-remarketing-total-cap`).
- **Body (in Spanish):**

  ```markdown
  ## Resumen
  - <qué cambió y por qué, 1–5 viñetas>

  ## Notas
  - <migraciones, variables de entorno/configuración, seguimientos o cualquier detalle relevante para revisores; omitir la sección si está vacía>
  ```

- **No real PII:** Never include real phone numbers, document numbers, emails, or customer IDs from incident traces in the PR description.
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
