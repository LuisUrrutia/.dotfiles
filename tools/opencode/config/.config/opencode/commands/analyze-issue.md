---
description: Analyze a GitHub issue
---

## Context
Repository: !`git remote get-url origin 2>/dev/null | sed -E 's#(git@github.com:|https://github.com/)([^.]+)(\.git)?#https://github.com/\2#' || echo "No repository"`

## Execution steps

1. Treat `$ARGUMENTS` as one issue number for the current repository or one full GitHub issue URL. If it is missing or invalid, stop and show the accepted forms.
2. Confirm the current directory is inside a Git repository and that `gh auth status` succeeds. Report the exact missing prerequisite instead of guessing issue contents.
3. Fetch the issue with `gh issue view "$ARGUMENTS" --json number,title,body,labels,assignees,state,url`.
4. Read the relevant implementation, tests, project instructions, and related issues or pull requests before proposing a solution.
5. Return the technical specification below in the response. Do not create a file, edit code, or change issue state unless the user explicitly asks.

# Technical Specification for Issue `$ARGUMENTS`

## Issue Summary
- Title: [Issue title from GitHub]
- Description: [Brief description from issue]
- Labels: [Labels from issue]
- Priority: [High/Medium/Low based on issue content]

## Problem Statement
[1-2 paragraphs explaining the problem]

## Technical Approach
[Detailed technical approach]

## Implementation Plan
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Test Plan
1. Unit Tests:
   - [test scenario]
2. Component Tests:
   - [test scenario]
3. Integration Tests:
   - [test scenario]

## Success Criteria
- [ ] [criterion 1]
- [ ] [criterion 2]

## Out of Scope
- [item 1]
- [item 2]
