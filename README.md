<p align="center">
  <img src="assets/baton.png" alt="One robot hand passing a rainbow baton to another robot hand" width="560">
</p>

<h1 align="center">baton</h1>

A portable `spec → tests → implement → review` path for Claude Code. You hand off a
task and a crew of subagents runs the path leg by leg, checking each baton pass before the
next runner takes off. The same files run locally, in CI (`claude-code-action`), or on
Claude Code on the web — unchanged.

```
.claude/
  commands/baton.md       # the starter — /baton
  agents/
    baton-code-explorer.md # leg 1: lightweight read-only trace of the code the task touches
    baton-spec-writer.md   # leg 1: spec → testable acceptance criteria (starts from the code map)
    baton-test-writer.md   # leg 2: writes failing tests (Red) — example/property/visual
    baton-implementer.md   # leg 3: makes them pass, no test edits (Green)
    baton-reviewer.md      # leg 5: adversarial review against the spec
    baton-qa-browser.md    # leg 4: verifies the running app in a real browser (Playwright MCP)
  settings.json            # permission defaults
CLAUDE.md                  # per-project commands, gate toggles & conventions (fill this in)
```

## Use it in one project (per-repo)

1. Copy `.claude/` and `CLAUDE.md` into the repo root.
2. Fill in the commands/conventions in `CLAUDE.md`.
3. In a Claude Code session: `/baton <issue-number | spec text>`.

## Use it everywhere (global) — the symlink pattern

Claude Code reads config from two scopes: the project (`./.claude/`) and the user
(`~/.claude/`). Anything in `~/.claude/agents/` and `~/.claude/commands/` is available
in **every** repo — the same trick as symlinking into your opencode config dir.

Keep this repo as the single source of truth and symlink it into the user scope.
One script does it:

```sh
scripts/link-claude.sh                # mirror /baton + the baton-* agents into ~/.claude
scripts/link-claude.sh --install-hook # ...and re-sync on every commit (post-commit hook)
```

It links individual files (not the whole dir, so it merges with anything already in
`~/.claude/` instead of clobbering it), is idempotent, and is **rename-safe** — it links
whatever `.claude/{commands,agents}/*.md` exist now and prunes links whose target was
renamed away. With `--install-hook` it sets `core.hooksPath=scripts/hooks`, so a later
rename or a new agent never leaves your global config stale. It always links the **main**
checkout, so the worktree fan-out below can't leave `~/.claude` dangling. Honors
`$CLAUDE_CONFIG_DIR` if you've moved your config.

Prefer doing it by hand? It's just `ln -s "$PWD/.claude/commands/baton.md"
~/.claude/commands/` and the same for each `.claude/agents/baton-*.md`.

Now `/baton` and its agents work in any repo. **Per-project specifics stay in each
repo's own `CLAUDE.md`** — that's the split: generic baton behavior is global and version-
controlled here; the test command, conventions, and dev-server URL live per-repo. A
project's local `.claude/` also composes with the global one, so you can override or add
per-repo when you want.

## Note on global CLAUDE.md
`~/.claude/CLAUDE.md` loads in every project too. Keep only truly universal preferences
there (e.g. "always run the linter before finishing"). Anything project-shaped belongs in
the repo's CLAUDE.md, or it will leak into unrelated work.

## Deeper testing — two tiers
Baton supports three heavier techniques, toggled per project in `CLAUDE.md` under
"Testing gates." They split across two tiers by cost and environment:

**In-session (cheap, runs inside the pipeline):**
- **Property-based** (Hypothesis): the test-writer writes invariant tests that generate
  hundreds of inputs. Best for parsers, serializers, math, anything with a clear invariant.

**Better as separate PR-triggered CI checks (expensive, environment-specific):**
- **Browser QA** (qa-browser, via the Playwright MCP server): drives the running app against
  each acceptance criterion, screenshots the result, posts a PASS/FAIL report to the PR.
- **Visual regression** (Playwright snapshots / Percy / Chromatic): screenshot-diffs the UI and
  flags unintended changes.

Why the second tier is better in CI: those gates need a browser and a running app, they take
real time, and — like your test suite — they're the *independent* checks the agent can't
self-report its way past. Run them in-session for thorough local passes; wire them as their own
workflows on the PR for hands-off autonomy.

**Playwright MCP setup** (once, for browser QA): `claude mcp add playwright npx @playwright/mcp@latest`.

A backend library enables only property-based; a web app turns the rest on too. Keep a
project lean — enable only what fits.

## How baton ships (Ship mode)
The Anchor leg lands the work according to **Ship mode** in the repo's `CLAUDE.md`:
- `auto-merge` (default) — open a PR (the durable artifact) and let CI merge it the moment
  your required PR check goes green. You never click anything; main stays always-verified. This is
  the autopilot path: fire `/baton`, walk away, come back to a merged-and-checked main. (Bring your
  own CI — any required status check works; baton no longer ships workflow templates.)
- `pr` — open a PR and stop. A human merges. Use when every diff deserves eyes.
- `merge` — merge immediately, no CI wait. Throwaway/solo repos only; the in-session reviewer is
  then the sole gate.

If `auto-merge` is set but the repo has no required check to gate on, Baton does **not** merge
blind — it leaves a plain PR open and tells you. So the seatbelt can't silently come off.

### One-time setup for `auto-merge` (per repo)
`auto-merge` gates on a required PR check, so a fresh repo needs three things: a CI workflow that
produces a check, auto-merge enabled, and branch protection requiring that check.

**1. Give the repo a check to gate on.** Baton is bring-your-own-CI, but here's a minimal independent
gate to start from — drop it in `.github/workflows/pr-checks.yml` and edit the install/test steps for
your stack:

```yaml
name: pr-checks
on: pull_request
jobs:
  tests:                       # this job name is the required check (see step 3)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # --- edit for your stack ---
      - uses: actions/setup-python@v5
        with: { python-version: '3.x' }
      - run: pip install -e '.[dev]'
      - run: pytest -q
