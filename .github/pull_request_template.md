<!-- Use a Conventional Commit title, for example: fix(fish): preserve caller-provided pager -->

## Why

<!-- Explain the problem or goal. Link the full issue URL when one exists. -->

## What changed

<!-- Describe the smallest reviewable set of changes in this PR. -->

## Verification

<!-- Include exact commands and outcomes. State why any applicable check was skipped. -->

| Check | Command | Result |
| --- | --- | --- |
| Targeted behavior |  |  |
| Syntax or static analysis |  |  |
| Broader smoke path |  |  |
| Final diff | `git diff --check` |  |

## Risk and recovery

<!-- Describe user-state impact, failure modes, and how to recover. Write "None" when not applicable. -->

## Checklist

- [ ] I reviewed the final diff for unintended changes.
- [ ] I did not include secrets, credentials, private keys, licenses, sessions, logs, caches, or databases.
- [ ] I preserved existing user state or made destructive intent explicit.
- [ ] I updated user-facing documentation when behavior changed.
- [ ] I ran the applicable repository-specific checks below, or explained why they do not apply:
  - Bootstrap or Profile Install: relevant macOS Bash 3.2 `install.sh --dry-run` modes.
  - Stowed Config: every package restowed into a temporary home with `--no-folding`.
  - Machine or Git: secret scanning and the Git-specific validation commands from `AGENTS.md`.
