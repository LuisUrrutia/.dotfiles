---
description: Routes agent work through Superpowers and Matt skills for disciplined execution
---

# SAIZEN Workflow

Use Superpowers as the execution spine. Use Matt skills as overlays for domain language, PRDs, issues, architecture, and diagnosis.

## Global Rules

- Highest priority before any work: read the applicable `AGENTS.md` instructions, then check for `CONTEXT-MAP.md`; if it exists, use it to find and read the relevant `CONTEXT.md` files, otherwise read the root or nearest `CONTEXT.md` before acting.
- Check skills before acting.
- If `brainstorming` applies, invoke `brainstorming` and `grill-with-docs` together as a paired intake.
- Shape brainstorming questions like `grill-with-docs`: inspect repo/docs first when possible, analyze the decision, ask one question at a time, and include a recommended answer plus options when useful.
- Do not ask "approve?" or add approval gates just because `brainstorming` asks for them. Continue unless the user explicitly requests approval checkpoints.
- If `brainstorming` offers the visual companion and the user accepts, invoke `prototype` to create, compare, or improve the visual artifact.
- If the answer is in the repo, inspect the repo instead of asking.
- Keep domain language in `CONTEXT.md`.
- Verify before claiming success.
- When creating tests, make them comprehensive for behavior and requirements that matter: contracts, edge cases, accessibility, regressions, data handling, and failure modes. Do not test incidental implementation details or low-value details just because they changed; styling specifics like padding are only worth testing when they are product requirements.
- Never commit, push, or open a PR unless requested.

## Router

| User request | Workflow |
| --- | --- |
| New feature/change | `brainstorming` + `grill-with-docs` paired intake -> `writing-plans` -> `using-git-worktrees` if needed -> `tdd`/`test-driven-development` -> `requesting-code-review` -> `verification-before-completion` |
| Existing plan/spec/PRD | `brainstorming` + `grill-with-docs` paired intake -> `to-prd` or `to-issues` if tracker work is needed -> `writing-plans` -> execution spine |
| Bug/failure/regression | `diagnose` or `systematic-debugging` -> reproduce -> minimize -> regression test -> fix -> `verification-before-completion` |
| Architecture/refactor | `zoom-out` if unfamiliar -> `improve-codebase-architecture` -> `grill-with-docs` if terms/boundaries change -> `writing-plans` -> tests -> review/verify |
| Issues/PRD/triage | `setup-matt-pocock-skills` if needed -> `triage`, `to-prd`, or `to-issues` -> `writing-plans` only if executing |
| Visual/interaction planning | `brainstorming` + `grill-with-docs` paired intake -> `prototype` for visual iterations -> `writing-plans` if implementing |
| Prototype | `prototype` -> `brainstorming` + `grill-with-docs` paired intake if fuzzy or domain assumptions need testing |
| Skill authoring | `write-a-skill` or `writing-skills` -> define triggers/use cases -> draft concise skill -> review |
| Commit/PR | verify -> review if non-trivial -> `commit` or `pr` only on request |

## Conflict Rules

- User instructions win.
- Safety and repo rules win over speed.
- Superpowers owns implementation lifecycle.
- Matt skills own domain alignment, issue/PRD workflow, architecture review, and diagnosis.
- For new changes and existing plans, start with `brainstorming` and `grill-with-docs` together.
