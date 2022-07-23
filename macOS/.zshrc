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
# Usage: create_fvm_project DESTINATION [-v VERSION]
# 
# Where DESTINATION is the name of the flutter project 
# to be created and VERSION is the flutter version you wish
# to use (defaults to 'beta').
function create_fvm_project() {
  # Check if fvm is available
  if ! command -v fvm &> /dev/null
  then
      echo "fvm could not be found. Make sure it's installed and available."
      exit 1
  fi
  
  # Get the version parameter, if specified
  while getopts ":v" opt; do
    case $opt in
      v) VERSION=$OPTARG ;;
    esac
  done
      
  # Create the destination directory
  DESTINATION=${@:$OPTIND:1}
  mkdir -p $DESTINATION
  cd $DESTINATION

  # Setup fvm in the destination directory using VERSION
  if [ -n "$VERSION" ]; then
    fvm use $VERSION --force
  else
    fvm use beta --force
  fi

  # Create the actual project
  fvm flutter create .

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

# starship
eval "$(starship init zsh)"

# dart pub
export PATH="$PATH":"$HOME/.pub-cache/bin"

# Android
export PATH="$HOME/Library/Android/sdk/emulator":"$HOME/Library/Android/sdk/tools":"$HOME/Library/Android/sdk/platform-tools":"$PATH"

# Java
export JAVA_HOME=$(/usr/libexec/java_home)

# nvm
# from https://gist.github.com/fideloper/903f8976206fd6ca847c05f792ac9ea8
if [ -s "$HOME/.nvm/nvm.sh" ] && [ ! "$(type -w __init_nvm | awk '{print $2}')" = function ]; then
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  declare -a __node_commands=('nvm' 'node' 'npm' 'yarn' 'gulp' 'grunt' 'webpack')
  function __init_nvm() {
    for i in "${__node_commands[@]}"; do unalias $i; done
    . "$NVM_DIR"/nvm.sh
    unset __node_commands
    unset -f __init_nvm
  }
  for i in "${__node_commands[@]}"; do alias $i='__init_nvm && '$i; done
fi
