#! /bin/bash

# --- script setup ---
set -e # stop on errors
set -u # fail on unset variables

entryDir=$(dirname "$0")
pkginfoDir="$entryDir/pkginfo"
scriptsDir="$entryDir/scripts"

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

# --- installers ---
installPacman() {
  filePath=$pkginfoDir/$1.pacman
  if [[ -f "$filePath" ]]; then
    sudo pacman --needed --noconfirm -S - <$filePath
  fi
}

installYay() {
  filePath=$pkginfoDir/$1.yay
  if [[ -f "$filePath" ]]; then
    yay --needed --noconfirm --removemake --answerclean All --answeredit N --answerupgrade Y -S - <$filePath
  fi
}

install() {
  installPacman $1
  installYay $1
}

# --- start ---
installPersonal=$(ask "🔒 Install personal packages (only on your personal kits)?")

installGaming="0"

if [[ $installPersonal = "1" ]]; then
  installGaming=$(ask "🔒 Install gaming packages?")
fi

installToys=$(ask "🔒 Install extra (toy) packages?")

echo "💽 starting SSD trimming service..."
sudo systemctl enable fstrim.timer

# --- update ---
bash -c "$entryDir/update-local.sh"

# --- software installation ---
if hostnamectl | grep -qi 'tuxedo\|xmg\|clevo'; then
  echo "🖥️ detected TUXEDO / XMG / Clevo hardware, installing now..."
  install tuxedo
fi

echo "🛠️ installing common packages..."
install common

if [[ $installPersonal = "1" ]]; then
  echo "🤘 installing personal packages..."
  install personal
fi

if [[ $installGaming = "1" ]]; then
  echo "🎮 installing gaming packages..."
  install gaming
fi

if [[ $installToys = "1" ]]; then
  echo "🤡 installing toy packages..."
  install toys
fi
