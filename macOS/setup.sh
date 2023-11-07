# --------------------------------
# --------- ⚙️ Utilities ---------
# --------------------------------

# macOS utility to emulate Linux's realpath
realpath() {
  ORIGIN_DIR=$(pwd)
  cd "$(dirname "$1")"
  LINK=$(readlink "$(basename "$1")")
  while [ "$LINK" ]; do
    cd "$(dirname "$LINK")"
    LINK=$(readlink "$(basename "$1")")
  done
  REALPATH="$PWD/$(basename "$1")"
  cd "$ORIGIN_DIR"
  echo "$REALPATH"
}

# Creates a symlink using an absolute path
lns () {
  ln -sfn $(realpath "${1-}") "${2-}"
}

# --------------------------------
# ------- 🔧 Basic set up --------
# --------------------------------

# Set up .gitconfig symlink
lns .gitconfig ~/

# Install homebrew
echo "🔧 Installing Homebrew...\n"
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install zsh & oh-my-zsh
echo "🔧 Setting up Zsh...\n"
brew install zsh && \
chsh -s /usr/local/bin/zsh && \
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install oh-my-zsh plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Set up .zshrc symlink
lns .zshrc ~/

# Install starship
echo "🔧 Installing starship...\n"
brew install starship
lns starship.toml ~/.config/

# Create Developer directory
mkdir -p ~/Developer

# --------------------------------
# --- 📦 Packages installation ---
# --------------------------------

# Set up Brewfile symlink
lns Brewfile ~/

# Install brew packages
echo "📦 Installing brew packages...\n"
brew bundle install

# Set up Java
echo "📦 Setting up Java...\n"
lns /usr/local/opt/openjdk@11/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-11.jdk

# Set up pnpm
echo "📦 Setting up pnpm...\n"
pnpm env use --global latest

# Set up Hyper
echo "📦 Setting up hyper...\n"
rm -f ~/.hyper.js && lns .hyper.js ~/.hyper.js

# XCode
echo "🚀 You're all set up!\n"
echo "To install XCode go to https://apps.apple.com/us/app/xcode/id497799835"
echo "You'll then need to run the following commands:\n"
echo "sudo xcode-select --install"
echo "sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
echo "sudo xcodebuild -runFirstLaunch"
echo "xcodebuild -downloadPlatform iOS"
