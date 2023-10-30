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
  ln -s $(realpath "${1-}") "${2-}"
}

# --------------------------------
# ------- 🔧 Basic set up --------
# --------------------------------

# Set up .gitconfig symlink
rm -f ~/.gitconfig && lns .gitconfig ~/

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
rm -f ~/.zshrc && lns .zshrc ~/

# Install starship
echo "🔧 Installing starship...\n"
brew install starship
rm -f ~/.config/starship.toml && lns starship.toml ~/.config/

# Install Fira Code
echo "🔧 Installing Fira Code font...\n"
brew tap homebrew/cask-fonts
brew install --cask font-fira-code

# Create Developer directory
mkdir -p ~/Developer

# --------------------------------
# --- 📦 Packages installation ---
# --------------------------------

# Install Java
echo "📦 Installing ytdl...\n"
brew install youtube-dl

# Install Java
echo "📦 Installing Java...\n"
brew install openjdk@8

# Install dart
echo "📦 Installing dart...\n"
brew tap dart-lang/dart
brew install dart

# Install fvm
echo "📦 Installing fvm...\n"
pub global activate fvm

# Install nvm
echo "📦 Installing pnpm...\n"
brew install node
brew install pnpm
pnpm env use --global latest

# Install Android Studio
echo "📦 Installing Android Studio...\n"
brew install --cask android-studio

# Install Hyper
echo "📦 Installing hyper...\n"
brew install --cask hyper
rm -f ~/.hyper.js && lns .hyper.js ~/.hyper.js

# Install Figma
echo "📦 Installing Figma...\n"
brew install --cask figma

# Install cocoapods
echo "📦 Installing cocoapods...\n"
# TODO: remove the need of using sudo
# https://guides.cocoapods.org/using/getting-started.html#getting-started
sudo gem install cocoapods

# XCode
echo "🚀 You're all set up!\n"
echo "To install XCode go to https://apps.apple.com/us/app/xcode/id497799835"
echo "You'll then need to run the following commands:\n"
echo "sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
echo "sudo xcodebuild -runFirstLaunch"
