---
description: Create conventional commit after user confirmation
---

## Context
- Current Branch: !`git branch --show-current`
- Git Status: !`git status`
- Git Diff staged: !`git diff --staged`

## Steps
1. No staged files → ask user to stage
2. Unstaged mods in staged files → ask to add
3. Review changes
4. Generate commit message
   - Use git diff staged
   - Use context if provided: `context: $ARGUMENTS`
   - Follow conventional commits
   - No co-authors
   - Simple changes → 1 Line commit message
   - Complex changes → Add body to commit message
5. Confirm with user:
   - Main branch → warn, confirm proceed or suggest new branch `git switch -c <name>`
   - User approves message → commit

## Notes
- Clear, concise messages
- Ask for additional tools if needed
