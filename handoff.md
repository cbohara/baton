---
description: Hand off a task to the relay of subagents — spec → red tests → implement → review
argument-hint: <github-issue-number | issue-url | inline spec text>
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Task
---

You run the relay. You take the baton — the task below — and hand it to each
specialist subagent in turn, checking the baton was passed cleanly before the next
runner takes off. You don't run the legs yourself; you make sure each handoff is good.

The task:

$ARGUMENTS

Run the legs below **in order**. Do not skip ahead. The handoffs between legs are
the whole point — if a leg's exit condition isn't met, STOP and report rather than
working around it. A dropped baton ends the relay; it doesn't get quietly picked up.

Read `CLAUDE.md` first for the project's test command, lint command, and
conventions. Everything project-specific lives there; this command stays generic.

## Leg 1 — Spec (spec-writer)
- If the argument is a GitHub issue number or URL, fetch it: `gh issue view <n>`.
- Delegate to the **spec-writer** subagent to turn the input into a concrete
  spec with explicit, testable acceptance criteria and an explicit out-of-scope list.
- If you are running interactively (a human is watching), print the refined spec
  and wait for confirmation before continuing. If running headless (CI / web),
  proceed automatically.

## Leg 2 — Red (test-writer) (this is the most important gate)
- Delegate to the **test-writer** subagent to write tests covering the acceptance
  criteria. Tests only — no implementation.
- Run the project's test command.
- **Confirm the new tests FAIL, and fail for the right reason** (the feature does
  not exist yet), not because of import errors, syntax errors, or typos.
  - If a new test PASSES before any implementation → the test is vacuous. STOP and report.
  - If a new test ERRORS (not a clean assertion failure) → the test is malformed. STOP and report.
- Only a clean, meaningful red proves the tests are real constraints. Do not
  proceed to implementation until you have it.

## Leg 3 — Green (implementer)
- Delegate to the **implementer** subagent to make the failing tests pass.
- It must NOT modify the tests to make them pass. If a test is genuinely wrong,
  surface it for human decision rather than editing it away.
- Run the new tests → confirm green.
- Run the **full** suite → confirm no regressions. If anything else broke, fix it.

## Leg 4 — Review (reviewer) (loop until clean)
- Delegate to the **reviewer** subagent (fresh, adversarial, read-only).
- If it raises blocking issues, hand them back to the **implementer**, then
  re-run leg 3's checks and re-review. Repeat until the reviewer reports no blockers.
- Non-blocking suggestions: note them in the summary, don't gold-plate.

## Anchor leg — Ship
- Open a PR (or, if a branch/PR already exists for this task, push to it):
  `gh pr create` with a body that includes the acceptance criteria, what changed,
  and the reviewer's verdict.
- Print a short summary: criteria met, test status, full-suite status, review verdict,
  and anything left for human judgment.

Throughout: keep changes scoped to this one task. If the task is too large to fit
cleanly (tests sprawl, the diff balloons), STOP and recommend splitting the issue.
