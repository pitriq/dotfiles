#!/bin/bash
set -e

# --------------------------------
# --------- ⚙️ Utilities ---------
# --------------------------------

# macOS utility to emulate Linux's realpath
realpath() {
  ORIGIN_DIR=$(pwd)
  cd "$(dirname "$1")" 2>/dev/null || return 1
  LINK=$(readlink "$(basename "$1")")
  while [ "$LINK" ]; do
    cd "$(dirname "$LINK")"
    LINK=$(readlink "$(basename "$LINK")")
  done
  REALPATH="$PWD/$(basename "$1")"
  cd "$ORIGIN_DIR"
  echo "$REALPATH"
}

# Creates a symlink using an absolute path
lns () {
  ln -sfn "$(realpath "${1-}")" "${2-}"
}

# --------------------------------
# ------- 🔧 Basic set up --------
# --------------------------------

# Ensure we're in the correct directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Set up aliases and functions
mkdir -p ~/.config
lns aliases.sh ~/.config/aliases.sh
lns functions.sh ~/.config/functions.sh

# Install homebrew
echo "🔧 Installing Homebrew..."
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true

# Add Homebrew to PATH (for Apple Silicon Macs)
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Install zsh & oh-my-zsh
echo "🔧 Setting up Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc || true

# Set up .zshrc symlink (after oh-my-zsh to prevent overwrite)
lns .zshrc ~/.zshrc

# Set up .gitconfig symlink
lns .gitconfig ~/.gitconfig

# Install oh-my-zsh plugins
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
fi
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
fi

# Install starship
echo "🔧 Installing starship..."
brew install starship
mkdir -p ~/.config
lns starship.toml ~/.config/starship.toml

# System tweaks
# Finder: Show status bar and path bar
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true
# Finder: Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Create Developer directory
mkdir -p ~/Developer

# --------------------------------
# --- 📦 Packages installation ---
# --------------------------------

# Set up Brewfile symlink
lns Brewfile ~/Brewfile

# Install brew packages
echo "📦 Installing brew packages..."
brew bundle --file="$SCRIPT_DIR/Brewfile"

# Set up Java
echo "📦 Setting up Java..."
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk

# Set up fvm
echo "📦 Setting up fvm..."
fvm install stable && fvm global stable

# Set up Ghostty
echo "👻 Setting up Ghostty..."
mkdir -p ~/.config/ghostty
lns ghostty/config ~/.config/ghostty/config

# Set up shared agent config (AGENTS.md, skills, hooks)
echo "🤖 Setting up shared agent config..."
mkdir -p ~/.claude ~/.codex
lns agents/AGENTS.md ~/.claude/CLAUDE.md
lns agents/AGENTS.md ~/.codex/AGENTS.md
lns agents/hooks ~/.claude/hooks
lns agents/hooks ~/.codex/hooks
lns agents/skills ~/.claude/skills
# Codex manages ~/.codex/skills/.system itself, so we link individual skills
# rather than the whole directory.
mkdir -p ~/.codex/skills
for skill in agents/skills/*; do
  [ -d "$skill" ] || continue
  lns "$skill" ~/.codex/skills/"$(basename "$skill")"
done

# Set up Claude Code (Claude-specific config)
echo "🤖 Setting up Claude Code..."
lns claude/settings.json ~/.claude/settings.json
lns claude/statusline.sh ~/.claude/statusline.sh

# Set up Codex (Codex-specific config)
echo "🤖 Setting up Codex..."
lns codex/config.toml ~/.codex/config.toml

# Set wallpaper
echo "🖼️ Setting wallpaper..."
osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$SCRIPT_DIR/raven-ivan-belikov.webp\""

# XCode
echo "🚀 You're all set up!"
echo ""
echo "To install XCode go to https://apps.apple.com/us/app/xcode/id497799835"
echo "You'll then need to run the following commands:"
echo ""
echo "sudo xcode-select --install"
echo "sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
echo "sudo xcodebuild -runFirstLaunch"
echo "xcodebuild -downloadPlatform iOS"
