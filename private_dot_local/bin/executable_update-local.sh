#! /bin/bash

# --- script setup ---
set -e # stop on errors
set -u # fail on unset variables

entryDir=$(dirname "$0")
scriptsDir="$entryDir/scripts"

# --- package update ---
echo "🌐 package update..."
sudo pacman -Syu --noconfirm || true
yay -Syu --noconfirm || true

# --- update lazyvim ---
bash -c "$scriptsDir/update-lazyvim.sh"

# --- chezmoi update ---
echo "🥐 updating chezmoi..."
chezmoi update
