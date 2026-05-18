# Path to your oh-my-zsh installation.
export ZSH="/Users/pitriq/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

plugins=(git zsh-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# --------------------------------
# ---------- 👨🏻‍💻 Aliases ----------
# --------------------------------

source "$HOME/.config/aliases.sh"

# --------------------------------
# --------- 🐙 Functions ---------
# --------------------------------

source "$HOME/.config/functions.sh"

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

# fvm default flutter sdk
export PATH="$PATH":"$HOME/fvm/default/bin"

# shorebird
export PATH="$HOME/.shorebird/bin":"$PATH"

# Android
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/emulator":"$ANDROID_HOME/tools":"$ANDROID_HOME/platform-tools":"$PATH"

# Java
export JAVA_HOME=$(/usr/libexec/java_home -v 17)

# Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

## [Completion]
## Completion scripts setup. Remove the following line to uninstall
[[ -f $HOME/.dart-cli-completion/zsh-config.zsh ]] && . $HOME/.dart-cli-completion/zsh-config.zsh || true
## [/Completion]
