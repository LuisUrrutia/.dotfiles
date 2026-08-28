# Orca-managed session

Orca reads worktrees only after their main repository checkout is registered;
`wt` selects existing branches and creates new branches and worktrees.

## Orca CLI boundaries

- `orca worktree create` and `orca project setup-*` are prohibited.
- `orca repo add` may import only the main checkout resolved by the repository
  preflight below. A linked worktree is never a repo to add.
- When the user explicitly asks to clone a repository into Orca, clone it over
  SSH into `~/Projects/<owner>/<repo>`, then import that main checkout.

## Checkout ownership

The starting agent owns only the checkout path encoded by
`ORCA_WORKTREE_ID`. Any other absolute checkout path is a destination worktree,
including a newly cloned or imported main checkout, an existing branch or pull
request checkout, and a worktree created during the task.

Before handoff, limit destination operations to read-only discovery that
identifies the repository and branch, an explicitly authorized clone, the
repository preflight, Worktrunk destination selection or creation, and the
handoff itself. Changing a command's working directory does not transfer
ownership. Once Orca resolves the destination worktree, launch the receiving
agent there; that agent loads the repository instructions and performs all task
work.

## Repository preflight

Complete this preflight before selecting or creating a destination worktree or
starting its receiving agent, whether the repository is an upstream clone or a
fork:

1. Resolve the main checkout from the first `worktree` entry in
   `git worktree list --porcelain`. Use its canonical absolute path; a linked
   worktree path is not a substitute.
2. Run `orca repo list --json` and compare `repos[].path` with that main
   checkout path.
3. When no exact path match exists, run
   `orca repo add --path <main-worktree-path> --json`. This imports the
   existing checkout; it does not authorize cloning, changing remotes, or
   modifying Git state.
4. Verify the returned or listed repo has the exact main checkout path and
   retain its full repo ID. A missing or mismatched repo is a blocker.

The preflight is complete only when Orca returns the matching main checkout and
its repo ID. Resolve the destination worktree only after that condition holds.

## Handoff

Transfer ownership before task work when either condition holds:

- The implementation checkout differs from the path in `ORCA_WORKTREE_ID`,
  even when the destination is an imported main checkout or already uses the
  requested branch.
- The task needs a new branch or worktree in the starting repository.

Complete the handoff as follows:

1. Invoke the `orca-cli` skill. Match `ORCA_PANE_KEY` against
   `orca worktree ps --json` and preserve that pane's `agentType` in the
   destination:
   - `codex`: `codex --dangerously-bypass-approvals-and-sandbox`
   - `claude`: `claude --dangerously-skip-permissions`
   Any other or unresolved agent type is a blocker: its YOLO command is
   undefined.
2. Complete the repository preflight and retain the matching repo ID.
3. Write the handoff document as the `handoff` skill describes
   (`~/.agents/skills/handoff/SKILL.md`), with context limited to the work
   requested for the destination worktree.
4. Resolve the destination's absolute path with the matching Worktrunk branch:
   - Already checked out: use that checkout's canonical absolute path.
   - Existing branch: run `wt switch <branch>`.
   - Existing pull request: run `wt switch pr:<number>` or pass its URL.
   - New branch: run `wt switch --create <name>`.
5. Orca discovers that worktree under the registered repo with a delay. Wait for
   it: poll `orca worktree show --worktree path:<abs-path> --json` every few
   seconds until it resolves, for up to two minutes. `selector_not_found`
   during that window means keep waiting; after it, that is a blocker.
6. Run `orca terminal create --worktree path:<abs-path> --command "<agent
   command>" --json`, wait for `tui-idle`, and send a prompt to read the
   handoff document.
7. Report the destination worktree and terminal, then stop. The receiving agent
   owns repository inspection, implementation, verification, commits, and PR
   work.

The handoff is complete only when the receiving agent has started in the
destination worktree and received the handoff document. Until then, the
starting agent performs only the setup operations allowed under Checkout
ownership. On a blocker, stop before task work; implementation waits for a
completed handoff, and the starting agent never implements as a fallback.
