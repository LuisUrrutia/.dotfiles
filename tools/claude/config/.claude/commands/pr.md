---
allowed-tools: Bash(git log:*), Bash(git diff:*), Bash(gh pr create:*), Bash(git rev-parse --abbrev-ref --symbolic-full-name @{u}), Bash(git push:*), Bash(git rebase:*), Bash(git status:*)
description: Create a pull request for the current branch
---

## Context
- Branch status: !`git branch -vv`
- All commits of the current branch: !`git log origin/main..HEAD --oneline`
- Change statistics: !`git diff origin/main...HEAD --stat -- ':!*lock.json' ':!*lock.yaml' ':!*.lockb' ':!*.lock' ':!.opencode' ':!.claude'`
- Detailed changes: !`git diff origin/main...HEAD -- ':!*lock.json' ':!*lock.yaml' ':!*.lockb' ':!*.lock' ':!.opencode' ':!.claude'`

1. Check the branch status:
  - If the branch has not been pushed (ahead N), push it first `git push -u origin <current-branch>`
  - If the branch is behind the target branch (behind N), rebase it `git pull --rebase origin <target-branch>`
2. Analyze the full set of changes in the current branch
3. Present a PR title and content using the template
  - Fill in all required sections according to @.github/PULL_REQUEST_TEMPLATE.md (if exists)
  - Format:
  ```
  Title: <PR Title>
  
  Description:
  <PR Description>
  ```
4. Confirm with the user if the PR is ready to be created or if he wants to modify the title or description
  - Use `gh pr create` to create the PR
  
**NOTES**:
- Lock files and AI tool folders are excluded from diff/stats above
- You must strictly follow the PR template format (if exists)
- All required sections must be fully completed
- If you need access to additional tools, ask the user to modify the command to include them
