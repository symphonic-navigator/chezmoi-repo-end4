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

# --- update end-4 dotfiles ---
echo "🖥️ updating end-4 dotfiles..."
pushd ~/dots-hyprland
git stash
git pull
bash -c "UV_VENV_CLEAR=1 ~/dots-hyprland/setup install -f --skip-sysupdate --skip-allgreeting --skip-miscconf --skip-fish --clean"

# --- update lazyvim ---
bash -c "$scriptsDir/update-lazyvim.sh"

# --- chezmoi update ---
echo "🥐 updating chezmoi..."
chezmoi update --force
