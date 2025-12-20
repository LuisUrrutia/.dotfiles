---
allowed-tools: Bash(git log:*), Bash(git diff:*), Bash(gh pr create:*), Bash(git rev-parse --abbrev-ref --symbolic-full-name @{u}), Bash(git push:*), Bash(git rebase:*), Bash(git status:*)
description: Create a pull request for the current branch
---

## Context
- Branch status: !`git branch -vv`
- All commits of the current branch: !`git log <target-branch>..HEAD --oneline`
- Change statistics: !`git diff <target-branch>...HEAD --stat`
- Detailed changes: !`git diff <target-branch>...HEAD`

2. Analyze the full set of changes in the current branch
3. Check the branch status:
  - If the branch has not been pushed (ahead N), push it first `git push -u origin <current-branch>`
  - If the branch is behind the target branch (behind N), rebase it `git pull --rebase origin <target-branch>`
5. Create the PR using the template
  - Fill in all sections according to @.github/PULL_REQUEST_TEMPLATE.md (if exists)
  - Use `gh pr create` to create the PR
  
**NOTES**:
- You must strictly follow the PR template format (if exists)
- All required sections must be fully completed
- If you need access to additional tools, ask the user to modify the command to include them
