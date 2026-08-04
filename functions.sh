#!/usr/bin/env zsh

# --------------------------------
# --------- 🐙 Functions ---------
# --------------------------------

function mov2mp4() {
  if (( $# < 1 || $# > 2 )); then
    echo "Usage: mov2mp4 INPUT.mov [CRF]"
    return 1
  fi

  local input="$1"
  local crf="${2:-24}"
  local output="${input%.*}.mp4"

  if [[ ! -f "$input" ]]; then
    echo "File not found: $input"
    return 1
  fi

  ffmpeg -hide_banner -n -i "$input" \
    -map 0:v:0 -map '0:a?' \
    -c:v libx264 \
    -preset medium \
    -crf "$crf" \
    -pix_fmt yuv420p \
    -fps_mode:v passthrough \
    -enc_time_base:v -1 \
    -c:a aac \
    -b:a 160k \
    -movflags +faststart \
    "$output"
}

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

function _work_cleanup_worktree_path_allowed() {
  local workspace_path="$1"
  local roots="${WORK_CLEANUP_WORKTREE_ROOTS:-$HOME/conductor/workspaces:$HOME/Developer/apps/conductor/workspaces:$HOME/.supacode/repos}"
  local root

  workspace_path="${workspace_path:A}"
  for root in "${(@s/:/)roots}"; do
    [[ -n "$root" ]] || continue
    while [[ "$root" != "/" && "$root" == */ ]]; do
      root="${root%/}"
    done
    root="${root:A}"
    [[ "$workspace_path" == "$root"/* ]] && return 0
  done

  return 1
}

function _work_cleanup_worktree_symlinks() {
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

function _work_cleanup_db_cleanup() {
  local sep=$'\x1f'
  local pg_container_override="${WORK_CLEANUP_PG_CONTAINER:-}"
  local pg_user="${WORK_CLEANUP_PG_USER:-postgres}"
  local reset=$'\033[0m'
  local bold=$'\033[1m'
  local red=$'\033[31m'
  local green=$'\033[32m'
  local yellow=$'\033[33m'
  local cyan=$'\033[36m'
  local gray=$'\033[90m'
  local repo_root repo_name
  local docker_ps container_name container existing_rows existing_db db_suffix size
  local workspace_line workspace_path workspace_name workspace_file db_name answer quoted_db key index
  local -A running_containers queried_containers existing_by_container
  local -A live_dbs seen_missing_containers seen_matches
  local -a repo_roots=("$@")
  local -a repo_names matched_containers matched_dbs matched_sizes

  command -v docker >/dev/null 2>&1 || return 0

  for repo_root in "${repo_roots[@]}"; do
    repo_name="$(basename "$repo_root")"
    repo_names+=("$repo_name")
  done

  if docker_ps="$(docker ps --format '{{.Names}}' 2>/dev/null)"; then
    while IFS= read -r container_name; do
      [[ -n "$container_name" ]] && running_containers[$container_name]=1
    done <<< "$docker_ps"
  fi

  for (( index = 1; index <= ${#repo_roots[@]}; index++ )); do
    repo_root="${repo_roots[$index]}"
    repo_name="${repo_names[$index]}"
    key="${repo_name}${sep}${repo_name}_${repo_name}"
    live_dbs[$key]=1

    while IFS= read -r workspace_line; do
      [[ "$workspace_line" == "worktree "* ]] || continue
      workspace_path="${workspace_line#worktree }"
      [[ -e "$workspace_path" ]] || continue

      workspace_file="$workspace_path/.workspace"
      if [[ -f "$workspace_file" ]]; then
        db_name="$(awk '/^[[:space:]]*dbName:[[:space:]]*/ { sub(/^[[:space:]]*dbName:[[:space:]]*/, ""); print; exit }' "$workspace_file" 2>/dev/null)"
        db_name="${db_name%$'\r'}"
      else
        workspace_name="$(basename "$workspace_path")"
        workspace_name="${(L)workspace_name}"
        workspace_name="${workspace_name//-/_}"
        db_name="${repo_name}_${workspace_name}"
      fi

      if [[ -n "$db_name" ]]; then
        key="${repo_name}${sep}${db_name}"
        live_dbs[$key]=1
      fi
    done < <(git -C "$repo_root" worktree list --porcelain 2>/dev/null)
  done

  for (( index = 1; index <= ${#repo_roots[@]}; index++ )); do
    repo_name="${repo_names[$index]}"
    container="${pg_container_override:-postgres_${repo_name}}"

    if [[ -z "${running_containers[$container]:-}" ]]; then
      if [[ -z "${seen_missing_containers[$container]:-}" ]]; then
        echo "${gray}db: $container not running; skipped database cleanup${reset}"
        seen_missing_containers[$container]=1
      fi
      continue
    fi

    if [[ -z "${queried_containers[$container]:-}" ]]; then
      queried_containers[$container]=1
      existing_rows="$(docker exec "$container" psql -U "$pg_user" -Atc "SELECT datname||'|'||pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE NOT datistemplate;" 2>/dev/null)" || existing_rows=""
      existing_by_container[$container]="$existing_rows"
    else
      existing_rows="${existing_by_container[$container]}"
    fi

    while IFS='|' read -r existing_db size; do
      [[ -z "$existing_db" ]] && continue
      [[ "$existing_db" == "${repo_name}_"* ]] || continue

      db_suffix="${existing_db#"${repo_name}_"}"
      [[ -z "$db_suffix" || "$db_suffix" == *[^A-Za-z0-9_]* ]] && continue

      key="${repo_name}${sep}${existing_db}"
      [[ -n "${live_dbs[$key]:-}" ]] && continue

      key="${container}${sep}${existing_db}"
      [[ -n "${seen_matches[$key]:-}" ]] && continue

      seen_matches[$key]=1
      matched_containers+=("$container")
      matched_dbs+=("$existing_db")
      matched_sizes+=("$size")
    done <<< "$existing_rows"
  done

  (( ${#matched_dbs[@]} == 0 )) && return 0

  echo "${bold}Orphaned workspace databases:${reset}"
  for (( index = 1; index <= ${#matched_dbs[@]}; index++ )); do
    echo "${red}drop:${reset} ${cyan}${matched_dbs[$index]}${reset} ${gray}(${matched_sizes[$index]})${reset}"
  done

  printf "%sDrop %d orphaned database(s)? [Y/n]%s " "$yellow" "${#matched_dbs[@]}" "$reset"
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

  for (( index = 1; index <= ${#matched_dbs[@]}; index++ )); do
    db_name="${matched_dbs[$index]}"
    container="${matched_containers[$index]}"
    quoted_db="${db_name//\"/\"\"}"

    if docker exec "$container" psql -U "$pg_user" -qc "DROP DATABASE \"$quoted_db\";"; then
      echo "${green}dropped:${reset} ${cyan}$db_name${reset}"
    else
      echo "${red}failed:${reset} ${cyan}$db_name${reset}"
    fi
  done

  echo "${green}Done.${reset}"
}

function _work_cleanup_deriveddata_cleanup() {
  local trash_bin="$1"
  local deriveddata_root="${WORK_CLEANUP_DERIVEDDATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData}"
  local reset=$'\033[0m'
  local bold=$'\033[1m'
  local red=$'\033[31m'
  local green=$'\033[32m'
  local yellow=$'\033[33m'
  local cyan=$'\033[36m'
  local gray=$'\033[90m'
  local entry info_plist workspace_path directory size answer index
  local -a stale_dirs stale_names stale_sizes stale_paths

  [[ -d "$deriveddata_root" ]] || return 0
  [[ -x /usr/libexec/PlistBuddy ]] || return 0

  while IFS= read -r entry; do
    info_plist="$entry/info.plist"
    [[ -f "$info_plist" ]] || continue

    workspace_path="$(/usr/libexec/PlistBuddy -c 'Print :WorkspacePath' "$info_plist" 2>/dev/null)" || continue
    [[ -n "$workspace_path" && ! -e "$workspace_path" ]] || continue

    directory="$(basename "$entry")"
    size="$(du -sh "$entry" 2>/dev/null)"
    size="${size%%[[:space:]]*}"
    stale_dirs+=("$entry")
    stale_names+=("$directory")
    stale_sizes+=("$size")
    stale_paths+=("$workspace_path")
  done < <(find "$deriveddata_root" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null)

  (( ${#stale_dirs[@]} == 0 )) && return 0

  echo "${bold}Stale DerivedData:${reset}"
  for (( index = 1; index <= ${#stale_dirs[@]}; index++ )); do
    echo "${red}trash:${reset} ${cyan}${stale_names[$index]}${reset} ${gray}(${stale_sizes[$index]}) ->${reset} ${cyan}${stale_paths[$index]}${reset}"
  done

  printf "%sMove %d stale DerivedData folder(s) to Trash? [Y/n]%s " "$yellow" "${#stale_dirs[@]}" "$reset"
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

  for (( index = 1; index <= ${#stale_dirs[@]}; index++ )); do
    if "$trash_bin" "${stale_dirs[$index]}"; then
      echo "${green}trashed:${reset} ${cyan}${stale_names[$index]}${reset}"
    else
      echo "${red}failed:${reset} ${cyan}${stale_names[$index]}${reset}"
    fi
  done

  echo "${green}Done.${reset}"
}

function work-cleanup {
  local repo_selector=""
  local configured_repos="${WORK_CLEANUP_REPOS:-}"
  local sep=$'\x1f'
  local trash_bin="${WORK_CLEANUP_TRASH_BIN:-}"
  local reset=$'\033[0m'
  local bold=$'\033[1m'
  local red=$'\033[31m'
  local yellow=$'\033[33m'
  local cyan=$'\033[36m'
  local gray=$'\033[90m'
  local common_dir candidate repo_root repo_name worktree_porcelain worktree_rows
  local workspace_path workspace_name branch locked age dirty status_line answer
  local symlink_paths symlink_path index worktree_index
  local -A seen_roots
  local -a configured_roots candidates repo_roots repo_names
  local -a worktree_paths worktree_branches worktree_locks

  if (( $# > 1 )); then
    echo "Usage: work-cleanup [repo-root-or-name]"
    return 1
  fi

  case "${1:-}" in
    -h|--help)
      echo "Usage: work-cleanup [repo-root-or-name]"
      echo ""
      echo "Stages:"
      echo "  0. Discover repositories from Git and WORK_CLEANUP_REPOS."
      echo "  1. Review linked worktrees and optionally move them to Trash."
      echo "  2. Find and optionally drop orphaned workspace PostgreSQL databases."
      echo "  3. Find and optionally trash stale Xcode DerivedData."
      echo ""
      echo "Worktree prompts default to No; database and DerivedData prompts default to Yes."
      echo ""
      echo "Environment:"
      echo "  WORK_CLEANUP_REPOS              Colon-separated repository roots."
      echo "  WORK_CLEANUP_WORKTREE_ROOTS     Colon-separated allowed worktree roots."
      echo "  WORK_CLEANUP_TRASH_BIN          trash executable override."
      echo "  WORK_CLEANUP_PG_CONTAINER       PostgreSQL container override."
      echo "  WORK_CLEANUP_PG_USER            PostgreSQL user (default: postgres)."
      echo "  WORK_CLEANUP_DERIVEDDATA_PATH   DerivedData root override."
      return 0
      ;;
    -*)
      echo "Unknown option: ${1:-}"
      return 1
      ;;
    *)
      repo_selector="${1:-}"
      ;;
  esac

  configured_roots=("${(@s/:/)configured_repos}")

  if [[ -n "$repo_selector" ]]; then
    if [[ -d "$repo_selector" ]]; then
      common_dir="$(git -C "$repo_selector" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
      if [[ -n "$common_dir" ]]; then
        common_dir="${common_dir:A}"
        if [[ "$common_dir" == */.git ]]; then
          candidates+=("${common_dir%/.git}")
        else
          candidates+=("$common_dir")
        fi
      fi
    else
      for candidate in "${configured_roots[@]}"; do
        [[ -n "$candidate" ]] || continue
        while [[ "$candidate" != "/" && "$candidate" == */ ]]; do
          candidate="${candidate%/}"
        done
        [[ "$(basename "$candidate")" == "$repo_selector" ]] && candidates+=("$candidate")
      done
    fi
  elif common_dir="$(git -C "$PWD" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
    common_dir="${common_dir:A}"
    if [[ "$common_dir" == */.git ]]; then
      candidates+=("${common_dir%/.git}")
    else
      candidates+=("$common_dir")
    fi
  else
    candidates=("${configured_roots[@]}")
  fi

  for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" ]] || continue
    while [[ "$candidate" != "/" && "$candidate" == */ ]]; do
      candidate="${candidate%/}"
    done
    candidate="${candidate:A}"
    [[ -e "$candidate/.git" ]] || continue
    [[ -n "${seen_roots[$candidate]:-}" ]] && continue

    seen_roots[$candidate]=1
    repo_roots+=("$candidate")
    repo_names+=("$(basename "$candidate")")
  done

  if (( ${#repo_roots[@]} == 0 )); then
    echo "${red}No Git repositories found.${reset}"
    return 1
  fi

  if [[ -z "$trash_bin" ]]; then
    if [[ -x /usr/bin/trash ]]; then
      trash_bin="/usr/bin/trash"
    else
      trash_bin="$(command -v trash 2>/dev/null)"
    fi
  fi

  if [[ -z "$trash_bin" ]]; then
    echo "trash not found"
    return 1
  fi

  for (( index = 1; index <= ${#repo_roots[@]}; index++ )); do
    repo_root="${repo_roots[$index]}"
    repo_name="${repo_names[$index]}"
    echo "${bold}Worktrees for $repo_name:${reset}"

    if ! worktree_porcelain="$(git -C "$repo_root" worktree list --porcelain 2>/dev/null)"; then
      echo "${red}Could not list worktrees for: $repo_root${reset}"
      return 1
    fi

    worktree_rows="$(print -r -- "$worktree_porcelain" | awk -v sep="$sep" '
      function emit() {
        if (path != "") print path sep branch sep locked
      }
      $1 == "worktree" {
        emit()
        path = substr($0, 10)
        branch = "detached"
        locked = 0
        next
      }
      $1 == "branch" {
        branch = substr($0, 8)
        sub(/^refs\/heads\//, "", branch)
        next
      }
      $1 == "locked" {
        locked = 1
      }
      END {
        emit()
      }
    ' | LC_ALL=C sort)"

    worktree_paths=()
    worktree_branches=()
    worktree_locks=()
    while IFS="$sep" read -r workspace_path branch locked; do
      [[ -n "$workspace_path" ]] || continue
      worktree_paths+=("$workspace_path")
      worktree_branches+=("$branch")
      worktree_locks+=("$locked")
    done <<< "$worktree_rows"

    for (( worktree_index = 1; worktree_index <= ${#worktree_paths[@]}; worktree_index++ )); do
      workspace_path="${worktree_paths[$worktree_index]}"
      branch="${worktree_branches[$worktree_index]}"
      locked="${worktree_locks[$worktree_index]}"
      [[ -n "$workspace_path" && "$workspace_path" != "$repo_root" ]] || continue

      if [[ ! -e "$workspace_path" ]]; then
        if (( locked )); then
          git -C "$repo_root" worktree unlock "$workspace_path" >/dev/null 2>&1
        fi
        git -C "$repo_root" worktree prune --expire now >/dev/null 2>&1
        echo "${gray}prune: $workspace_path registered but missing; pruned${reset}"
        continue
      fi

      if ! _work_cleanup_worktree_path_allowed "$workspace_path"; then
        echo "${yellow}skip: $workspace_path is outside allowed worktree roots${reset}"
        continue
      fi

      workspace_name="$(basename "$workspace_path")"
      age="$(git -C "$workspace_path" log -1 --format=%cr 2>/dev/null)"
      dirty="$(git -C "$workspace_path" status --porcelain 2>/dev/null)"
      status_line="${cyan}${workspace_name}${reset} $branch ${gray}${age:-no commits}${reset}"
      [[ -n "$dirty" ]] && status_line="$status_line ${red}[dirty]${reset}"
      (( locked )) && status_line="$status_line ${yellow}[locked]${reset}"
      echo "$status_line ${gray}-> $workspace_path${reset}"

      printf "%sTrash worktree %s? [y/N]%s " "$yellow" "$workspace_name" "$reset"
      if ! read -r answer; then
        echo ""
        echo "No confirmation received; cancelled."
        return 1
      fi

      case "${(L)answer}" in
        y|yes)
          ;;
        *)
          continue
          ;;
      esac

      if (( locked )); then
        git -C "$repo_root" worktree unlock "$workspace_path"
      fi

      symlink_paths="$(_work_cleanup_worktree_symlinks "$workspace_path")"
      if [[ -n "$symlink_paths" ]]; then
        while IFS= read -r symlink_path; do
          [[ -n "$symlink_path" ]] && "$trash_bin" "$symlink_path"
        done <<< "$symlink_paths"
      fi

      "$trash_bin" "$workspace_path"
      git -C "$repo_root" worktree prune --expire now
      echo "${gray}branch $branch kept${reset}"
    done
  done

  _work_cleanup_db_cleanup "${repo_roots[@]}" || return 1
  _work_cleanup_deriveddata_cleanup "$trash_bin"
}
