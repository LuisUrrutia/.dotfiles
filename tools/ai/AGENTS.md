# Operating principles

- Begin with substance: an answer, evidence, correction, or next action. Omit
  praise and social validation.
- Be decisive: make a clear recommendation when the evidence supports one.
  Use “it depends” only for genuine tradeoffs, and name them.
- Challenge harmful or needlessly complex plans directly, then offer the
  safer or simpler alternative.
- Keep replies as short as the task allows.

## Worktrees

- Use WorkTrunk (`wt`) for the worktree lifecycle:
  - Create a worktree and branch: `wt switch --create <name>`
  - Switch worktrees: `wt switch <name>`
  - List worktrees: `wt list`
  - Remove the current worktree: `wt remove`
- Reserve raw `git worktree` commands for cases where the user explicitly
  requests them.

## Execution

- Once a plan is agreed, execute autonomously. Interrupt only for a destructive
  action, an inaccessible prerequisite, or a materially different tradeoff.
- During autonomous work, log concise phase-level actions and results.
- Run CLI tools in non-interactive mode with `--no-interactive`, `--yes`, or
  the equivalent. Configure them to fail rather than wait on stdin.
- Use the environment’s dedicated search tools. When only shell search is
  available, use `rg` for content and `rg --files` for paths.
- End autonomous sessions with a summary of completed and remaining work.

## Evidence and access

- Ground factual and completion claims in direct evidence: command output,
  `path:line`, or a source URL.
- Write URLs in full instead of hiding them behind Markdown labels. Refer to
  GitHub issues by their full URL rather than only `#123`.
- Back research findings with primary or trusted documentation.
- When sources help a pull request reviewer, add a **References** bullet list
  with full URLs at the end of the PR body, before Linear magic words.
- If required authenticated material is inaccessible, report the exact access
  blocker before dependent work. Do not infer its contents.

## Commit safety

- Before committing, inspect staged files and exclude secrets, machine state,
  histories, caches, sessions, logs, and SQLite databases.

## Verification

- After each implementation, run all applicable checks:
  1. The narrowest behavioral test for the changed behavior.
  2. The project’s compile or build command.
  3. A broader smoke path outside the changed feature.
- Report the exact commands and outcomes before declaring completion. If a
  check is unavailable, name the exact blocker.
- After a runnable feature, provide exactly two copy-pasteable shell commands:
  1. **Fresh:** tear down generated state, then start the system.
  2. **Quick:** start the system assuming the current state is clean.
  Put each command in its own fenced block, one command per block, with no
  placeholders.

## Tests

- Structure behavioral tests as Arrange, Act, and Assert. Add phase comments
  only when spacing and naming do not make the boundaries obvious.
- Prefer real collaborators or lightweight fakes. Extensive mocking indicates
  a boundary that should be redesigned.
- Fix the production code when a test needs a workaround. Change the test only
  when its asserted contract is wrong.

## Comments

- Comments capture only a non-obvious why, invariant, external constraint, or
  gotcha. Never narrate what code, JSX, or layout does.
- Make code self-documenting through precise names and simple structure.
  Refactor unclear code instead of explaining it with comments.
- Delete commented-out code.
- Match the file’s existing comment density. Default to one line, and prefer
  zero comments over a redundant one.

## TypeScript

- Use precise types. At untyped boundaries, prefer `unknown` and narrow it.
- Use `any` only when a precise type is impossible or the user explicitly
  requires it.

## Modules and naming

- Build cohesive modules with one concrete responsibility. Name files,
  packages, and directories after the domain or capability they own:
  `dates.ts`, `currency.ts`, `permissions.ts`, `auth/`.
- Catch-all names such as `utils`, `helpers`, `common`, `shared`, and `misc`
  are forbidden. Place each export in the concrete module that owns it.
- Keep functions, types, and constants together when they change for the same
  reason; split them when they represent distinct concepts.
- Follow the repository’s established casing convention. When none exists,
  use lowercase names and kebab-case for multiple words: `date-range.ts`.

## Package management

- Use the repository’s configured package manager. If none is configured, use pnpm.

## Stack preferences

- When the project does not dictate alternatives, prefer TypeScript,
  Tailwind CSS, pnpm, React, Convex, Clerk, and Vercel.
- For static sites, prefer Astro and Cloudflare Pages.
- For plain HTML/CSS deliverables, use semantic HTML and an external stylesheet.

## Code style

- Prefer direct, cohesive code. Introduce an abstraction only when it removes
  concrete duplication or protects an invariant.
- Delete code and prose that carries no behavior, invariant, decision, or
  evidence.
