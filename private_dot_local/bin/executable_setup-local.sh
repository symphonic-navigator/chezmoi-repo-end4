#! /bin/bash

# --- script setup ---
set -euo pipefail

entryDir=$(dirname "$0")
pkginfoDir="$entryDir/pkginfo"
scriptsDir="$entryDir/scripts"

mkdir -p "$HOME/.config"

# --- interactive functions ---
ask() {
  local prompt="$1"
  local answer
  read -p "$prompt [y/N]: " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "1"
  else
    echo "0"
  fi
}

# --- start ---

if [[ $EUID -eq 0 ]]; then
  echo "❌ do not run this script as root or sudo"
  exit 1
fi

config_file="$HOME/.config/local-system.conf"

if [[ -f "$config_file" ]]; then
  rm "$config_file" || true
fi

installPersonal=$(ask "🔒 Install personal packages (only on your personal kits)?")

installGaming="0"

if [[ $installPersonal = "1" ]]; then
  installGaming=$(ask "🔒 Install gaming packages?")
fi

installToys=$(ask "🔒 Install extra (toy) packages?")

echo "INSTALL_PERSONAL=$installPersonal" >"$config_file"
echo "INSTALL_GAMING=$installGaming" >>"$config_file"
echo "INSTALL_TOYS=$installToys" >>"$config_file"

# --- update ---
bash -c "$entryDir/update-local.sh"
