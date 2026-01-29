#!/bin/bash
set -e

# Script to create vendor origin repositories on GitHub
# Uses the GitHub CLI (gh) to create repos with proper settings
#
# Usage:
#   ./create-origin.sh                    # Create origins for all submodules (if missing)
#   ./create-origin.sh repo1 repo2        # Create origins for specific submodules only
#
# The script will:
#   - Create a public repo named vendor-{submodule_name}
#   - Set description to "Vendor fork for {submodule_name}"
#   - Set homepage to the upstream URL
#   - Disable releases, packages, and deployments from the homepage
#   - Disable GitHub Actions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITMODULES_FILE="$SCRIPT_DIR/.gitmodules"
ORG="avocado-linux"

# Check for gh CLI
if ! command -v gh &> /dev/null; then
  echo "[ERROR] GitHub CLI (gh) is not installed or not in PATH."
  echo "Please install it: https://cli.github.com/"
  exit 1
fi

# Check gh authentication
if ! gh auth status &> /dev/null; then
  echo "[ERROR] Not authenticated with GitHub CLI."
  echo "Please run: gh auth login"
  exit 1
fi

# Check for .gitmodules
if [ ! -f "$GITMODULES_FILE" ]; then
  echo "[ERROR] .gitmodules file not found at: $GITMODULES_FILE"
  exit 1
fi

# Parse .gitmodules to extract submodule info
# Returns: submodule_name|upstream_url
parse_gitmodules_with_upstream() {
  local current_name=""
  local current_upstream=""

  while IFS= read -r line; do
    # Match submodule name
    if [[ "$line" =~ ^\[submodule\ \"(.+)\"\]$ ]]; then
      # If we have a previous entry, emit it
      if [ -n "$current_name" ] && [ -n "$current_upstream" ]; then
        echo "$current_name|$current_upstream"
      fi
      current_name="${BASH_REMATCH[1]}"
      current_upstream=""
    # Match upstream line
    elif [[ "$line" =~ ^[[:space:]]*upstream[[:space:]]*=[[:space:]]*(.*) ]]; then
      current_upstream="${BASH_REMATCH[1]}"
      # Clean up the URL (remove trailing .git if present for display)
      current_upstream="${current_upstream%.git}"
    fi
  done < "$GITMODULES_FILE"

  # Emit the last entry
  if [ -n "$current_name" ] && [ -n "$current_upstream" ]; then
    echo "$current_name|$current_upstream"
  fi
}

# Check if a repository exists
repo_exists() {
  local repo="$1"
  gh repo view "$repo" > /dev/null 2>&1
}

# Disable GitHub Actions for a repository
disable_actions() {
  local repo="$1"

  if gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$repo/actions/permissions" \
    -F enabled=false > /dev/null 2>&1; then
    echo "  [OK] Actions disabled"
    return 0
  else
    echo "  [WARN] Failed to disable actions"
    return 1
  fi
}

# Disable releases, packages, and deployments from homepage
disable_homepage_sections() {
  local repo="$1"

  # Disable releases, packages, and deployments visibility on homepage
  # These are controlled via the repository's homepage settings
  if gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$repo" \
    -F has_downloads=false > /dev/null 2>&1; then
    echo "  [OK] Downloads disabled"
  fi

  # Disable environments/deployments visibility (if API supports it)
  # Note: GitHub doesn't expose all homepage settings via API, some may need manual config
}

# Create a vendor repository
create_vendor_repo() {
  local name="$1"
  local upstream_url="$2"
  local repo_name="vendor-$name"
  local full_repo="$ORG/$repo_name"
  local description="Vendor fork for $name"

  echo "Processing: $name"
  echo "  Repo: $full_repo"
  echo "  Upstream: $upstream_url"

  # Check if repo already exists
  if repo_exists "$full_repo"; then
    echo "  [SKIP] Repository already exists"
    return 0
  fi

  # Create the repository
  echo "  Creating repository..."
  if ! gh repo create "$full_repo" \
    --public \
    --description "$description" \
    --homepage "$upstream_url" \
    --disable-wiki \
    --disable-issues 2>&1 | grep -v "^$"; then
    echo "  [ERROR] Failed to create repository"
    return 1
  fi
  echo "  [OK] Repository created"

  # Wait a moment for GitHub to fully provision the repo
  sleep 1

  # Disable homepage sections (releases, packages, deployments)
  echo "  Configuring repository settings..."
  disable_homepage_sections "$full_repo"

  # Disable GitHub Actions
  disable_actions "$full_repo"

  echo "  [OK] Successfully created $full_repo"
  return 0
}

# Parse command line arguments
REQUESTED_REPOS=("$@")

# Get all submodules from .gitmodules
declare -A SUBMODULE_MAP  # submodule_name -> upstream_url

while IFS='|' read -r name upstream; do
  SUBMODULE_MAP["$name"]="$upstream"
done < <(parse_gitmodules_with_upstream)

# Determine which repos to process
if [ ${#REQUESTED_REPOS[@]} -gt 0 ]; then
  echo "Creating vendor repos for: ${REQUESTED_REPOS[*]}"
  REPOS_TO_PROCESS=()
  for requested in "${REQUESTED_REPOS[@]}"; do
    if [ -n "${SUBMODULE_MAP[$requested]}" ]; then
      REPOS_TO_PROCESS+=("$requested|${SUBMODULE_MAP[$requested]}")
    else
      echo "[WARNING] Unknown submodule: $requested (skipping)"
    fi
  done
else
  echo "Creating vendor repos for all submodules..."
  REPOS_TO_PROCESS=()
  for name in "${!SUBMODULE_MAP[@]}"; do
    REPOS_TO_PROCESS+=("$name|${SUBMODULE_MAP[$name]}")
  done
fi

if [ ${#REPOS_TO_PROCESS[@]} -eq 0 ]; then
  echo "[ERROR] No valid submodules to process."
  exit 1
fi

echo "Found ${#REPOS_TO_PROCESS[@]} submodules to process."
echo

# Process each submodule
created=0
skipped=0
failed=0

for entry in "${REPOS_TO_PROCESS[@]}"; do
  IFS='|' read -r name upstream <<< "$entry"
  result=0
  create_vendor_repo "$name" "$upstream" || result=$?

  if [ $result -eq 0 ]; then
    # Check if it was skipped (already exists) or created
    if repo_exists "$ORG/vendor-$name"; then
      # We don't track skip vs create separately in this simple version
      created=$((created + 1))
    fi
  else
    failed=$((failed + 1))
  fi
  echo
done

# Summary
echo "========================================="
echo "Summary:"
echo "  Total: ${#REPOS_TO_PROCESS[@]}"
echo "  Succeeded: $created"
echo "  Failed: $failed"

if [ $failed -gt 0 ]; then
  exit 1
fi
