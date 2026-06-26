# baton shell helpers — local parallelism for the baton pipeline.
#
# Single source of truth: source this from your ~/.zshrc so it never drifts —
#   [ -f /path/to/baton/scripts/baton-helpers.zsh ] && source /path/to/baton/scripts/baton-helpers.zsh
#
# One verb, matching the /baton command you invoke inside the session:
#   baton <issue>             foreground — attached, watch + steer
#   baton bg <issue> [more…]  background — detached + logged, fire many, auto-cleans on merge
#   baton rm <issue>          manual cleanup — remove a worktree + its local branch
#
# Each issue gets its own sibling git worktree (<repo>-wt-<issue>) on branch
# issue-<issue>, so many runs go in parallel without stepping on each other.
# baton.md stays generic — this is just the machine-specific local pre-step.
# Shipping (PR + auto-merge/merge) is controlled by Ship mode in the repo's CLAUDE.md.

baton() {  # dispatcher: bare issue → foreground; `bg`/`rm` → subcommands
  case "$1" in
    bg) shift; _baton_bg "$@" ;;
    rm) shift; _baton_rm "$@" ;;
    ""|-h|--help)
      echo "usage:"
      echo "  baton <issue>             foreground — attached, watch + steer"
      echo "  baton bg <issue> [more…]  background — detached + logged, auto-cleans on merge"
      echo "  baton rm <issue>          manual cleanup — remove worktree + local branch"
      ;;
    *) _baton_fg "$1" ;;
  esac
}

_baton_fg() {  # foreground: attached — watch it stream, steer it
  local issue=$1
  local root repo dir
  root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "baton: not in a git repo"; return 1; }
  repo=$(basename "$root"); dir="$(dirname "$root")/${repo}-wt-${issue}"
  [ -d "$dir" ] || git worktree add "$dir" -b "issue-${issue}" 2>/dev/null || git worktree add "$dir" || return 1
  cd "$dir" || return 1
  claude "/baton $issue"
}

_baton_bg() {  # background: detached + logged, doesn't move your shell; auto-cleans merged worktrees
  [ -n "$1" ] || { echo "usage: baton bg <issue> [issue...]"; return 1; }
  local issue
  for issue in "$@"; do
    ( root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 1
      repo=$(basename "$root"); local parent; parent="$(dirname "$root")"
      dir="${parent}/${repo}-wt-${issue}"; log="${parent}/baton-${issue}.log"
      [ -d "$dir" ] || git worktree add "$dir" -b "issue-${issue}" 2>/dev/null || git worktree add "$dir" || exit 1
      cd "$dir" || exit 1
      claude -p "/baton $issue" > "$log" 2>&1
      # auto-cleanup: only when the PR actually merged. Look it up by head ref via pr list,
      # so it still resolves after delete-branch-on-merge removes the remote branch.
      cd "$root" || exit 0
      local n; n=$(gh pr list --head "issue-${issue}" --state merged --json number --jq 'length' 2>/dev/null || echo 0)
      if [ "${n:-0}" -ge 1 ] 2>/dev/null; then
        git worktree remove "$dir" 2>/dev/null && git branch -D "issue-${issue}" 2>/dev/null
        echo "auto-removed $dir (PR merged)" >> "$log"
      else
        echo "kept $dir (no merged PR found — inspect, then: baton rm ${issue})" >> "$log"
      fi ) &
    echo "baton $issue → background (pid $!), log: ../baton-${issue}.log  (tail -f to follow)"
  done
}

_baton_rm() {  # manual cleanup: remove a finished worktree and its local branch
  local issue=$1
  [ -n "$issue" ] || { echo "usage: baton rm <issue>"; return 1; }
  local root repo dir
  root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "baton rm: not in a git repo"; return 1; }
  repo=$(basename "$root"); dir="$(dirname "$root")/${repo}-wt-${issue}"
  git worktree remove "$dir" && echo "removed $dir"
  git branch -D "issue-${issue}" 2>/dev/null && echo "deleted branch issue-${issue}"
}
