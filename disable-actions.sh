#!/bin/bash
set -e

# Script to disable GitHub Actions for vendored repository origins
# Uses the GitHub API via the 'gh' CLI tool
#
# Usage:
#   ./disable-actions.sh              # Disable actions for all vendored repos
#   ./disable-actions.sh repo1 repo2  # Disable actions for specific repos only

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITMODULES_FILE="$SCRIPT_DIR/.gitmodules"

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

# Parse .gitmodules to extract repo info
# Returns: submodule_name|owner/repo
parse_gitmodules() {
  local current_name=""
  local current_url=""

  while IFS= read -r line; do
    # Match submodule name
    if [[ "$line" =~ ^\[submodule\ \"(.+)\"\]$ ]]; then
      # If we have a previous entry, emit it
      if [ -n "$current_name" ] && [ -n "$current_url" ]; then
        echo "$current_name|$current_url"
      fi
      current_name="${BASH_REMATCH[1]}"
      current_url=""
    # Match url line (origin, not upstream)
    elif [[ "$line" =~ ^[[:space:]]*url[[:space:]]*=[[:space:]]*(.*) ]]; then
      local url="${BASH_REMATCH[1]}"
      # Extract owner/repo from various URL formats:
      # ssh://git@github.com/owner/repo.git
      # git@github.com:owner/repo.git
      # https://github.com/owner/repo.git
      if [[ "$url" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
        local owner="${BASH_REMATCH[1]}"
        local repo="${BASH_REMATCH[2]}"
        repo="${repo%.git}"  # Remove .git suffix if present
        current_url="$owner/$repo"
      fi
    fi
  done < "$GITMODULES_FILE"

  # Emit the last entry
  if [ -n "$current_name" ] && [ -n "$current_url" ]; then
    echo "$current_name|$current_url"
  fi
}

# Disable GitHub Actions for a repository
disable_actions() {
  local repo="$1"  # format: owner/repo

  echo "Disabling GitHub Actions for: $repo"

  # Use GitHub API to disable actions
  # https://docs.github.com/en/rest/actions/permissions#set-github-actions-permissions-for-a-repository
  if gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$repo/actions/permissions" \
    -F enabled=false > /dev/null 2>&1; then
    echo "  [OK] Actions disabled for $repo"
    return 0
  else
    echo "  [ERROR] Failed to disable actions for $repo"
    return 1
  fi
}

# Parse command line arguments
REQUESTED_REPOS=("$@")

# Get all repos from .gitmodules
declare -A REPO_MAP  # submodule_name -> owner/repo

while IFS='|' read -r name repo; do
  REPO_MAP["$name"]="$repo"
done < <(parse_gitmodules)

# Determine which repos to process
if [ ${#REQUESTED_REPOS[@]} -gt 0 ]; then
  echo "Disabling GitHub Actions for specific repos: ${REQUESTED_REPOS[*]}"
  REPOS_TO_PROCESS=()
  for requested in "${REQUESTED_REPOS[@]}"; do
    if [ -n "${REPO_MAP[$requested]}" ]; then
      REPOS_TO_PROCESS+=("$requested|${REPO_MAP[$requested]}")
    else
      echo "[WARNING] Unknown submodule: $requested (skipping)"
    fi
  done
else
  echo "Disabling GitHub Actions for all vendored repos..."
  REPOS_TO_PROCESS=()
  for name in "${!REPO_MAP[@]}"; do
    REPOS_TO_PROCESS+=("$name|${REPO_MAP[$name]}")
  done
fi

if [ ${#REPOS_TO_PROCESS[@]} -eq 0 ]; then
  echo "[ERROR] No valid repos to process."
  exit 1
fi

echo "Found ${#REPOS_TO_PROCESS[@]} repos to process."
echo

# Process each repo
succeeded=0
failed=0

for entry in "${REPOS_TO_PROCESS[@]}"; do
  IFS='|' read -r name repo <<< "$entry"
  if disable_actions "$repo"; then
    succeeded=$((succeeded + 1))
  else
    failed=$((failed + 1))
  fi
done

# Summary
echo
echo "========================================="
echo "Summary:"
echo "  Total: ${#REPOS_TO_PROCESS[@]}"
echo "  Succeeded: $succeeded"
echo "  Failed: $failed"

if [ $failed -gt 0 ]; then
  exit 1
fi
