# relay shell helpers — local parallelism for the handoff relay.
#
# Single source of truth: source this from your ~/.zshrc so it never drifts —
#   [ -f /path/to/relay/docs/relay-helpers.zsh ] && source /path/to/relay/docs/relay-helpers.zsh
#
# Functions are named to match the /handoff command you invoke inside the session:
#   handoff <issue>             foreground — attached, watch + steer
#   handoffbg <issue> [more...] background — detached + logged, fire many
#   handoffrm <issue>           remove a finished worktree after its PR merges
#
# Each issue gets its own sibling git worktree (<repo>-wt-<issue>) on branch
# issue-<issue>, so many relays run in parallel without stepping on each other.
# handoff.md stays generic — this is just the machine-specific local pre-step.
# Shipping (PR + auto-merge/merge) is controlled by Ship mode in the repo's CLAUDE.md.

handoff() {  # foreground: attached — watch it stream, steer it. Usage: handoff 142
  local issue=$1
  [ -n "$issue" ] || { echo "usage: handoff <issue>"; return 1; }
  local root repo dir
  root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "handoff: not in a git repo"; return 1; }
  repo=$(basename "$root"); dir="$(dirname "$root")/${repo}-wt-${issue}"
  [ -d "$dir" ] || git worktree add "$dir" -b "issue-${issue}" 2>/dev/null || git worktree add "$dir" || return 1
  cd "$dir" || return 1
  claude "/handoff $issue"
}

handoffbg() {  # background: detached + logged, doesn't move your shell. Usage: handoffbg 143 144 145
  [ -n "$1" ] || { echo "usage: handoffbg <issue> [issue...]"; return 1; }
  local issue
  for issue in "$@"; do
    ( root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 1
      repo=$(basename "$root"); dir="$(dirname "$root")/${repo}-wt-${issue}"
      [ -d "$dir" ] || git worktree add "$dir" -b "issue-${issue}" 2>/dev/null || git worktree add "$dir" || exit 1
      cd "$dir" || exit 1
      claude -p "/handoff $issue" > "$(dirname "$root")/relay-${issue}.log" 2>&1 ) &
    echo "handoff $issue → background (pid $!), log: ../relay-${issue}.log  (tail -f to follow)"
  done
}

handoffrm() {  # cleanup: remove a finished worktree once its PR has merged. Usage: handoffrm 142
  local issue=$1
  [ -n "$issue" ] || { echo "usage: handoffrm <issue>"; return 1; }
  local root repo dir
  root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "handoffrm: not in a git repo"; return 1; }
  repo=$(basename "$root"); dir="$(dirname "$root")/${repo}-wt-${issue}"
  git worktree remove "$dir" && echo "removed $dir"
}