```

For a web app, add a second job (e.g. `browser`) that boots the app and runs Playwright e2e/visual,
and require it too (step 3). Keep the slow, environment-heavy gates here in CI — that's tier two from
[Deeper testing](#deeper-testing--two-tiers).

**2. Enable auto-merge on the repo:**

```sh
gh repo edit --enable-auto-merge
```

**3. Require the check on `main`** (CI-gated, not human-gated):

```sh
gh api -X PUT repos/{owner}/{repo}/branches/main/protection \
  -f 'required_status_checks[strict]=true' \
  -f 'required_status_checks[contexts][]=tests' \
  -F 'enforce_admins=false' \
  -F 'required_pull_request_reviews=null' \
  -F 'restrictions=null'
```

`tests` must match the job name from step 1 — change both together, and add more `contexts[]` lines for
additional required checks (e.g. `browser`). `required_pull_request_reviews=null` keeps it gated on CI
but not on a human approval, which is the point of autopilot. Until all three are set, `auto-merge` safely
falls back to leaving the PR open.

Note: if you run `/baton` from your own CI workflow, a PR it opens with the default `GITHUB_TOKEN`
won't trigger your other workflows — so auto-merge would wait forever on a check that never fires.
Either run `/baton` locally (pushes under your creds, CI fires normally) or push from CI with a PAT
instead of the default token. Locally-run pipelines are unaffected.

Heads-up for **private repos on the free plan**: GitHub won't let you require a status check there
(branch protection and rulesets both need Pro or a public repo), so `auto-merge` has nothing to gate on
and would just leave PRs open. Use Ship mode `merge` on those repos until you go Pro or public.

### Keeping branches tidy
Both `merge` and `auto-merge` leave the source branch behind by default — and with worktree fan-out
(`<repo>-wt-<issue>`, see below) those `issue-*` branches add up fast. Turn on auto-delete so the remote
prunes each branch the moment its PR merges:

```sh
gh repo edit <owner>/<repo> --delete-branch-on-merge
```

That handles the *remote*. For the *local* worktrees, `baton bg` auto-removes a worktree once its PR
merges (see below); `baton rm <issue>` does it manually for the rest.

## Local parallelism (optional)
`baton.md` runs one pipeline in whatever tree you're in — it's deliberately generic so it works
identically in GitHub Actions, locally, and on the web. To fan out across issues *locally*, keep the
worktree pre-step **out** of the pipeline (it's machine-specific) and put it in your shell profile instead.
One verb (`baton`, matching the `/baton` command), with two subcommands:

```sh
baton <issue>             # foreground: attached session, watch + steer.        baton 142
baton bg <issue> [more…]  # background: detached + logged, fire many.            baton bg 143 144 145
baton rm <issue>          # manual cleanup: remove a worktree + its local branch. baton rm 142
```

`baton` and `baton bg` create a sibling worktree `<repo>-wt-<issue>` on branch `issue-<issue>`, so
every run works in isolation — run as many as your machine handles, none stepping on the others. They
ship identically (per the repo's Ship mode); foreground vs background only changes whether you watch it
stream or check `../baton-<issue>.log` later.

**Background auto-cleans itself.** When a `baton bg` run finishes, it checks whether the issue's PR
actually merged (via `gh pr list --head issue-<issue> --state merged`, which still resolves after
delete-branch-on-merge prunes the branch). If merged, it removes the worktree and local branch
automatically; if **not** merged — a dropped baton, red tests, anything — it **keeps** the worktree so
you can inspect it. You never lose work to cleanup; only the successes get tidied. `baton rm` is then
just for the leftovers (failed runs you've dealt with, or foreground worktrees).

Typical lifecycle, fanning a few issues out in the background:

```sh
baton bg 142 143 144       # 3 isolated worktrees, 3 runs detached, each logging to ../baton-<n>.log
tail -f ../baton-142.log   # peek at one if you're curious (optional)
# … each run ships per Ship mode; on merge it auto-removes its own worktree + branch …
baton rm 143               # only needed for any that DIDN'T merge (the log says "kept … inspect")
```

Start with foreground `baton` until you trust the permission allowlist end-to-end — a background run
stalls silently on an un-allowed prompt — then graduate routine slices to `baton bg`. Note: you can't
remove the worktree you're currently `cd`'d into, so run `baton rm` from the main checkout.

The full functions live in `scripts/baton-helpers.zsh`. **Source them** rather than pasting into `~/.zshrc`,
so the baton repo stays the single source of truth (same reasoning as symlinking the agents) and your
shell never drifts from canonical:

```sh
# in ~/.zshrc — guarded so a missing repo doesn't break shell startup
[ -f "$HOME/git/baton/scripts/baton-helpers.zsh" ] && source "$HOME/git/baton/scripts/baton-helpers.zsh"
```

## Tweak freely
This is a starting point. The baton logic is plain English in `commands/baton.md` and
the agent prompts — edit them as your experience dictates. The red gate (leg 2) and the
"never edit tests to pass them" rule (leg 3) are the two batons worth never dropping.
