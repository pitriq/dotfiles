#!/usr/bin/env zsh

# --------------------------------
# ---------- 👨🏻‍💻 Aliases ----------
# --------------------------------

alias ytdl="yt-dlp -x --audio-format mp3"
alias flac2mp3='flac2mp3_func() { ffmpeg -i "$1" -b:a 320k "${1%.*}.mp3"; }; flac2mp3_func'
alias dev="cd $HOME/Developer"
alias dots="cd $HOME/Developer/me/dotfiles"
alias work="cd $HOME/Developer/apps/sytex"
alias dl="cd $HOME/Downloads"
alias brewdump="brew bundle dump --formula --cask --tap"
alias baptise="sudo xattr -d com.apple.quarantine"
alias code="cursor"
