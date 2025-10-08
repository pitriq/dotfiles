# Path to your oh-my-zsh installation.
export ZSH="/Users/pitriq/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

plugins=(git zsh-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# --------------------------------
# ---------- 👨🏻‍💻 Aliases ----------
# --------------------------------

source "$HOME/Developer/me/dotfiles/macOS/aliases.sh"

# --------------------------------
# --------- 🐙 Functions ---------
# --------------------------------

source "$HOME/Developer/me/dotfiles/macOS/functions.sh"

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
export PATH="$HOME/Library/Android/sdk/emulator":"$HOME/Library/Android/sdk/tools":"$HOME/Library/Android/sdk/platform-tools":"$PATH"

# Java
export JAVA_HOME=$(/usr/libexec/java_home -v 17)

## [Completion]
## Completion scripts setup. Remove the following line to uninstall
[[ -f $HOME/.dart-cli-completion/zsh-config.zsh ]] && . $HOME/.dart-cli-completion/zsh-config.zsh || true
## [/Completion]
