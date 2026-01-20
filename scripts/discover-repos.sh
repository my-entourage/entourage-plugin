#!/usr/bin/env bash
#
# discover-repos.sh - Auto-discover local repository paths using git remote URLs
#
# Part of entourage-plugin: https://github.com/my-entourage/entourage-plugin
#
# Usage:
#   echo '{"repos":[{"name":"my-app","github":"my-org/my-app"}]}' | ./discover-repos.sh
#
# Input (JSON via stdin):
#   {
#     "repos": [
#       {"name": "my-app", "github": "my-org/my-app"},
#       {"name": "api", "github": "my-org/api-server"}
#     ]
#   }
#
# Output (JSON to stdout):
#   {"my-app": "/Users/me/code/my-app", "api": "/Users/me/projects/api-server"}
#
# Discovery Strategy:
#   1. Checks sibling directories (../*)
#   2. Checks common locations: ~/code/*, ~/dev/*, ~/projects/*, ~/src/*
#   3. Matches by git remote URL (not directory name)
#   4. Returns first match for each repo
#

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract repos array
REPOS=$(echo "$INPUT" | jq -c '.repos // []')
REPO_COUNT=$(echo "$REPOS" | jq 'length')

if [[ "$REPO_COUNT" -eq 0 ]]; then
    echo "{}"
    exit 0
fi

# Build list of candidate directories to search
build_candidate_list() {
    local candidates=()

    # Sibling directories (relative to current working directory)
    if [[ -d ".." ]]; then
        for dir in ../*/; do
            [[ -d "$dir" ]] && candidates+=("$(cd "$dir" && pwd)")
        done
    fi

    # Common development directories
    local common_dirs=(
        "$HOME/code"
        "$HOME/dev"
        "$HOME/projects"
        "$HOME/src"
        "$HOME/Documents/code"
        "$HOME/Documents/projects"
        "$HOME/workspace"
    )

    for base_dir in "${common_dirs[@]}"; do
        if [[ -d "$base_dir" ]]; then
            for dir in "$base_dir"/*/; do
                [[ -d "$dir" ]] && candidates+=("$(cd "$dir" && pwd)")
            done
        fi
    done

    # Deduplicate and print
    printf '%s\n' "${candidates[@]}" | sort -u
}

# Get normalized git remote URL for a directory
get_git_remote() {
    local dir="$1"
    local remote_url

    remote_url=$(git -C "$dir" config --get remote.origin.url 2>/dev/null) || return 1

    # Normalize URL: convert SSH to comparable format
    # git@github.com:org/repo.git -> org/repo
    # https://github.com/org/repo.git -> org/repo
    # https://github.com/org/repo -> org/repo

    # Remove .git suffix
    remote_url="${remote_url%.git}"

    # Handle SSH format: git@github.com:org/repo
    if [[ "$remote_url" =~ ^git@github\.com:(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    # Handle HTTPS format: https://github.com/org/repo
    if [[ "$remote_url" =~ ^https://github\.com/(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    # Return empty for non-GitHub remotes
    return 1
}

# Main discovery logic
discover_repos() {
    local result="{}"
    local found_count=0
    local total_needed="$REPO_COUNT"

    # Get list of candidate directories
    local candidates
    candidates=$(build_candidate_list)

    # For each candidate directory, check if it matches any needed repo
    while IFS= read -r candidate_dir; do
        # Skip if we've found all repos
        [[ "$found_count" -ge "$total_needed" ]] && break

        # Skip if not a directory or not accessible
        [[ ! -d "$candidate_dir" ]] && continue

        # Get git remote for this candidate
        local remote_path
        remote_path=$(get_git_remote "$candidate_dir" 2>/dev/null) || continue

        # Check each repo to see if it matches
        for ((i=0; i<REPO_COUNT; i++)); do
            local repo_name repo_github
            repo_name=$(echo "$REPOS" | jq -r ".[$i].name")
            repo_github=$(echo "$REPOS" | jq -r ".[$i].github // empty")

            # Skip if already found
            if echo "$result" | jq -e ".[\"$repo_name\"]" > /dev/null 2>&1; then
                continue
            fi

            # Skip if no github field to match against
            [[ -z "$repo_github" ]] && continue

            # Compare normalized URLs (case-insensitive)
            local remote_lower repo_github_lower
            remote_lower=$(echo "$remote_path" | tr '[:upper:]' '[:lower:]')
            repo_github_lower=$(echo "$repo_github" | tr '[:upper:]' '[:lower:]')
            if [[ "$remote_lower" == "$repo_github_lower" ]]; then
                result=$(echo "$result" | jq --arg name "$repo_name" --arg path "$candidate_dir" '.[$name] = $path')
                ((found_count++))
                break
            fi
        done
    done <<< "$candidates"

    echo "$result"
}

# Run discovery
discover_repos
