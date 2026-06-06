# Project context

This project uses a disciplined build loop: **spec → red tests → implement → review**.
The pipeline (in `.claude/`) is generic; everything project-specific goes here so the
agents stay reusable across repos.

## Commands
<!-- Fill these in per project. The pipeline reads them from here. -->
- Test command: `<e.g. pytest -q>`
- Run a single test: `<e.g. pytest path::test_name>`
- Lint / format: `<e.g. ruff check . && ruff format .>`
- Dev server (for integration review): `<e.g. npm run dev — serves on http://localhost:3000>`

## The loop (non-negotiable gates)
1. **Spec** — concrete, testable acceptance criteria before anything else.
2. **Red** — tests written first must FAIL meaningfully before implementation.
   A test that passes before the feature exists is a bug in the test.
3. **Green** — implement the minimum to pass; never edit tests to make them pass;
   the full suite must stay green (no regressions).
4. **Review** — a separate, adversarial pass before the PR. Loop until no blockers.

## Conventions
<!-- Project-specific patterns the agents should follow. Keep this short and real. -->
- <e.g. Use the existing `Result` type for fallible operations.>
- <e.g. Tests live in `tests/`, mirror the source tree.>
- <e.g. No new dependencies without flagging it.>
