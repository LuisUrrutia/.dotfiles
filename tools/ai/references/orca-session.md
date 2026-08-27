# Orca-managed session

Orca reads worktrees only after their main repository checkout is registered;
`wt` creates every branch and worktree.

## Orca CLI boundaries

- `orca worktree create` and `orca project setup-*` are prohibited.
- `orca repo add` may import only the main checkout resolved by the repository
  preflight below. A linked worktree is never a repo to add.
- When the user explicitly asks to clone a repository into Orca, clone it over
  SSH into `~/Projects/<owner>/<repo>`, then import that main checkout.

## Repository preflight

Complete this preflight before creating a branch or worktree, whether the
repository is an upstream clone or a fork:

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
its repo ID. Create or inspect linked worktrees only after that condition holds.

## Handoff

When the task needs a new branch or worktree, transfer ownership before any
implementation:

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
   requested for the new branch.
4. Create the branch and worktree with `wt switch --create <name>` and resolve
   the destination's absolute path.
5. Orca discovers that worktree under the registered repo with a delay. Wait for
   it: poll `orca worktree show --worktree path:<abs-path> --json` every few
   seconds until it resolves, for up to two minutes. `selector_not_found`
   during that window means keep waiting; after it, that is a blocker.
6. Run `orca terminal create --worktree path:<abs-path> --command "<agent
   command>" --json`, wait for `tui-idle`, and send a prompt to read the
   handoff document.
7. Report the destination worktree and terminal, then stop. The receiving agent
   owns implementation, verification, and commits.

The handoff is complete only when the receiving agent has started in the
destination worktree and received the handoff document. On a blocker, stop
before creating the branch or worktree or editing files; implementation waits
for a completed handoff, and the current agent never implements as a fallback.
