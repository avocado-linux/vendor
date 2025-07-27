#!/bin/bash
set -e

# Function to configure a single submodule
configure_submodule() {
  local name="$1"
  local sm_path="$2"

  # If specific submodules were requested, check if this one matches
  if [ -n "$REQUESTED_SUBMODULES_STRING" ]; then
    # Convert string back to array
    local requested_array=($REQUESTED_SUBMODULES_STRING)
    local found=0
    for requested in "${requested_array[@]}"; do
      if [ "$name" = "$requested" ]; then
        found=1
        break
      fi
    done
    if [ $found -eq 0 ]; then
      return 0
    fi
  fi

  echo "========================================="
  echo "Processing submodule: $name (path: $sm_path)"
  echo "========================================="

  # Get the upstream URL from .gitmodules if it exists
  upstream_url=$(git config -f ../.gitmodules --get submodule."$name".upstream 2>/dev/null || true)

  if [ -z "$upstream_url" ]; then
    echo "[WARNING] No upstream URL configured for $name in .gitmodules."
    echo "This submodule may have been added without using vendor-repo.sh."
    echo "Skipping git configuration for this submodule."
    echo
    return 0
  fi

  echo "Upstream URL: $upstream_url"

  # Get the origin URL from .gitmodules
  origin_url=$(git config -f ../.gitmodules --get submodule."$name".url 2>/dev/null || true)
  if [ -n "$origin_url" ]; then
    echo "Origin URL: $origin_url"
  fi

  # Check and configure origin remote
  if [ -n "$origin_url" ]; then
    if git remote get-url origin &>/dev/null; then
      current_origin=$(git remote get-url origin)
      if [ "$current_origin" != "$origin_url" ]; then
        echo "Updating origin remote from $current_origin to $origin_url"
        git remote set-url origin "$origin_url"
      else
        echo "Origin remote already correctly configured."
      fi
    else
      echo "Adding origin remote: $origin_url"
      git remote add origin "$origin_url"
    fi
  fi

  # Check and configure upstream remote
  if git remote get-url upstream &>/dev/null; then
    current_upstream=$(git remote get-url upstream)
    if [ "$current_upstream" != "$upstream_url" ]; then
      echo "Updating upstream remote from $current_upstream to $upstream_url"
      git remote set-url upstream "$upstream_url"
    else
      echo "Upstream remote already correctly configured."
    fi
  else
    echo "Adding upstream remote: $upstream_url"
    git remote add upstream "$upstream_url"
  fi

  # Fetch from upstream
  echo "Fetching all branches from upstream..."
  git fetch upstream

  # Create local branches tracking upstream branches
  echo "Creating local branches tracking upstream/*"
  for remote_branch in $(git for-each-ref --format="%(refname:strip=3)" refs/remotes/upstream | grep -v "^HEAD$"); do
    if git show-ref --verify --quiet "refs/heads/$remote_branch"; then
      echo "Branch $remote_branch already exists locally, skipping..."
    else
      echo "Creating and tracking branch: $remote_branch"
      git branch "$remote_branch" "upstream/$remote_branch"
    fi
  done

  echo
  echo "Git configuration applied successfully for $name"
  echo
}

# Parse command line arguments
REQUESTED_SUBMODULES=()
if [ $# -gt 0 ]; then
  REQUESTED_SUBMODULES=("$@")
  echo "Applying git configuration to specific submodules: ${REQUESTED_SUBMODULES[*]}"
else
  echo "Applying git configuration to all vendor submodules..."
fi
echo

# Export the requested submodules as a string for subshells (arrays cannot be exported)
export REQUESTED_SUBMODULES_STRING="${REQUESTED_SUBMODULES[*]}"

# Initialize submodules if not already done
if ! git submodule status | grep -q '^[-+]'; then
  echo "Submodules not initialized. Initializing..."
  git submodule update --init --recursive
fi

# Counter for failed submodules
failed=0

# Export the function so it's available in subshells
export -f configure_submodule

# Process each submodule
git submodule foreach --quiet 'configure_submodule "$name" "$sm_path"' || failed=$((failed + 1))

# Count total/processed submodules
if [ ${#REQUESTED_SUBMODULES[@]} -gt 0 ]; then
  total=${#REQUESTED_SUBMODULES[@]}
else
  total=$(git submodule status | wc -l)
fi
success=$((total - failed))

echo "========================================="
echo "Configuration Summary:"
if [ ${#REQUESTED_SUBMODULES[@]} -gt 0 ]; then
  echo "  Requested: $total"
else
  echo "  Total submodules: $total"
fi
echo "  Successfully configured: $success"
echo "  Failed: $failed"
echo "========================================="

if [ $failed -gt 0 ]; then
  echo
  echo "[WARNING] Some submodules failed to configure. Please check the errors above."
  exit 1
else
  echo
  echo "All submodules have been configured successfully!"
  echo
  echo "You can now work with the vendor repositories with proper upstream tracking."
  echo "Use 'git fetch upstream' in any submodule to get the latest upstream changes."
fi
