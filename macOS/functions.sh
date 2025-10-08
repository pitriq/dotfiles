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
  local STACKTRACE="$1"
  local SYMBOLS="$2"
  local OUTPUT="$3"

  if [[ -z "$STACKTRACE" || -z "$SYMBOLS" ]]; then
    echo "Usage: symbolicate <stacktrace.txt> <symbols_file> [output_file]"
    echo "If output_file is not given, it becomes <stacktrace>_symbolicated.txt"
    return 1
  fi

  [[ ! -f "$STACKTRACE" ]] && echo "Error: Stack trace not found: $STACKTRACE" && return 1
  [[ ! -f "$SYMBOLS" ]] && echo "Error: Symbols file not found: $SYMBOLS" && return 1

  [[ -z "$OUTPUT" ]] && OUTPUT="${STACKTRACE%.*}_symbolicated.txt"

  # Locate addr2line tool
  local ADDR2LINE=""
  local NDK_PATH="$HOME/Library/Android/sdk/ndk"
  [[ -d "$NDK_PATH" ]] && ADDR2LINE=$(find "$NDK_PATH" -name "llvm-addr2line" 2>/dev/null | head -n 1)
  [[ -z "$ADDR2LINE" && $(command -v llvm-addr2line) ]] && ADDR2LINE="llvm-addr2line"
  [[ -z "$ADDR2LINE" && $(command -v addr2line) ]] && ADDR2LINE="addr2line" && echo "Warning: Using system addr2line — may not work with Android ELF files"

  if [[ -z "$ADDR2LINE" ]]; then
    echo "Error: No addr2line found!"
    echo "Install either:"
    echo "  • Android NDK (contains llvm-addr2line)"
    echo "  • LLVM via Homebrew: brew install llvm"
    return 1
  fi

  echo "Using: $ADDR2LINE"
  echo "Input: $STACKTRACE"
  echo "Symbols: $SYMBOLS"
  echo "Output: $OUTPUT"
  echo "----------------------------------------"
  echo "Symbolicating..."

  > "$OUTPUT"

  while IFS= read -r line; do
    if [[ $line =~ pc\ (0x[0-9a-f]+) ]]; then
      local addr="${BASH_REMATCH[1]}"
      local result
      result=$("$ADDR2LINE" -e "$SYMBOLS" -f -C -i "$addr" 2>/dev/null)

      if [[ $result != "??"* && -n "$result" ]]; then
        local func_name=$(echo "$result" | head -n1)
        local file_loc=$(echo "$result" | tail -n1)
        {
          echo "$line"
          echo "  → $func_name"
          echo "    at $file_loc"
          echo
        } >> "$OUTPUT"
      else
        echo "$line (no symbol found)" >> "$OUTPUT"
      fi
    elif [[ $line =~ ^[[:space:]]*at ]]; then
      echo "$line" >> "$OUTPUT"
    fi
  done < "$STACKTRACE"

  echo "========================================"
  echo "Done! Output: $OUTPUT"
}
