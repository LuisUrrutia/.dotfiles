---
description: Create a pull request for the current branch
---

## Context
- Branch: !`git branch -vv`
- Commits: !`git log origin/main..HEAD --oneline`
- Stats: !`git diff origin/main...HEAD --stat`
- Diff: !`git diff origin/main...HEAD`

1. Check branch:
  - Not pushed (ahead N)? Push: `git push -u origin <branch>`
  - Behind? Rebase: `git pull --rebase origin <target>`
2. Analyze all changes
3. Draft PR (follow @.github/PULL_REQUEST_TEMPLATE.md if exists):
  ```
  Title: <title>

  Description:
  <body>
  ```
4. Confirm before creating with `gh pr create`

**NOTES**:
- Follow PR template strictly (if exists)
- Complete all required sections
- Ask if additional tools needed
