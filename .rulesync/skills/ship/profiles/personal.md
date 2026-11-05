# Ship profile: personal

Applies to projects under `/mnt/Laplace/projects/personal/` and repos owned by `KKogaa`.

## GitHub account

Personal repos belong to `KKogaa`. If the active `gh` account is a different (e.g. work) account, it can't push here. Don't switch accounts globally; prefix every `gh` command with the personal token:

```bash
GH_TOKEN=$(gh auth token -u KKogaa) gh pr create ...
```

If `git push` over HTTPS fails with a 403, run `gh auth setup-git` once. A repo with no `origin` remote has nowhere to open a PR: stop at the commit and tell the user.

## Base branch

The remote's default branch (`master` or `main`). Personal repos often deploy on push to it, so never push it directly.

## PR

- Base: the default branch. Normal (not draft) PRs.
- Body sections: **Summary**, **Changes**, **Verification** (verifier table), **Review** (verdict and nits), **Deployment notes**.
- When working from an issue: branch `<type>/<issue-number>-<slug>`, and `Closes #<n>` at the end of **Summary**. Personal PRs target the default branch, so the issue closes automatically on merge.
