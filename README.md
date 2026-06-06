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
    test-writer.md         # leg 2: writes the failing tests (Red)
    implementer.md         # leg 3: makes them pass, no test edits (Green)
    reviewer.md            # leg 4: adversarial, read-only review
  settings.json            # permission defaults
CLAUDE.md                  # per-project commands & conventions (fill this in)
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

## Tweak freely
This is a starting point. The handoff logic is plain English in `commands/handoff.md` and
the agent prompts — edit them as your experience dictates. The red gate (leg 2) and the
"never edit tests to pass them" rule (leg 3) are the two batons worth never dropping.
