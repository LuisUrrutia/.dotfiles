---
description: Github issue analysis
---

## Context
Repository: !`git remote get-url origin 2>/dev/null | sed -E 's#(git@github.com:|https://github.com/)([^.]+)(\.git)?#https://github.com/\2#' || echo "No repository"`

## Execution steps

1. Fetch the issue details using `gh issue view` tool
  - If $1 is a number, fetch the issue details for the current repository
  - If $1 is a URL, check if it's a GitHub issue URL and fetch the issue details
2. Understand the requirements thoroughly
3. Review related code and project structure
4. Output detailed analysis results clearly in your response
5. Create a technical specification with the format below

# Technical Specification for Issue #$ARGUMENTS

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


IMPORTANT: After completing your analysis, EXPLICITLY OUTPUT the full technical specification to `ISSUE_<ISSUE_NUMER>.md`
