---
description: Rank open pull requests for review
---

## Context
Repository: !`git remote get-url origin 2>/dev/null | sed -E 's#(git@github.com:|https://github.com/)([^.]+)(\.git)?#https://github.com/\2#' || echo "No repository"`

## Execution steps

1. Treat `$ARGUMENTS` as optional review preferences, such as area, author, labels, size limit, or "include drafts". Defaults: exclude drafts, exclude WIP, rank easiest useful reviews first.
2. Confirm the current directory is inside a git repository. If not, stop and report that this command needs a git repo.
3. Confirm `gh` is installed and authenticated. If missing or unauthenticated, report the exact command the user can run, such as `gh auth login`.
4. Confirm `jq` is installed. If missing, report that `jq` is required to rank PRs locally.
5. Collect open PRs for the current repository with `gh pr list --state open --json number,title,author,isDraft,additions,deletions,baseRefName,headRefName,labels,reviewDecision,updatedAt,url`.
6. Exclude drafts unless `$ARGUMENTS` says to include them. Exclude WIP PRs by title prefixes like `WIP`, `[WIP]`, `Draft`, or labels that clearly mark work in progress.
7. Rank easy reviews first using filtered additions and deletions. Ignore generated files, lockfiles, vendored files, snapshots, and package manager artifacts when possible by checking PR file lists with `gh pr view <number> --json files`.
8. Show a dependency tree when any PR base branch matches another open PR head branch. Put parent PRs before children.
9. Apply optional preferences from `$ARGUMENTS` after dependency ordering. Explain which preferences changed the ranking.
10. Do not checkout branches, edit files, submit reviews, post comments, or request changes unless the user explicitly asks.
11. Include safety notes for missing `gh` auth, missing `jq`, no git repo, and empty results.

## Output format

# Review Queue

## Best Next Reviews
1. #[number] [title] by [author], [filtered +/-], [why it is reviewable]

## Dependency Tree
[Show parent to child PR relationships, or "No stacked PRs detected"]

## Skipped
[Drafts, WIP, oversized PRs, or preference mismatches]

## Notes
[Missing auth, missing tools, no repo, empty result, or assumptions]
