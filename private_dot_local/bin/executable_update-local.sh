#! /bin/bash

# --- script setup ---
set -euo pipefail

entryDir=$(dirname "$0")
pkginfoDir="$entryDir/pkginfo"
scriptsDir="$entryDir/scripts"

config_file="$HOME/.config/local-system.conf"

# --- installers ---
extract_packages() {
  grep -v -E '^[[:space:]]*#|^[[:space:]]*$' "$1"
}

installPacman() {
  local package_file
  package_file="$pkginfoDir/$1.pacman"
  if [[ -f "$package_file" ]]; then
    extract_packages "$package_file" | sudo pacman --needed --noconfirm -S -
  fi
}

installYay() {
  local package_file
  package_file="$pkginfoDir/$1.yay"
  if [[ -f "$package_file" ]]; then
    extract_packages "$package_file" | yay --needed --noconfirm --removemake --answerclean All --answeredit N --answerupgrade Y -S -
  fi
}

install() {
  installPacman "$1"
  installYay "$1"
}

# --- start ---
if [[ $EUID -eq 0 ]]; then
  echo "❌ do not run this script as root or sudo"
  exit 1
fi

if [[ ! -f "$config_file" ]]; then
  echo "❌ configuration file is missing - please run setup-local instead"
  exit 1
fi

command -v yay >/dev/null || {
  echo "❌ yay missing"
  exit 1
}

source "$config_file"

# --- package update ---
echo "🌐 package update..."
sudo pacman -Syu --noconfirm || true
yay -Syu --noconfirm || true

# --- hyprwalz installation ---
echo "💻 installing hyprwalz..."
mkdir -p "/tmp/install"
rm -rf "/tmp/install/hyprwalz"
git clone "https://github.com/symphonic-navigator/hyprwalz.git" "/tmp/install/hyprwalz"
bash -c "/tmp/install/hyprwalz/install.sh"
rm -rf "/tmp/install/hyprwalz"

# --- hardware installation ---
echo "💽 starting SSD trimming service..."
sudo systemctl enable fstrim.timer

if hostnamectl | grep -qi 'tuxedo\|xmg\|clevo'; then
  echo "🖥️ detected TUXEDO / XMG / Clevo hardware, installing now..."
  install tuxedo
fi

if inxi -G | grep -iq nvidia; then
  echo "🔧 detected nvidia GPU, enabling nvidia-powerd..."
  sudo systemctl enable --now nvidia-powerd.service
fi

echo "⌨️ enabling chromium access to keychron devices..."
sudo mkdir -p /etc/udev/rules.d
echo 'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/99-keychron.rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# --- privacy setup ---
echo "🥷 volatile journald..."
sudo mkdir -p /etc/systemd/journald.conf.d
echo -e "[Journal]\nStorage=volatile\nRuntimeMaxUse=128M\nSystemMaxUse=0" | sudo tee /etc/systemd/journald.conf.d/volatile.conf >/dev/null
sudo systemctl restart systemd-journald

# --- software installation ---
echo "🛠️ installing common packages..."
install common

if [[ $INSTALL_PERSONAL = "1" ]]; then
  echo "🤘 installing personal packages..."
  install personal
fi

if [[ $INSTALL_GAMING = "1" ]]; then
  echo "🎮 installing gaming packages..."
  install gaming
fi

if [[ $INSTALL_TOYS = "1" ]]; then
  echo "🤡 installing toy packages..."
  install toys
fi

# --- update lazyvim ---
bash -c "$scriptsDir/update-lazyvim.sh"

# --- chezmoi update ---
echo "🥐 updating chezmoi..."
chezmoi update --force

# --- update end-4 dotfiles ---
echo "🖥️ updating end-4 dotfiles..."
pushd ~/repos/dots-hyprland
git stash -u || true
git pull
bash -c "UV_VENV_CLEAR=1 ~/repos/dots-hyprland/setup install -f --skip-sysupdate --skip-allgreeting --skip-miscconf --skip-fish --clean"
popd
