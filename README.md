# relay

A portable spec → red-tests → implement → review loop for Claude Code. You hand off a
task and the relay of subagents runs it leg by leg, checking each baton pass before the
next runner takes off. The same files run locally, in CI (`claude-code-action`), or on
Claude Code on the web — unchanged.

```
.claude/
  commands/handoff.md     # the relay starter — /handoff
  agents/
    spec-writer.md        # leg 1: spec → testable acceptance criteria
    test-writer.md         # leg 2: writes failing tests (Red) — example/property/visual
    implementer.md         # leg 3: makes them pass, no test edits (Green)
    reviewer.md            # legs 4 & 6: mutation-test the tests, then adversarial review
    qa-browser.md          # leg 5: verifies the running app in a real browser (Playwright MCP)
  settings.json            # permission defaults
CLAUDE.md                  # per-project commands, gate toggles & conventions (fill this in)
ci-templates/              # inert GitHub Actions templates — copy into a project's .github/workflows/
  relay.yml                # issue labelled `relay` → runs the relay in CI, opens a PR
  pr-checks.yml            # on PR: full suite + browser e2e/visual (the independent gate)
  mutation.yml             # opt-in (label/manual): mutation testing
```

## Use it in one project (per-repo)

1. Copy `.claude/` and `CLAUDE.md` into the repo root.
2. Fill in the commands/conventions in `CLAUDE.md`.
3. In a Claude Code session: `/handoff <issue-number | spec text>`.

## Use it everywhere (global) — the symlink pattern

Claude Code reads config from two scopes: the project (`./.claude/`) and the user
(`~/.claude/`). Anything in `~/.claude/agents/` and `~/.claude/commands/` is available
in **every** repo — the same trick as symlinking into your opencode config dir.

Keep this repo as the single source of truth and symlink it into the user scope:

```sh
# from this repo's root
mkdir -p ~/.claude/{agents,commands}
ln -s "$PWD/.claude/commands/handoff.md"    ~/.claude/commands/handoff.md
ln -s "$PWD/.claude/agents/spec-writer.md" ~/.claude/agents/spec-writer.md
ln -s "$PWD/.claude/agents/test-writer.md"  ~/.claude/agents/test-writer.md
ln -s "$PWD/.claude/agents/implementer.md"  ~/.claude/agents/implementer.md
ln -s "$PWD/.claude/agents/reviewer.md"     ~/.claude/agents/reviewer.md
ln -s "$PWD/.claude/agents/qa-browser.md"   ~/.claude/agents/qa-browser.md
```

(Symlink individual files, not the whole dir, so this merges with anything already
in `~/.claude/` instead of clobbering it.)

Now `/handoff` and the four agents work in any repo. **Per-project specifics stay in each
repo's own `CLAUDE.md`** — that's the split: generic relay behavior is global and version-
controlled here; the test command, conventions, and dev-server URL live per-repo. A
project's local `.claude/` also composes with the global one, so you can override or add
per-repo when you want.

## Note on global CLAUDE.md
`~/.claude/CLAUDE.md` loads in every project too. Keep only truly universal preferences
there (e.g. "always run the linter before finishing"). Anything project-shaped belongs in
the repo's CLAUDE.md, or it will leak into unrelated work.

## Deeper testing — two tiers
The relay supports four heavier techniques, toggled per project in `CLAUDE.md` under
"Testing gates." They split across two tiers by cost and environment:

**In-session (cheap, runs inside the relay):**
- **Property-based** (Hypothesis): the test-writer writes invariant tests that generate
  hundreds of inputs. Best for parsers, serializers, math, anything with a clear invariant.
- **Mutation testing** (mutmut / Stryker): the reviewer breaks the code on purpose to check
  the tests catch it. Surviving mutants = weak tests = a blocker. This is how you trust tests
  without reading them. It's slow, so enable it where test quality matters most, or move it to CI.

**Better as separate PR-triggered CI checks (expensive, environment-specific):**
- **Browser QA** (qa-browser, via the Playwright MCP server): drives the running app against
  each acceptance criterion, screenshots the result, posts a PASS/FAIL report to the PR.
- **Visual regression** (Playwright snapshots / Percy / Chromatic): screenshot-diffs the UI and
  flags unintended changes.

Why the second tier is better in CI: those gates need a browser and a running app, they take
real time, and — like your test suite — they're the *independent* checks the agent can't
self-report its way past. Run them in-session for thorough local passes; wire them as their own
workflows on the PR for hands-off autonomy. Templates for both tiers are in `ci-templates/`.

**Playwright MCP setup** (once, for browser QA): `claude mcp add playwright npx @playwright/mcp@latest`.

A backend library enables only property-based + mutation; a web app turns the rest on too. Keep a
project lean — enable only what fits.

## CI templates
`ci-templates/` holds workflow files as inert references — they only run once copied into a
*project's* `.github/workflows/`. Copy the ones you want and edit the install/test steps:
- `relay.yml` — issue labelled `relay` triggers the relay in CI (needs `.claude/` committed in
  that repo and a `CLAUDE_CODE_OAUTH_TOKEN` secret from `claude setup-token`).
- `pr-checks.yml` — the independent gate: full suite + Playwright e2e/visual on every PR. Make this
  a required check in branch protection.
- `mutation.yml` — opt-in (PR label or manual), since it's slow.

## Tweak freely
This is a starting point. The handoff logic is plain English in `commands/handoff.md` and
the agent prompts — edit them as your experience dictates. The red gate (leg 2) and the
"never edit tests to pass them" rule (leg 3) are the two batons worth never dropping.
