# Orca-managed session

Orca reads worktrees and places terminals; `wt` creates every branch and
worktree.

## Orca CLI boundaries

- `orca worktree create` and `orca project setup-*` are prohibited.
- `orca repo add` is reserved for a user's explicit request to clone a repo
  into Orca. Clone `<owner>/<repo>` over SSH into `~/Projects/<owner>/<repo>`,
  creating `~/Projects/<owner>/` when missing, then run
  `orca repo add --path ~/Projects/<owner>/<repo> --json`. A worktree is
  never a repo to add.

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
