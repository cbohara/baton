#!/usr/bin/env bash
# link-claude.sh — mirror this repo's baton command + agents into ~/.claude, so
# /baton and the baton-* agents work in every repo. Single source of truth stays
# this repo; ~/.claude just holds symlinks back to it.
#
# Idempotent and rename-safe: it links whatever .claude/{commands,agents}/*.md
# exist right now and prunes links that used to point here but whose target is
# gone (e.g. after a rename). Run it any time:
#
#   scripts/link-claude.sh                # sync ~/.claude now
#   scripts/link-claude.sh --install-hook # also install a post-commit hook that re-syncs on every commit
#
# Honors $CLAUDE_CONFIG_DIR if set (defaults to ~/.claude).
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)

# Always link to the MAIN working tree, never a linked worktree — baton bg fans
# work out into throwaway worktrees, and we don't want ~/.claude pointing at one
# that later gets removed.
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel)
common_git=$(git -C "$script_dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
if [ -n "$common_git" ]; then
  main_root=$(dirname "$common_git")
  [ -f "$main_root/.claude/commands/baton.md" ] && repo_root="$main_root"
fi

src="$repo_root/.claude"
dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

sync_dir() {  # mirror $src/$1/*.md into $dest/$1
  local sub=$1 link tgt f
  mkdir -p "$dest/$sub"

  # prune links that point into this repo but whose target no longer exists (renames)
  for link in "$dest/$sub"/*.md; do
    [ -L "$link" ] || continue
    tgt=$(readlink "$link")
    case "$tgt" in
      "$src/$sub/"*) [ -e "$tgt" ] || { rm -f "$link"; echo "pruned  $sub/$(basename "$link")"; } ;;
    esac
  done

  # (re)link every current file
  for f in "$src/$sub"/*.md; do
    [ -e "$f" ] || continue
    ln -sf "$f" "$dest/$sub/$(basename "$f")"
    echo "linked  $sub/$(basename "$f")"
  done
}

sync_dir commands
sync_dir agents
echo "synced baton → $dest"

if [ "${1:-}" = "--install-hook" ]; then
  git -C "$repo_root" config core.hooksPath scripts/hooks
  echo "hook installed: core.hooksPath=scripts/hooks (re-syncs on every commit)"
fi
