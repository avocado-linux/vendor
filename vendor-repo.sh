#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <upstream-repo-url> [github-org]"
  exit 1
fi

UPSTREAM_URL="$1"
REPO_DIR=$(basename -s .git "$UPSTREAM_URL")
ORG_NAME="${2:-avocado-linux}"
ORIGIN_URL="git@github.com:${ORG_NAME}/vendor-${REPO_DIR}.git"

echo "Cloning from upstream: $UPSTREAM_URL"
git clone --origin upstream "$UPSTREAM_URL" "$REPO_DIR"
cd "$REPO_DIR"

echo "Adding origin remote: $ORIGIN_URL"
git remote add origin "$ORIGIN_URL"

echo "Fetching all branches from upstream..."
git fetch upstream

echo "Creating local branches tracking upstream/*"
for remote_branch in $(git for-each-ref --format='%(refname:strip=3)' refs/remotes/upstream | grep -v '^HEAD$'); do
  if git show-ref --verify --quiet "refs/heads/$remote_branch"; then
    echo "Branch $remote_branch already exists locally, skipping..."
  else
    echo "Creating and tracking branch: $remote_branch"
    git branch "$remote_branch" "upstream/$remote_branch"
  fi
done

echo "Done. All upstream branches are now local and origin remote is set to: $ORIGIN_URL"

cd ..

echo "Adding $REPO_DIR as a submodule to the superproject..."

git config -f .gitmodules submodule."$REPO_DIR".path "$REPO_DIR"
git config -f .gitmodules submodule."$REPO_DIR".url "$ORIGIN_URL"
git config -f .gitmodules submodule."$REPO_DIR".upstream "$UPSTREAM_URL"

git add "$REPO_DIR"
git add .gitmodules

echo "Submodule '$REPO_DIR' added. Please commit the changes to the superproject."
git status

