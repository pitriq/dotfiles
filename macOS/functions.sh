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
