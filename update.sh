#!/bin/bash
set -e

# Function to update a single submodule
update_submodule() {
  local submodule_name="$1"
  local submodule_path="$2"

  # If specific submodules were requested, check if this one matches
  if [ -n "$REQUESTED_SUBMODULES_STRING" ]; then
    # Convert string back to array
    local requested_array=($REQUESTED_SUBMODULES_STRING)
    local found=0
    for requested in "${requested_array[@]}"; do
      if [ "$submodule_name" = "$requested" ]; then
        found=1
        break
      fi
    done
    if [ $found -eq 0 ]; then
      return 0
    fi
  fi

  echo "Updating submodule: $submodule_name"

  # Update remotes
  if ! git remote update --prune; then
    echo "[ERROR] Remote update failed in '$submodule_name'."
    return 1
  fi

  # Get actual upstream branches (skip symbolic refs)
  local upstream_branches=$(git for-each-ref --format='%(refname:strip=3)' refs/remotes/upstream | grep -v '^HEAD$')

  if [ -z "$upstream_branches" ]; then
    echo "[WARNING] No upstream branches found in '$submodule_name'."
    return 0
  fi

  # Update each branch
  for branch in $upstream_branches; do
    local remote_branch="upstream/$branch"

    # Use a safe name for local branch (slashes OK)
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      git switch "$branch"
      git reset --hard "$remote_branch"
    else
      git switch -c "$branch" "$remote_branch"
    fi
  done

  # Push all branches to origin
  if [ "${FORCE_PUSH:-0}" -eq 1 ]; then
    if ! git push --all origin --force; then
      echo "[ERROR] Failed to push branches for '$submodule_name'."
      return 1
    fi
  else
    if ! git push --all origin; then
      echo "[ERROR] Failed to push branches for '$submodule_name'."
      return 1
    fi
  fi

  echo "Successfully updated '$submodule_name'."
  return 0
}

# Export function for use in subshells
export -f update_submodule

# Parse command line arguments
FORCE_PUSH=0
REQUESTED_SUBMODULES=()

for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE_PUSH=1
      ;;
    *)
      REQUESTED_SUBMODULES+=("$arg")
      ;;
  esac
done

# Display what will be updated
if [ ${#REQUESTED_SUBMODULES[@]} -gt 0 ]; then
  echo "Updating specific submodules: ${REQUESTED_SUBMODULES[*]}"
else
  echo "Updating all submodules..."
fi

if [ $FORCE_PUSH -eq 1 ]; then
  echo "Force push enabled."
fi

# Export variables for subshells
export FORCE_PUSH

# Export the requested submodules as a string for subshells (arrays cannot be exported)
export REQUESTED_SUBMODULES_STRING="${REQUESTED_SUBMODULES[*]}"

# Initialize submodules if not already done
if ! git submodule status >/dev/null 2>&1; then
  echo "[ERROR] Not in a git repository with submodules."
  exit 1
fi

if git submodule status | grep -q '^-'; then
  echo "Initializing submodules..."
  git submodule update --init --recursive
fi

# Process submodules
failed=0
processed=0

# Run update for each submodule
git submodule foreach --quiet '
  if update_submodule "$name" "$sm_path"; then
    exit 0
  else
    exit 1
  fi
' || failed=$((failed + 1))

# Count processed submodules
if [ ${#REQUESTED_SUBMODULES[@]} -gt 0 ]; then
  processed=${#REQUESTED_SUBMODULES[@]}
else
  processed=$(git submodule status | wc -l)
fi

# Summary
echo
echo "========================================="
echo "Update Summary:"
echo "  Requested: $processed"
echo "  Failed: $failed"
echo "  Succeeded: $((processed - failed))"

if [ $failed -gt 0 ]; then
  exit 1
fi
