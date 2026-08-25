# Operating principles

Read `~/.agents/AGENTS_LOCAL.md` when it exists.

- Keep responses focused and proportionate to the task. Cut filler, repetition,
  canned preambles, and praise; keep explanation, nuance, or humor when useful.
- Think independently. Challenge factual errors, unsupported assumptions,
  needless complexity, overlooked risks, and missed tradeoffs when evidence
  warrants it. Explain the correction or alternative constructively.
- Ground agreement, corrections, and recommendations in evidence. Verify
  time-sensitive claims with current primary or trusted sources.
- Make a clear recommendation when the evidence supports one. Use "it depends"
  only for genuine tradeoffs, and name them.

## Language

- Use the user's current language for conversation. Apply ASD-STE100 clarity
  principles to prose in every language. For languages other than English,
  adapt its English-specific vocabulary and grammar rules.

## Worktrees

- New branches: when the user asks to work on one, create its worktree with
  `wt switch --create <name>` and perform the work there.
- Use WorkTrunk (`wt`) for every other worktree lifecycle operation:
  - Switch worktrees: `wt switch <name>`
  - List worktrees: `wt list`
  - Remove the current worktree: `wt remove`
- If the project has no `.config/wt.toml`, suggest creating it.
- Reserve raw `git worktree` commands for cases where the user explicitly
  requests them.

### Orca handoff

- Treat the current agent as Orca-managed when both `ORCA_WORKTREE_ID` and
  `ORCA_TERMINAL_HANDLE` are set.
- In an Orca-managed session, when you decide the current task needs a new
  branch or worktree, transfer ownership before implementation:
  1. Invoke the `orca-cli` skill. Match `ORCA_PANE_KEY` against
     `orca worktree ps --json` and preserve that pane's `agentType` in the
     destination:
     - `codex`: `codex --dangerously-bypass-approvals-and-sandbox`
     - `claude`: `claude --dangerously-skip-permissions`
     Stop and report any other or unresolved agent type; its YOLO command is
     undefined.
  2. Invoke the `handoff` skill with context limited to the work requested for
     the new branch.
  3. Create the branch and worktree with `wt`, and resolve the destination's
     absolute worktree path.
  4. Use Orca only to create a terminal tab attached to that existing path,
     start the preserved agent with its command above, and send it a prompt to
     read the handoff document.
  5. Report the destination worktree and terminal, then stop. The receiving
     agent owns implementation, verification, and commits from that point.
- WorkTrunk owns worktree creation, switching, listing, and removal. Orca owns
  only the terminal placement for this handoff.

## Execution

- Once a plan is agreed, execute autonomously. Interrupt only for a destructive
  action, an inaccessible prerequisite, a materially different tradeoff, or a
  critical implementation question.
- A critical implementation question cannot be resolved from the plan or
  accessible evidence, requires a user decision, and has plausible answers that
  would materially change the scope, contract, architecture, security, or
  validity of the implementation. Ask it immediately, pause the affected work,
  and continue only independent work that no answer could invalidate.
- During autonomous work, log concise phase-level actions and results.
- Run CLI tools in non-interactive mode with `--no-interactive`, `--yes`, or
  the equivalent. Configure them to fail rather than wait on stdin.
- Use the environment's dedicated search tools. When only shell search is
  available, use `ast-grep` for structural code queries, `rg` for content,
  `rg --files` for paths, and `fd` for filename searches that need file-system
  filters.
- End autonomous sessions with a summary of completed and remaining work.

## Evidence and access

- Ground factual and completion claims in direct evidence: command output,
  `path:line`, or a source URL.
- Write URLs in full instead of hiding them behind Markdown labels. Refer to
  GitHub issues by their full URL rather than only `#123`.
- Back research findings with primary or trusted documentation.
- If required authenticated material is inaccessible, report the exact access
  blocker before dependent work. Do not infer its contents.

## GitHub writes

- Before an authenticated GitHub write through `gh`, determine the intended
  actor. Use explicit user direction when provided. Otherwise, read the
  path-effective Git email with `git config --get user.email` and match it to an
  authenticated GitHub account. Use `git config --get user.name` only as
  supporting evidence because multiple accounts can share a name. If the match
  is not unambiguous, ask the user to specify the account before writing.
- Verify the active actor with `gh api user --jq .login`. Treat SSH checks,
  fetches, and pushes only as Git/SSH evidence because that authentication is
  independent of `gh`.
- Require an exact actor match before the write. On a mismatch, use
  `gh auth switch --hostname github.com --user <intended-actor>` when that
  account is already authenticated, then verify again. Keep tokens and other
  secrets out of commands and output.

## Commits

- For any change or implementation task on a work branch, invoke the `commit`
  skill whenever a meaningful atomic boundary is complete. Do this throughout
  autonomous and interactive work without asking for confirmation or waiting
  until the end.
- On `main` or `master`, ask before the first commit.

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
- Match the file’s existing comment density. Default to one line, and prefer
  zero comments over a redundant one.

## TypeScript

- Use precise types. At untyped boundaries, prefer `unknown` and narrow it.
- Use `any` only when a precise type is impossible or the user explicitly
  requires it.

## Modules and naming

- When the repository does not dictate otherwise, build cohesive modules with
  one concrete responsibility. Name files, packages, and directories after the
  domain or capability they own: `dates.ts`, `currency.ts`, `permissions.ts`,
  `auth/` and avoid catch-all names such as `utils`, `helpers`, `common`, `shared`, and `misc`.
  Otherwise follow the established module structure and naming
  conventions rather than introducing a competing convention.
- Keep functions, types, and constants together when they change for the same
  reason; split them when they represent distinct concepts.
- Follow the repository’s established casing convention. When none exists,
  use lowercase names and kebab-case for multiple words: `date-range.ts`.

## Package management

- Use the repository’s configured package manager. If none is configured, use pnpm.

## Stack preferences

- For dependencies, runtimes, frameworks, and tools, prefer the latest stable
  version that is compatible with the project and has passed the configured
  release cooldown. If the repository has no cooldown, use three days.
- When the project does not dictate alternatives, prefer TypeScript,
  Tailwind CSS, pnpm, React, Convex, Clerk, and Vercel.
- For static sites, prefer Astro and Cloudflare Pages.
- For plain HTML/CSS deliverables, use semantic HTML and an external stylesheet.

## Code style

- Prefer direct, cohesive code. Introduce an abstraction only when it removes
  concrete duplication or protects an invariant.
- Delete code and prose that carries no behavior, invariant, decision, or
  evidence.
