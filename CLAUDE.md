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

## Ship mode (how the Anchor leg lands the work)
- Ship mode: `<auto-merge | pr | merge>` — default `auto-merge`.
  - `auto-merge` — open a PR (the artifact), enable GitHub auto-merge, let CI (`pr-checks.yml`)
    merge it the moment checks pass. Momentum without losing the independent gate. Needs branch
    protection requiring `pr-checks`; if that gate isn't present, it falls back to a plain PR and says so.
  - `pr` — open a PR and stop (a human merges). Use when you want eyes on every diff.
  - `merge` — merge immediately, no waiting on CI. Throwaway/solo repos only: the in-session
    reviewer is then your ONLY gate (the code's author grading its own work).

## Testing gates (toggle per project — enable only what fits)
- Property-based testing: `<on | off>` — tool: `<e.g. Hypothesis>`
- Browser QA (qa-browser leg): `<on | off>` — requires the Playwright MCP server
- Visual regression: `<on | off>` — `<e.g. npx playwright test --update-snapshots to set baseline>`

## Web app commands (only if this is a web app)
- Dev server start: `<e.g. npm run dev>` serving at `<http://localhost:3000>`
- E2E / browser test command: `<e.g. npx playwright test>`
- Visual snapshot dir: `<e.g. tests/__snapshots__>`

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
