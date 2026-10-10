---
name: visual-change-explainer
description: Creates a plain-language visual change brief as an HTML report. Use whenever an audit, review, diagnosis, architecture discussion, or plan recommends non-trivial changes that the user should understand or choose between before implementation, especially when behavior is hidden, tradeoffs exist, or the user asks for simple explanations, concrete examples, diagrams, or animations. Do not interrupt direct implementation requests or expand trivial one-line fixes into reports.
---

# Visual Change Explainer

Turn recommendations into **change stories**. A change story starts with what the
user observes, walks through the current causal sequence, and then shows how the
sequence changes under each credible solution.

The report is an explanation and decision aid. It is not a substitute for
evidence and it does not implement the proposed changes.

## Workflow

### 1. Ground every recommendation

Inspect the relevant files, commands, runtime state, or primary documentation
before explaining a change. Record the smallest concrete scenario that
demonstrates the current behavior.

For each recommendation, identify:

- What the user sees or does.
- The exact current sequence that produces the surprising result.
- The desired result.
- What must change in that sequence.
- What the proposed solution preserves.
- Any unavoidable limit or tradeoff.

Use actual paths, commands, values, and outcomes when available. Label a scenario
as hypothetical when it cannot be verified. Never invent a failure merely to
make a recommendation persuasive.

Completion criterion: every behavioral claim in the report is backed by direct
evidence or explicitly marked as hypothetical.

### 2. Write the simple explanation first

Explain one recommendation per section using this order:

1. **Problem in plain words**: one short paragraph with no unexplained jargon.
2. **Current example**: a numbered, concrete sequence from action to surprising
   result.
3. **Why it happens**: the minimum mechanism needed to make the example make
   sense.
4. **Recommended solution**: a numbered sequence showing the new behavior.
5. **Alternatives**: only real alternatives, each with its consequence and a
   clear recommendation badge.
6. **Summary**: one paragraph stating what changes, what stays, and the remaining
   limitation.
7. **Technical detail**: commands, code, citations, and edge cases in a collapsed
   `details` block.

Use the user's language. Define a necessary technical term on first use, then use
it consistently. Prefer a familiar action and result over module or architecture
vocabulary in the first explanation.

Completion criterion: a reader can understand each section by reading only the
plain-language problem, current example, proposed solution, and summary.

### 3. Make causality visible

Read `assets/report-shell.html` before creating the report. Reuse its visual
language, responsive structure, flow nodes, replay behavior, and reduced-motion
support rather than designing a new shell each time.

Every non-trivial recommendation needs:

- A **before** flow showing the current causal sequence.
- An **after** flow showing where the solution changes that sequence.
- Color that communicates state: red for the surprising/failing outcome, green
  for the corrected outcome, amber for a real limitation.
- A Replay control when the flow is animated.

Animation must reveal causal order. Do not animate decoration. Keep the final
state readable without animation and honor `prefers-reduced-motion`.

Use tables only for true comparisons. Use numbered steps for sequences. Use two
side-by-side cards for current versus proposed behavior. On narrow screens, all
layouts must collapse to one column.

Completion criterion: each visual teaches the same causal story as the prose and
remains understandable in its final static state.

### 4. Preserve the user's constraints

State the user's requirement before changing the mechanism that currently serves
it. Show explicitly how the recommendation preserves that requirement.

When no solution fully preserves it, say so in plain language and show the
closest options. Prefer an honest limitation over a seamless-looking diagram.

Do not hide the recommendation inside neutral alternatives. Mark the best option
as Recommended and explain why. Include alternatives only when a reasonable user
might choose them.

Completion criterion: every stated user preference is either preserved or shown
as an explicit tradeoff.

### 5. Create and open the report

Write a self-contained HTML file to the operating system's temporary directory,
not the repository. Use a unique name such as:

```text
<tmpdir>/change-brief-<topic>-<timestamp>.html
```

Keep CSS and JavaScript in the file. Do not require a build step. External fonts
or UI frameworks are unnecessary; the report must still render offline.

Open it for the user:

- On macOS, prefer Dia when `/Applications/Dia.app` exists:
  `open -b company.thebrowser.dia <path>`.
- Otherwise on macOS, use `open <path>`.
- On Linux, use `xdg-open <path>`.
- On Windows, use `start <path>`.

If desktop inspection is available, verify the first recommendation, one diagram,
and one solution card visually. Also verify that generating the report did not
change repository files.

Completion criterion: the HTML exists, opens successfully, represents every
recommendation, and the user receives its absolute path.

## Scope

Use the full HTML report for recommendations that are non-obvious, have multiple
steps, alter global behavior, or require a user decision. For a single obvious
fix, use the same problem/example/solution structure directly in the response
without creating a report.

When the user directly asks for implementation, implement and verify the work.
Use this skill afterward only when they also ask for an explanation or when a
material unresolved decision blocks safe implementation.

## Final response

State that the visual brief is open, give its absolute path, name the major
decision still needed, and say whether repository files changed. Do not repeat
the report in the response.
