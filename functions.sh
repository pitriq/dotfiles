#!/usr/bin/env zsh

# --------------------------------
# --------- 🐙 Functions ---------
# --------------------------------

function work_simulator() {
  cd $(xcrun simctl get_app_container booted io.siteplan.sytex data)
}

function create_fvm_config() {
  mkdir -p .vscode
  touch .vscode/settings.json

  FVM_CONFIG="{\"dart.flutterSdkPath\":\".fvm/flutter_sdk\",\"search.exclude\":{\"**/.fvm\":true},\"files.watcherExclude\":{\"**/.fvm\":true}}"
  echo $FVM_CONFIG > .vscode/settings.json
}

# Creates a flutter project with fvm
#
# Usage: create_fvm_project DESTINATION [-v VERSION] [-b ORG_BUNDLE_ID]
# 
# DESTINATION is the name of the flutter project 
# to be created and VERSION is the flutter version you wish
# to use (defaults to 'stable').
# 
# ORG_BUNDLE_ID is the bundle id of the organization you're working for.
function create_fvm_project() {
  # Check if fvm is available
  if ! command -v fvm &> /dev/null
  then
      echo "fvm could not be found. Make sure it's installed and available."
      exit 1
  fi
  
  # Get the version parameter. Defaults to 'stable'
  VERSION="stable"
  while getopts ":v:" opt; do
    case $opt in
      v) VERSION=$OPTARG ;;
    esac
  done

  # Get the bundle id parameter, if specified
  while getopts ":b" opt; do
    case $opt in
      b) ORG_BUNDLE_ID=$OPTARG ;;
    esac
  done

  # Get the platforms paremeter. Defaults to "ios,android"
  PLATFORMS="ios,android"
  while getopts ":p" opt; do
    case $opt in
      p) PLATFORMS=$OPTARG ;;
    esac
  done
      
  # Create the destination directory
  DESTINATION=${@:$OPTIND:1}
  mkdir -p $DESTINATION
  cd $DESTINATION

  # Setup fvm in the destination directory using VERSION
  fvm use $VERSION --force

  # Create the actual project. If the org bundle id is specified, use it
  if [ -n "$ORG_BUNDLE_ID" ]; then
    fvm flutter create --org $ORG_BUNDLE_ID --platforms $PLATFORMS .
  else
    fvm flutter create --platforms $PLATFORMS .
  fi

  # Create vscode config file
  $(create_fvm_config)

  # Add vscode configs directory to .gitignore
  # (Creating a backup file is required for sed inline text replacing in macOS)
  sed -i'.bak' "s/#.vscode\//.vscode\//" .gitignore
  rm .gitignore.bak
  
  # Add fvm flutter symlink to .gitignore
  echo "\n# fvm\n.fvm/" >> .gitignore
}

