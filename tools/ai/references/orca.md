# Orca Counterexample Pass

For every behavioral change, work in two passes:

1. **Delivery:** implement the requested behavior.
2. **Counterexample:** assume the happy path works and try to falsify the
   solution through reachable states.

Scale the counterexample pass to the change. A rename needs a quick check. A
change involving shared state, async work, caches, persistence, identity,
events, external processes, networks, platforms, versions, permissions, or
security requires the full review below.

## Contract

Before implementation, state:

- the externally observable behavior that must become true;
- the existing behavior that must remain unchanged;
- the source of truth for the affected state;
- the explicit non-goals.

A solution is incomplete while any requirement or preserved behavior lacks a
code path and verification method.

## Existing system

Trace the current path before adding logic:

- entry point;
- producers and consumers;
- state owner;
- identifiers used across boundaries;
- caches and in-flight work;
- retries, cleanup, and lifecycle;
- existing implementations that already perform part of the job.

Extend the existing path when it owns the behavior. Adding a second producer
requires proof that the two paths cannot duplicate, reorder, or contradict each
other.

## Risk axes

Evaluate each applicable axis. Mark an axis N/A only when the code makes it
unreachable.

- **Multiplicity:** zero, one, many, duplicates, collisions.
- **Time:** before, during, after, concurrent, delayed, stale.
- **Failure:** exception, timeout, cancellation, partial success, retry.
- **Identity:** missing, ambiguous, reused, conflicting, wrong owner.
- **Topology:** local, remote, headless, disconnected, reconnected, multiple
  clients or workers.
- **Evolution:** old and new versions, migrations, rollout, rollback.
- **Platform:** supported operating systems, path rules, process behavior.
- **Cost:** CPU, battery, network, disk, subprocesses, wakeups, cleanup.

Do not invent hypothetical states. Derive counterexamples from reachable code
paths, persisted data, supported configurations, or documented compatibility
requirements.

## Freshness and concurrency

For changes that invalidate, refresh, retry, or cache state, trace both
completed and in-flight operations.

Invalidating stored data does not prove that an operation already in flight
cannot return stale data. Account for the operation owner, joined callers,
writeback, retries, and repeated invalidation.

For event-driven work, prove ordering, idempotence, coalescing, and exactly-once
or at-least-once behavior as required by the contract.

## End-to-end path

Verify through the real entry point, not only through the new function or seam.

Trace:

`trigger -> authority -> mutation -> invalidation -> publication -> consumer -> observable result`

A unit test of the seam is supplementary. At least one test must exercise the
real path that caused the reported behavior.

## Compatibility and cost

Evaluate compatibility in both directions whenever components update
independently.

Prefer an existing compatible mechanism when it expresses the behavior. A
fallback that adds recurring work must justify its CPU, battery, network, disk,
and subprocess cost, plus the condition for removing it.

## Verification

Every non-trivial behavior change needs:

- a focused test that fails before the fix;
- a negative or ambiguous case derived from the risk axes;
- a regression test for an existing neighboring path that must remain
  unchanged;
- the project's typecheck or build;
- a broader smoke path outside the changed feature.

Integration tests prove internal boundaries and concurrency. End-to-end tests
finish with a user-observable assertion. Each test must prove a distinct failure
mode.

## Independent review

Before completion, review the final diff separately from implementation.

Ask:

- Which assumption is true only in the test setup?
- Which state can outlive the invalidation or owner?
- Which identifier can collide or lose its authority?
- Which operation can execute twice, finish late, or partially succeed?
- Which existing producer or consumer can duplicate the new behavior?
- Which supported topology or version pairing changes the result?
- Which recurring work continues while the feature is idle?
- Does the test prove the user outcome or only an internal detail?

Absence of findings is acceptable only after every applicable risk axis is
accounted for.

## Completion gate

Completion requires:

- every contract requirement mapped to code and evidence;
- every applicable risk axis covered by behavior, a test, or a documented
  non-applicability;
- no stale, ambiguous, duplicated, or ownerless path left unexplained;
- exact verification commands and outcomes reported.
