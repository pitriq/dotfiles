# Path to your oh-my-zsh installation.
export ZSH="/Users/pitri/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

plugins=(git zsh-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# --------------------------------
# ---------- 👨🏻‍💻 Aliases ----------
# --------------------------------

alias intel="arch -x86_64"
alias arm="arch -arm64"
alias ytdl="youtube-dl -x --audio-format mp3"
alias dev="cd $HOME/Developer"
alias sytex="cd $HOME/Developer/apps/sytex"
alias brewdump="brew bundle dump --formula --cask --tap"

# --------------------------------
# --------- 🐙 Functions ---------
# --------------------------------

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

# --------------------------------
# ---------- 🔧 Exports ----------
# --------------------------------

# homebrew
export PATH=/usr/local/bin:$PATH
eval "$(/opt/homebrew/bin/brew shellenv)"

# local binaries
export PATH="$HOME/.local/bin":"$PATH"

# starship
eval "$(starship init zsh)"

# dart pub
export PATH="$PATH":"$HOME/.pub-cache/bin"

# Android
export PATH="$HOME/Library/Android/sdk/emulator":"$HOME/Library/Android/sdk/tools":"$HOME/Library/Android/sdk/platform-tools":"$PATH"

# Java
export JAVA_HOME=$(/usr/libexec/java_home -v 11)