# Function to convert epoch time (seconds or milliseconds) to human readable format
function timestamp() {
  # Check if an argument was provided
  if [ -z "$1" ]; then
    echo "Usage: timestamp <epoch_time>"
    return 1
  fi

  local epoch_time=$1
  local length=${#epoch_time}

  # Determine if the input is in seconds or milliseconds based on length
  if [ $length -gt 10 ]; then
    # Convert milliseconds to seconds for date command
    epoch_time=$(echo "scale=0; $epoch_time / 1000" | bc)
  fi

  # Convert to human readable format
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS date command
    date -r $epoch_time "+%Y-%m-%d %H:%M:%S"
  else
    # Linux date command
    date -d @$epoch_time "+%Y-%m-%d %H:%M:%S"
  fi
}

symbolicate() {
  local STACKTRACE=$1
  local SYMBOLS=$2
  local OUTPUT=$3

  if [ -z "$STACKTRACE" ] || [ -z "$SYMBOLS" ]; then
    echo "Usage: symbolicate <stacktrace.txt> <symbols_file> [output_file]"
    echo ""
    echo "If output_file is not specified, it will be named: <stacktrace>_symbolicated.txt"
    return 1
  fi

  # Set default output file if not provided
  if [ -z "$OUTPUT" ]; then
    OUTPUT="${STACKTRACE%.*}_symbolicated.txt"
  fi

  if [ ! -f "$STACKTRACE" ]; then
    echo "Error: Stack trace file not found: $STACKTRACE"
    return 1
  fi

  if [ ! -f "$SYMBOLS" ]; then
    echo "Error: Symbols file not found: $SYMBOLS"
    return 1
  fi

  # Find the right addr2line tool for macOS
  local ADDR2LINE=""

  # Try Android NDK llvm-addr2line first (latest Android NDK versions)
  if [ -d "$HOME/Library/Android/sdk/ndk" ]; then
    local NDK_LLVM_ADDR2LINE=$(find "$HOME/Library/Android/sdk/ndk" -name "llvm-addr2line" 2>/dev/null | head -n 1)
    if [ ! -z "$NDK_LLVM_ADDR2LINE" ]; then
      ADDR2LINE="$NDK_LLVM_ADDR2LINE"
    fi
  fi

  # Try system llvm-addr2line (from Homebrew LLVM)
  if [ -z "$ADDR2LINE" ] && command -v llvm-addr2line &> /dev/null; then
    ADDR2LINE="llvm-addr2line"
  fi

  # Try regular addr2line as last resort (might not work on macOS)
  if [ -z "$ADDR2LINE" ] && command -v addr2line &> /dev/null; then
    ADDR2LINE="addr2line"
    echo "Warning: Using system addr2line - may not work with Android ELF files"
  fi

  if [ -z "$ADDR2LINE" ]; then
    echo "Error: No suitable addr2line tool found!"
    echo ""
    echo "Please install one of the following:"
    echo "  1. Android NDK (should contain llvm-addr2line at ~/Library/Android/sdk/ndk)"
    echo "  2. LLVM tools: brew install llvm"
    return 1
  fi

  echo "Using: $ADDR2LINE"
  echo "Input: $STACKTRACE"
  echo "Symbols: $SYMBOLS"
  echo "Output: $OUTPUT"
  echo "Symbolicating stack trace..."
  echo ""

  # Clear/create output file
  echo -n "" > "$OUTPUT"

  # Process each line with a program counter (pc)
  while IFS= read -r line; do
    # Check if line contains "pc 0x"
    if [[ $line =~ pc\ (0x[0-9a-f]+) ]]; then
      local addr="${match[1]}"
      
      # Get the function name and location
      local result=$("$ADDR2LINE" -e "$SYMBOLS" -f -C -i "$addr" 2>/dev/null)
      
      # Check if we got a valid result (not just "??")
      if [[ $result != "??"* ]] && [[ ! -z "$result" ]]; then
        # Format: function name on first line, file:line on second
        local func_name=$(echo "$result" | head -n 1)
        local file_loc=$(echo "$result" | tail -n 1)
        
        echo "$line" >> "$OUTPUT"
        echo "  → $func_name" >> "$OUTPUT"
        echo "    at $file_loc" >> "$OUTPUT"
        echo "" >> "$OUTPUT"
      else
        # If symbolication failed, just print the original line
        echo "$line (no symbol found)" >> "$OUTPUT"
      fi
    elif [[ $line =~ ^[[:space:]]*at ]]; then
      # Java stack trace line, write as-is
      echo "$line" >> "$OUTPUT"
    fi
  done < "$STACKTRACE"

  echo "========================================"
  echo "Symbolication complete!"
  echo "Output written to: $OUTPUT"
}

function _conductor_worktree_path_allowed() {
  local workspace_path="$1"
  local roots="${CONDUCTOR_WORKTREE_ROOTS:-$HOME/conductor/workspaces:$HOME/Developer/apps/conductor/workspaces}"
  local root

  for root in "${(@s/:/)roots}"; do
    [[ -n "$root" && "$workspace_path" == "$root"/* ]] && return 0
  done

  return 1
}

function _conductor_worktree_git_state() {
  local repo_root="$1"
  local workspace_path="$2"

  git -C "$repo_root" worktree list --porcelain | awk -v target="$workspace_path" '
    $1 == "worktree" {
      in_block = ($0 == "worktree " target)
      if (in_block) found = 1
    }
    in_block && $1 == "locked" {
      locked = 1
    }
    END {
      if (!found) print "not-registered"
      else if (locked) print "locked"
      else print "ready"
    }
  '
}

function _conductor_worktree_symlinks() {
  local workspace_path="$1"
  local parent_dir link target

  parent_dir="$(dirname "$workspace_path")"
  [[ -d "$parent_dir" ]] || return 0

  while IFS= read -r link; do
    target="$(readlink "$link")"
    [[ "$target" == "$workspace_path" ]] && print -r -- "$link"
  done < <(find "$parent_dir" -maxdepth 1 -type l -print 2>/dev/null)

  return 0
}

function conductor_cleanup() {
  local repo_filter=""
  local db="${CONDUCTOR_DB_PATH:-$HOME/Library/Application Support/com.conductor.app/conductor.db}"
  local sep=$'\x1f'
  local sqlite_bin="${CONDUCTOR_SQLITE_BIN:-}"
  local trash_bin="${CONDUCTOR_TRASH_BIN:-}"
  local reset=$'\033[0m'
  local bold=$'\033[1m'
  local red=$'\033[31m'
  local green=$'\033[32m'
  local yellow=$'\033[33m'
  local cyan=$'\033[36m'
  local magenta=$'\033[35m'
  local gray=$'\033[90m'
  local arg

  for arg in "$@"; do
    case "$arg" in
      --force)
        echo "--force is no longer used; archived worktrees are included by default."
        return 1
        ;;
      --apply)
        echo "--apply is no longer used; conductor-cleanup prompts before moving files to Trash."
        return 1
        ;;
      -h|--help)
        echo "Usage: conductor-cleanup [repo-name-or-root]"
        echo ""
        echo "Shows archived Conductor worktrees, then prompts before moving worktree"
        echo "directories and descriptive symlinks to Trash."
        return 0
        ;;
      *)
        repo_filter="$arg"
        ;;
    esac
  done

  if [[ -z "$sqlite_bin" ]]; then
    if [[ -x /usr/bin/sqlite3 ]]; then
      sqlite_bin="/usr/bin/sqlite3"
    else
      sqlite_bin="$(command -v sqlite3 2>/dev/null)"
    fi
  fi

  if [[ -z "$trash_bin" ]]; then
    if [[ -x /usr/bin/trash ]]; then
      trash_bin="/usr/bin/trash"
    else
      trash_bin="$(command -v trash 2>/dev/null)"
    fi
  fi

  if [[ -z "$sqlite_bin" ]]; then
    echo "sqlite3 not found"
    return 1
  fi

  if [[ -z "$trash_bin" ]]; then
    echo "trash not found"
    return 1
  fi

  if [[ ! -f "$db" ]]; then
    echo "Conductor DB not found: $db"
    return 1
  fi

  echo "${bold}Archived Conductor worktrees:${reset}"

  local found=0
  local removable=0
  local skipped=0
  local gone=0
  local repo_root repo_name directory display_name branch workspace_path git_state status_line
  local dirty rows symlink_paths symlink_path cleanup_rows answer

  rows="$("$sqlite_bin" -noheader -separator "$sep" "$db" "
    SELECT r.root_path,
           r.name,
           w.directory_name,
           COALESCE(NULLIF(w.secondary_directory_name, ''), NULLIF(w.workspace_name, ''), ''),
           COALESCE(w.branch, ''),
           w.workspace_path
    FROM workspaces w
    JOIN repos r ON r.id = w.repository_id
    WHERE w.state = 'archived'
      AND w.workspace_path IS NOT NULL
    ORDER BY r.name, w.directory_name;
  ")" || {
    echo "Could not query Conductor DB: $db"
    return 1
  }

  while IFS="$sep" read -r repo_root repo_name directory display_name branch workspace_path; do
    [[ -z "$workspace_path" ]] && continue

    if [[ -n "$repo_filter" && "$repo_filter" != "$repo_name" && "$repo_filter" != "$repo_root" ]]; then
      continue
    fi

    found=$((found + 1))

    if [[ ! -d "$repo_root/.git" ]]; then
      status_line="$repo_name/$directory"
      [[ -n "$display_name" ]] && status_line="$status_line ${magenta}[$display_name]${reset}"
      echo "${yellow}skip:${reset} $status_line has missing repo root: ${cyan}$repo_root${reset}"
      skipped=$((skipped + 1))
      continue
    fi

    if [[ ! -e "$workspace_path" ]]; then
      status_line="$repo_name/$directory"
      [[ -n "$display_name" ]] && status_line="$status_line ${magenta}[$display_name]${reset}"

      git_state="$(_conductor_worktree_git_state "$repo_root" "$workspace_path")"
      if [[ "$git_state" == "not-registered" ]]; then
        echo "${gray}gone:${reset} $status_line is archived in Conductor, but the path and Git worktree entry are already gone"
      else
        echo "${yellow}prune:${reset} $status_line is archived but path is already gone"
      fi

      gone=$((gone + 1))
      continue
    fi

    if ! _conductor_worktree_path_allowed "$workspace_path"; then
      status_line="$repo_name/$directory"
      [[ -n "$display_name" ]] && status_line="$status_line ${magenta}[$display_name]${reset}"
      echo "${yellow}skip:${reset} $status_line is outside allowed worktree roots: ${cyan}$workspace_path${reset}"
      skipped=$((skipped + 1))
      continue
    fi

    git_state="$(_conductor_worktree_git_state "$repo_root" "$workspace_path")"

    if [[ "$git_state" == "not-registered" ]]; then
      status_line="$repo_name/$directory"
      [[ -n "$display_name" ]] && status_line="$status_line ${magenta}[$display_name]${reset}"
      echo "${yellow}skip:${reset} $status_line is not registered as a Git worktree: ${cyan}$workspace_path${reset}"
      skipped=$((skipped + 1))
      continue
    fi

    dirty="$(git -C "$workspace_path" status --porcelain 2>/dev/null)"

    status_line="${red}trash:${reset} $repo_name/$directory"
    [[ -n "$display_name" ]] && status_line="$status_line ${magenta}[$display_name]${reset}"
    [[ -n "$branch" ]] && status_line="$status_line ${cyan}($branch)${reset}"
    [[ "$git_state" == "locked" ]] && status_line="$status_line ${yellow}[locked]${reset}"
    [[ -n "$dirty" ]] && status_line="$status_line ${red}[dirty]${reset}"
    echo "$status_line ${gray}->${reset} ${cyan}$workspace_path${reset}"

    symlink_paths="$(_conductor_worktree_symlinks "$workspace_path")"
    if [[ -n "$symlink_paths" ]]; then
      while IFS= read -r symlink_path; do
        [[ -z "$symlink_path" ]] && continue
        echo "  ${magenta}symlink${reset} ${gray}->${reset} ${cyan}$symlink_path${reset}"
      done <<< "$symlink_paths"
    fi

    cleanup_rows="${cleanup_rows}${repo_root}${sep}${workspace_path}${sep}${git_state}"$'\n'
    removable=$((removable + 1))
  done <<< "$rows"

  if (( found == 0 )); then
    if [[ -n "$repo_filter" ]]; then
      echo "No archived Conductor worktrees found for: $repo_filter"
    else
      echo "No archived Conductor worktrees found."
    fi
    return 0
  fi

  echo "${bold}Summary:${reset} ${red}$removable removable${reset}, ${gray}$gone already gone${reset}, ${yellow}$skipped skipped${reset}."

  if (( removable == 0 )); then
    return 0
  fi

  printf "%sMove %d archived worktree(s) to Trash? [Y/n]%s " "$yellow" "$removable" "$reset"
  if ! read -r answer; then
    echo ""
    echo "No confirmation received; cancelled."
    return 1
  fi

  case "$answer" in
    ""|[yY]|[yY][eE][sS])
      ;;
    [nN]|[nN][oO])
      echo "${yellow}Cancelled.${reset}"
      return 0
      ;;
    *)
      echo "${yellow}Cancelled.${reset}"
      return 1
      ;;
  esac

  while IFS="$sep" read -r repo_root workspace_path git_state; do
    [[ -z "$workspace_path" ]] && continue

    if [[ "$git_state" == "locked" ]]; then
      git -C "$repo_root" worktree unlock "$workspace_path"
    fi

    symlink_paths="$(_conductor_worktree_symlinks "$workspace_path")"
    if [[ -n "$symlink_paths" ]]; then
      while IFS= read -r symlink_path; do
        [[ -z "$symlink_path" ]] && continue
        "$trash_bin" "$symlink_path"
      done <<< "$symlink_paths"
    fi

    "$trash_bin" "$workspace_path"
    git -C "$repo_root" worktree prune --expire now
  done <<< "$cleanup_rows"

  echo "${green}Done.${reset}"
}
