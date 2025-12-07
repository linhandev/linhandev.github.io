#!/usr/bin/env bash
set -euo pipefail

# Condense the repository history down to a single commit and clean Git/LFS storage.
# Usage: condense_history.sh [--yes] [--push] [--remote <name>] [--no-bundle]
# Environment:
#   CONDENSE_COMMIT_MSG  Optional commit message override.
#   CONDENSE_REMOTE      Optional remote override (default: origin).

usage() {
  cat <<'EOF'
Usage: condense_history.sh [options]

Options:
  --yes            Skip the interactive confirmation prompt.
  --push           Force push the rewritten branch to the configured remote.
  --remote <name>  Remote to push (default: origin or CONDENSE_REMOTE env).
  --no-bundle      Skip creating a safety bundle of the previous history.
  --help           Show this help message and exit.

This script rewrites the current branch to a single commit, prunes old Git LFS
objects, and aggressively garbage-collects the repository. Run only on a clean
working tree and push with caution, as remote history is overwritten.
EOF
}

prompt_confirm() {
  local prompt=${1:-"Proceed?"}
  read -r -p "$prompt [y/N] " reply || return 1
  case "$reply" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_clean_worktree() {
  if ! git diff --quiet --ignore-submodules; then
    echo "error: unstaged changes detected" >&2
    exit 1
  fi
  if ! git diff --quiet --cached --ignore-submodules; then
    echo "error: staged changes detected" >&2
    exit 1
  fi
  if [[ -n $(git status --short --untracked-files=normal) ]]; then
    echo "error: untracked files present" >&2
    exit 1
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command '$1' not found" >&2
    exit 1
  fi
}

track_images_with_lfs() {
  local -a patterns=(
    '*.png'
    '*.jpg'
    '*.jpeg'
    '*.gif'
    '*.bmp'
    '*.tiff'
    '*.webp'
    '*.svg'
    '*.avif'
  )
  for pattern in "${patterns[@]}"; do
    git lfs track "$pattern" >/dev/null 2>&1 || true
  done
}

main() {
  require_command git
  local have_git_lfs=0
  if command -v git >/dev/null 2>&1 && command -v git-lfs >/dev/null 2>&1; then
    have_git_lfs=1
  fi

  local auto_yes=0 push_after=0 make_bundle=1
  local remote=${CONDENSE_REMOTE:-origin}
  local commit_msg=${CONDENSE_COMMIT_MSG:-"chore: condense history"}

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes)
        auto_yes=1
        shift
        ;;
      --push)
        push_after=1
        shift
        ;;
      --remote)
        [[ $# -lt 2 ]] && { echo "error: --remote requires a value" >&2; exit 1; }
        remote="$2"
        shift 2
        ;;
      --no-bundle)
        make_bundle=0
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        echo "error: unknown option '$1'" >&2
        usage
        exit 1
        ;;
    esac
  done

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "error: not inside a Git repository" >&2
    exit 1
  }
  cd "$repo_root"

  local current_branch
  current_branch=$(git symbolic-ref --short HEAD)

  ensure_clean_worktree

  if [[ $have_git_lfs -eq 0 ]]; then
    echo "warning: git-lfs not available; skipping LFS operations" >&2
  fi

  local timestamp
  timestamp=$(date +%Y%m%d%H%M%S)
  local bundle_path="../$(basename "$repo_root")-history-${timestamp}.bundle"

  echo "Repository: $repo_root"
  echo "Current branch: $current_branch"
  echo "Commit message: $commit_msg"
  if [[ $make_bundle -eq 1 ]]; then
    echo "Backup bundle: $bundle_path"
  else
    echo "Backup bundle: skipped"
  fi
  if [[ $push_after -eq 1 ]]; then
    echo "Remote push: git push $remote $current_branch --force"
  else
    echo "Remote push: skipped"
  fi

  if [[ $auto_yes -eq 0 ]]; then
    prompt_confirm "Rewrite branch '$current_branch' to a single commit?" || {
      echo "aborted" >&2
      exit 1
    }
  fi

  if [[ $make_bundle -eq 1 ]]; then
    echo "Creating safety bundle..."
    git bundle create "$bundle_path" "$current_branch"
  fi

  if [[ $have_git_lfs -eq 1 ]]; then
    echo "Ensuring image patterns are tracked by Git LFS..."
    track_images_with_lfs
  fi

  echo "Staging repository contents..."
  git add -A

  echo "Writing tree snapshot..."
  local tree_sha
  tree_sha=$(git write-tree)

  echo "Creating single commit without running hooks..."
  local author_name author_email committer_name committer_email commit_sha
  author_name=$(git config user.name)
  author_email=$(git config user.email)
  committer_name=${GIT_COMMITTER_NAME:-$author_name}
  committer_email=${GIT_COMMITTER_EMAIL:-$author_email}
  if [[ -z ${author_name:-} || -z ${author_email:-} ]]; then
    echo "error: git user.name and user.email must be configured" >&2
    exit 1
  fi
  commit_sha=$(GIT_AUTHOR_NAME="$author_name" \
    GIT_AUTHOR_EMAIL="$author_email" \
    GIT_COMMITTER_NAME="$committer_name" \
    GIT_COMMITTER_EMAIL="$committer_email" \
    git commit-tree "$tree_sha" -m "$commit_msg")

  echo "Resetting branch '$current_branch' to new condensed commit..."
  git reset --hard "$commit_sha"

  if [[ $have_git_lfs -eq 1 ]]; then
    echo "Pruning Git LFS objects..."
    git lfs prune --force || echo "warning: git lfs prune reported issues" >&2
  fi

  echo "Expiring reflog and running aggressive garbage collection..."
  git reflog expire --expire=now --all
  git gc --prune=now --aggressive

  if [[ $push_after -eq 1 ]]; then
    echo "Force pushing to '$remote/$current_branch'..."
    git push "$remote" "$current_branch" --force
  fi

  echo "History condensed to a single commit on branch '$current_branch'."
  if [[ $make_bundle -eq 1 ]]; then
    echo "A backup bundle is located at: $bundle_path"
  fi
  if [[ $push_after -eq 0 ]]; then
    echo "Remember to push with: git push $remote $current_branch --force"
  fi
}

main "$@"
