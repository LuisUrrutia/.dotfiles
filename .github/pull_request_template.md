<!-- Use a Conventional Commit title, for example: fix(fish): preserve caller-provided pager -->

## Why

<!-- Explain the problem or goal. Link the full issue URL when one exists. -->

## What changed

<!-- Describe the smallest reviewable set of changes in this PR. -->

## Verification

<!-- Include exact commands and outcomes, plus the OS/architecture for platform changes.
Separate repository checks from package, service, GUI, and preference-restore acceptance.
State why any applicable check was skipped. -->

| Check                   | Command            | Result |
| ----------------------- | ------------------ | ------ |
| Targeted behavior       |                    |        |
| Repository verification | `mise run verify`  |        |
| Broader smoke path      |                    |        |
| Final diff              | `git diff --check` |        |

## Risk and recovery

<!-- Describe user-state impact, failure modes, and how to recover. Write "None" when not applicable. -->

## Checklist

- [ ] I reviewed the final diff for unintended changes.
- [ ] I did not include secrets, credentials, private keys, licenses, sessions, logs, caches, or databases.
- [ ] I preserved existing user state or made destructive intent explicit.
- [ ] I updated user-facing documentation when behavior changed.
- [ ] I ran `mise run verify`, including isolated deployment/history and Git identity checks.
- [ ] I checked affected macOS arm64 and Ubuntu arm64/x86_64 paths, or recorded the untested platforms.
- [ ] I distinguished repository checks from any unexecuted fresh-machine or application restore acceptance.
