# Operating principles

Read `~/.agents/AGENTS_LOCAL.md` (machine-local rules) when it exists.

- Global rule requests: edit `~/.dotfiles/tools/ai/AGENTS.md`, the tracked
  source of this file. `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` only
  import it.
- Keep responses focused and proportionate to the task. Cut filler, repetition,
  canned preambles, and praise; keep explanation, nuance, or humor when useful.
- Think independently. Challenge factual errors, unsupported assumptions,
  needless complexity, overlooked risks, and missed tradeoffs when evidence
  warrants it, and explain the correction constructively.
- Ground agreement, corrections, and recommendations in evidence. Verify
  time-sensitive claims with current primary or trusted sources.
- Make a clear recommendation when the evidence supports one. Use "it depends"
  only for genuine tradeoffs, and name them.

## Repository references

Read a file under `~/.agents/references/` only when its rule in this section
fires; the rule names the trigger.

- Orca: when the workspace root is named `orca` or `orca.*`, or the supplied
  task context identifies `stablyai/orca` or one of its forks, read and follow
  `~/.agents/references/orca.md` for the entire task.

## Language

- Use the user's current language for conversation. Apply ASD-STE100 clarity
  principles to prose in every language; for languages other than English,
  adapt its English-specific vocabulary and grammar rules.

## Execution

- Once a plan is agreed, execute autonomously. Interrupt only for a destructive
  action, a blocker, a materially different tradeoff, or a critical
  implementation question.
- A blocker is a prerequisite that is inaccessible or prohibited. Stop the work
  that depends on it, continue the independent work, and report the exact
  blocker. Treat the material behind it as unknown.
- A critical implementation question cannot be resolved from the plan or
  accessible evidence, requires a user decision, and has plausible answers that
  would materially change the scope, contract, architecture, security, or
  validity of the implementation. Ask it immediately, pause the affected work,
  and continue only independent work that no answer could invalidate.
- Log concise phase-level actions and results during autonomous work, and end
  with a summary of completed and remaining work.
- Run CLI tools non-interactively (`--no-interactive`, `--yes`, or the
  equivalent), configured to fail rather than wait on stdin.
- Use the environment's dedicated search tools. When only shell search is
  available: `ast-grep` for structural code queries, `rg` for content,
  `rg --files` for paths, and `fd` for filename searches that need file-system
  filters.

## Worktrees

- When the user asks to work on a new branch, create its worktree with
  `wt switch --create <name>` and work there.
- WorkTrunk (`wt`) owns every other worktree lifecycle operation; invoke the
  `worktrunk` skill for its commands. If the project has no `.config/wt.toml`,
  suggest creating it. Use raw `git worktree` only when the user explicitly
  asks for it.
- Orca reads worktrees and places terminals; `wt` creates every branch and
  worktree. `orca worktree create` and `orca project setup-*` are prohibited.
- `orca repo add` is reserved for a user's explicit request to clone a repo
  into Orca. Clone `<owner>/<repo>` over SSH into `~/Projects/<owner>/<repo>`,
  creating `~/Projects/<owner>/` when missing, then run
  `orca repo add --path ~/Projects/<owner>/<repo> --json`. A worktree is
  never a repo to add.

### Orca handoff

The session is Orca-managed when both `ORCA_WORKTREE_ID` and
`ORCA_TERMINAL_HANDLE` are set. In an Orca-managed session, when the task needs
a new branch or worktree, transfer ownership before any implementation:

1. Invoke the `orca-cli` skill. Match `ORCA_PANE_KEY` against
   `orca worktree ps --json` and preserve that pane's `agentType` in the
   destination:
   - `codex`: `codex --dangerously-bypass-approvals-and-sandbox`
   - `claude`: `claude --dangerously-skip-permissions`
   Any other or unresolved agent type is a blocker: its YOLO command is
   undefined.
2. Write the handoff document as the `handoff` skill describes
   (`~/.agents/skills/handoff/SKILL.md`), with context limited to the work
   requested for the new branch.
3. Create the branch and worktree with `wt switch --create <name>` and resolve
   the destination's absolute path.
4. Orca discovers that worktree under the current repo with a delay. Wait for
   it: poll `orca worktree show --worktree path:<abs-path> --json` every few
   seconds until it resolves, for up to two minutes. `selector_not_found`
   during that window means keep waiting; after it, that is a blocker.
5. Run `orca terminal create --worktree path:<abs-path> --command "<agent
   command>" --json`, wait for `tui-idle`, and send a prompt to read the
   handoff document.
