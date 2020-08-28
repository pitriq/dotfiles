export ZSH="/home/pitri/.oh-my-zsh"

# evan2 theme from https://github.com/EvanDarwin/evan2
ZSH_THEME="evan2"

fpath+=~/.zfunc

plugins=(git fast-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# scrcpy
alias cast="scrcpy -w -t"

mkdirc() {
	mkdir "$1" && cd "$1"
}

# creates a flutter project with fvm
#
# usage: fnew DESTINATION [-v VERSION]
# 
# where DESTINATION is the name of the flutter project 
# to be created and VERSION is the flutter version you wish
# to use (defaults to beta) 
fnew() {
    while getopts ":v" opt; do
      case $opt in
        v) VERSION=$OPTARG ;;
      esac
    done
        
    DESTINATION=${@:$OPTIND:1}
    
    mkdir $DESTINATION
    cd $DESTINATION

    if [ -n "$VERSION" ]; then
        fvm use $VERSION
    else
        fvm use beta
    fi
    
    mkdir .vscode
    touch .vscode/settings.json
    
    echo "{\n  \"dart.flutterSdkPaths\": [\n    \".fvm/flutter_sdk\"    \n  ],\n}" > .vscode/settings.json
    
    $(pwd)/fvm create .

    echo "\n#fvm\nfvm" >> .gitignore
}

APP_DIR="$HOME/.local"
export PATH="$APP_DIR/bin":/usr/local/bin:$PATH

# pyenv
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# dart
export PATH="$PATH:/usr/lib/dart/bin"
export PATH="$PATH":"$HOME/.pub-cache/bin"

# poetry
export PATH="$PATH":"$HOME/.poetry/bin"

# android
export PATH="$PATH":"$HOME/Android/Sdk/platform-tools"
export ADB="$HOME/Android/Sdk/platform-tools/adb"

# jabba
[ -s "$HOME/.jabba/jabba.sh" ] && source "$HOME/.jabba/jabba.sh"

# nvm
export NVM_DIR="$HOME/.nvm"
# nvm.sh runs `npm config get prefix` and thus, it's hella slow.
# using `--no-use` flag, the initialization is deferred.
# so anytime you want to use a node command, you must first call `nvm use default`
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use  # This loads nvm

# protocol buffers
PROTOBUF_PATH="$APP_DIR/protobuf"
export PATH="$PATH":"$PROTOBUF_PATH/bin":"$PROTOBUF_PATH/include"
