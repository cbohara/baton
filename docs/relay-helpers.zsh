# relay shell helpers — local parallelism for the handoff relay.
#
# Source this from your ~/.zshrc:  source /path/to/relay/docs/relay-helpers.zsh
# (or paste the two functions in directly).
#
# Each issue gets its own sibling git worktree (<repo>-wt-<issue>) on branch
# issue-<issue>, so many relays run in parallel without stepping on each other.
# handoff.md stays generic — this is just the machine-specific local pre-step.
# Shipping (PR + auto-merge) is controlled by Ship mode in the repo's CLAUDE.md;
# both functions ship identically.

relay() {  # foreground: attached — watch it stream, steer it. Usage: relay 142
  local issue=$1
  [ -n "$issue" ] || { echo "usage: relay <issue>"; return 1; }
  local root repo dir
  root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "relay: not in a git repo"; return 1; }
  repo=$(basename "$root"); dir="$(dirname "$root")/${repo}-wt-${issue}"
  [ -d "$dir" ] || git worktree add "$dir" -b "issue-${issue}" 2>/dev/null || git worktree add "$dir" || return 1
  cd "$dir" || return 1
  claude "/handoff $issue"
}

relaybg() {  # background: detached + logged, doesn't move your shell. Usage: relaybg 143 144 145
  [ -n "$1" ] || { echo "usage: relaybg <issue> [issue...]"; return 1; }
  local issue
  for issue in "$@"; do
    ( root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 1
      repo=$(basename "$root"); dir="$(dirname "$root")/${repo}-wt-${issue}"
      [ -d "$dir" ] || git worktree add "$dir" -b "issue-${issue}" 2>/dev/null || git worktree add "$dir" || exit 1
      cd "$dir" || exit 1
      claude -p "/handoff $issue" > "$(dirname "$root")/relay-${issue}.log" 2>&1 ) &
    echo "relay $issue → background (pid $!), log: ../relay-${issue}.log  (tail -f to follow)"
  done
}

# Cleanup helper: remove a finished worktree once its PR has merged. Usage: relayrm 142
relayrm() {
  local issue=$1
  [ -n "$issue" ] || { echo "usage: relayrm <issue>"; return 1; }
  local root repo dir
  root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "relayrm: not in a git repo"; return 1; }
  repo=$(basename "$root"); dir="$(dirname "$root")/${repo}-wt-${issue}"
  git worktree remove "$dir" && echo "removed $dir"
}
