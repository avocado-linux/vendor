#!/bin/bash
set -e

# Initialize the superproject repository
if [ ! -d .git ]; then
  echo "Initializing git repository in current directory..."
  git init
else
  echo "Git repository already exists in current directory."
fi

# Create or clear the .gitmodules file
> .gitmodules

for dir in */; do
  dir=${dir%/} # remove trailing slash
  if [ ! -d "$dir/.git" ]; then
    echo "Skipping $dir: not a git repo"
    continue
  fi

  echo "Adding submodule for $dir"

  # Get the URL of the 'origin' remote
  origin_url=$(cd "$dir" && git remote get-url origin)

  if [ -z "$origin_url" ]; then
    echo "Could not get origin URL for $dir. Skipping."
    continue
  fi

  # Add submodule entry to .gitmodules
  git config -f .gitmodules submodule."$dir".path "$dir"
  git config -f .gitmodules submodule."$dir".url "$origin_url"

  # Stage the submodule directory. This creates a gitlink entry.
  git add "$dir"

done

# Stage the .gitmodules file
git add .gitmodules

echo "Submodules added. Please commit the changes."
git status 
