#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values
dir=$(echo "$input" | jq -r '.workspace.current_dir')
dir_name=$(basename "$dir")
model=$(echo "$input" | jq -r '.model.display_name')

# Check for git branch
git_branch=""
dirty_count=""
if git -C "$dir" rev-parse --git-dir > /dev/null 2>&1; then
    git_branch=$(git -C "$dir" branch --show-current 2>/dev/null)

    # Count dirty files (modified, untracked, etc.)
    # Skip optional locks to avoid conflicts
    dirty=$(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$dirty" -gt 0 ]; then
        dirty_count=" ${dirty}*"
    fi
fi

# Colors
PALE_PURPLE='\033[38;5;183m'
CYAN='\033[36m'
YELLOW='\033[33m'
RED='\033[31m'
WHITE='\033[37m'
RESET='\033[0m'

# Get percentage directly from context_window
pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')

# Build progress bar (10 blocks total)
filled=$((pct / 10))
empty=$((10 - filled))

bar=""
for ((i=0; i<filled; i++)); do bar="${bar}█"; done
for ((i=0; i<empty; i++)); do bar="${bar}░"; done

# Determine bar color based on percentage
if [ "$pct" -le 40 ]; then
    BAR_COLOR="$WHITE"
elif [ "$pct" -le 75 ]; then
    BAR_COLOR="$YELLOW"
else
    BAR_COLOR="$RED"
fi

# Build status line with progress bar always visible
printf "${PALE_PURPLE}%s${RESET}%b | ${CYAN}%s${RESET} | ${BAR_COLOR}%s %d%%${RESET}" "$dir_name" "${git_branch:+ ${YELLOW}(${git_branch}${dirty_count})${RESET}}" "$model" "$bar" "$pct"
