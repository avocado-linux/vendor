#!/bin/bash
set -e

for dir in */; do
  cd "$dir" || continue

  if [ ! -d .git ]; then
    echo "Skipping $dir: not a git repo"
    cd ..
    continue
  fi

  echo "Updating repo in $dir"

  git remote update --prune || { echo "Remote update failed in $dir"; cd ..; continue; }

  # Get actual upstream branches (skip symbolic refs)
  upstream_branches=$(git for-each-ref --format='%(refname:strip=3)' refs/remotes/upstream | grep -v '^HEAD$')

  for branch in $upstream_branches; do
    remote_branch="upstream/$branch"
    
    # Use a safe name for local branch (slashes OK)
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      git switch "$branch"
      git reset --hard "$remote_branch"
    else
      git switch -c "$branch" "$remote_branch"
    fi
  done

  git push --all origin

  cd ..
done