6. Report the destination worktree and terminal, then stop. The receiving agent
   owns implementation, verification, and commits.

The handoff is complete only when the receiving agent has started in the
destination worktree and received the handoff document. On a blocker, stop
before creating the branch or worktree or editing files; implementation waits
for a completed handoff, and the current agent never implements as a fallback.

## Evidence

- Ground factual and completion claims in direct evidence: command output,
  `path:line`, or a source URL.
- Write URLs in full as plain text rather than behind Markdown labels, GitHub
  issues included (`https://github.com/<owner>/<repo>/issues/123`, not `#123`).
- Back research findings with primary or trusted documentation.

## Git transport

- Use SSH for every Git network operation: clone, fetch, pull, push, and
  submodules. HTTPS remotes are prohibited, including as a fallback.
- If SSH fails, diagnose and repair the SSH path; when the available access
  cannot restore it, that is a blocker.

## GitHub writes

Before an authenticated GitHub write through `gh`:

1. Determine the intended actor: explicit user direction, or else the
   path-effective `git config --get user.email` matched to an authenticated
   GitHub account. `git config --get user.name` is only supporting evidence
   because accounts can share a name. If the match is ambiguous, ask the user
   for the account.
2. Verify the active actor with `gh api user --jq .login`. SSH checks, fetches,
   and pushes prove only Git/SSH authentication, which is independent of `gh`.
3. Require an exact match. On a mismatch, run
   `gh auth switch --hostname github.com --user <intended-actor>` when that
   account is already authenticated, then verify again.

Keep tokens and other secrets out of commands and output.

## Commits

- On a work branch, invoke the `commit` skill at every completed atomic
  boundary, throughout autonomous and interactive work, without asking.
- On `main` or `master`, ask before the first commit.

## Pull requests

- Update an existing PR branch from its base with rebase rather than a merge
  commit.
- Publishing that rebase with `git push --force-with-lease` (lease form only)
  is pre-authorized. Immediately before pushing, verify the current branch,
  exact PR head, push remote, and expected remote tip.

## Verification

- After each implementation, run all applicable checks:
  1. The narrowest behavioral test for the changed behavior.
  2. The project's compile or build command.
  3. A broader smoke path outside the changed feature.
- Report the exact commands and outcomes before declaring completion. An
  unavailable check is a blocker.
- After a runnable feature, provide exactly two copy-pasteable shell commands,
  each in its own fenced block with no placeholders:
  1. **Fresh:** tear down generated state, then start the system.
  2. **Quick:** start the system assuming the current state is clean.

## Tests

- Structure behavioral tests as Arrange, Act, and Assert. Add phase comments
  only when spacing and naming do not make the boundaries obvious.
- Prefer real collaborators or lightweight fakes. Extensive mocking indicates
  a boundary that should be redesigned.
- Fix the production code when a test needs a workaround. Change the test only
  when its asserted contract is wrong.

## Comments

- A comment captures only a non-obvious why, invariant, external constraint, or
  gotcha; code, JSX, and layout explain themselves through precise names and
  simple structure. Refactor unclear code instead of commenting it.
- Match the file's existing comment density. Default to one line, and prefer
  zero comments over a redundant one.

## TypeScript

- Use precise types. At untyped boundaries, prefer `unknown` and narrow it.
- Use `any` only when a precise type is impossible or the user explicitly
  requires it.

## Modules and naming

- Follow the repository's established module structure, naming, and casing
  conventions. Where none exist: build cohesive modules with one concrete
  responsibility, named after the domain or capability they own (`dates.ts`,
  `currency.ts`, `permissions.ts`, `auth/`) rather than catch-alls such as
  `utils`, `helpers`, `common`, `shared`, or `misc`; use lowercase names with
  kebab-case for multiple words (`date-range.ts`).
- Keep functions, types, and constants together when they change for the same
  reason; split them when they represent distinct concepts.

## Stack preferences

- Use the repository's configured package manager; otherwise pnpm.
- For dependencies, runtimes, frameworks, and tools, prefer the latest stable
  version compatible with the project that has passed the configured release
  cooldown (three days when the repository sets none).
- When the project does not dictate alternatives, prefer TypeScript,
  Tailwind CSS, React, Convex, Clerk, and Vercel; for static sites, Astro and
  Cloudflare Pages.
- For plain HTML/CSS deliverables, use semantic HTML and an external stylesheet.

## Code style

- Prefer direct, cohesive code. Introduce an abstraction only when it removes
  concrete duplication or protects an invariant.
- Delete code and prose that carries no behavior, invariant, decision, or
  evidence.
