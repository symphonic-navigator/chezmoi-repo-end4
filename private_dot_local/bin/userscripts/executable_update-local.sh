#! /bin/bash

# --- script setup ---
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
pkginfo_dir="$script_dir/pkginfo"
scripts_dir="$script_dir/scripts"
config_dir="$HOME/.config"
config_name="local-system.conf"
config_file="$config_dir/$config_name"
tmp_root="/tmp/install"
hyprwalz_repo="https://github.com/symphonic-navigator/hyprwalz.git"
hyprwalz_dir="$tmp_root/hyprwalz"
dots_repo="$HOME/repos/dots-hyprland"
dots_setup="$dots_repo/setup"
keychron_rules_dir="/etc/udev/rules.d"
keychron_rules_file="$keychron_rules_dir/99-keychron.rules"
journald_conf_dir="/etc/systemd/journald.conf.d"
journald_conf_file="$journald_conf_dir/volatile.conf"
skip_end4="0"
sync_sources="0"
skip_chezmoi="0"

usage() {
  echo "Usage: $0 [--quick] [--sync] [--nochezmoi]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --quick)
    skip_end4="1"
    shift
    ;;
  --sync)
    sync_sources="1"
    shift
    ;;
  --nochezmoi)
    skip_chezmoi="1"
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "❌ unknown option: $1"
    usage
    exit 1
    ;;
  esac
done

# --- installers ---
extract_packages() {
  grep -v -E '^[[:space:]]*#|^[[:space:]]*$' "$1"
}

installPacman() {
  local package_file
  package_file="$pkginfo_dir/$1.pacman"
  if [[ -f "$package_file" ]]; then
    extract_packages "$package_file" | sudo pacman --needed --noconfirm -S -
  fi
}

installYay() {
  local package_file
  package_file="$pkginfo_dir/$1.yay"
  if [[ -f "$package_file" ]]; then
    extract_packages "$package_file" | yay --needed --noconfirm --removemake --answerclean All --answeredit N --answerupgrade Y -S -
  fi
}

installFlatpak() {
  local package_file
  package_file="$pkginfo_dir/$1.flatpak"
  if [[ -f "$package_file" ]]; then
    extract_packages "$package_file" | xargs -r flatpak install --user -y --noninteractive
  fi
}

install() {
  installPacman "$1"
  installYay "$1"
  installFlatpak "$1"
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

# shellcheck source=/dev/null
source "$config_file"

# --- package source sync ---
if [[ $sync_sources = "1" ]]; then
  echo "🔄 syncing package sources..."
  sudo pacman -Sy --noconfirm || true
  yay -Sy --noconfirm || true
fi

# --- package update ---
echo "🌐 package update..."
sudo pacman -Syu --noconfirm || true
yay -Syu --noconfirm || true

# --- hyprwalz installation ---
echo "💻 installing hyprwalz..."
mkdir -p "$tmp_root"
rm -rf "$hyprwalz_dir"
git clone "$hyprwalz_repo" "$hyprwalz_dir"
bash -c "$hyprwalz_dir/install.sh"
rm -rf "$hyprwalz_dir"

# --- hardware installation ---
echo "💽 starting SSD trimming service..."
sudo systemctl enable fstrim.timer

if hostnamectl | grep -qi 'tuxedo\|xmg\|clevo'; then
  echo "🖥️ detected TUXEDO / XMG / Clevo hardware, installing now..."
  install tuxedo
fi

if command -v inxi >/dev/null && inxi -G | grep -iq nvidia; then
  echo "🔧 detected nvidia GPU, enabling nvidia-powerd..."
  sudo systemctl enable --now nvidia-powerd.service
fi

echo "⌨️ enabling chromium access to keychron devices..."
sudo mkdir -p "$keychron_rules_dir"
echo 'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", MODE+="0666"' | sudo tee "$keychron_rules_file"
sudo udevadm control --reload-rules
sudo udevadm trigger

# --- privacy setup ---
echo "🥷 volatile journald..."
sudo mkdir -p "$journald_conf_dir"
echo -e "[Journal]\nStorage=volatile\nRuntimeMaxUse=128M\nSystemMaxUse=0" | sudo tee "$journald_conf_file" >/dev/null
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

# --- nicing ---
echo "❤️ enabling ananicy..."
sudo systemctl enable --now ananicy-cpp

# --- sddm theme installation ---
echo "🎨 installing sddm themes..."
install sddm-themes

# --- update lazyvim ---
bash -c "$scripts_dir/update-lazyvim.sh"

# --- chezmoi update ---
if [[ $skip_chezmoi = "1" ]]; then
  echo "⏭️ skipping chezmoi update (--nochezmoi)"
else
  echo "🥐 updating chezmoi..."
  chezmoi add "$script_dir"
  chezmoi update --force
fi

# --- update end-4 dotfiles ---
if [[ $skip_end4 = "1" ]]; then
  echo "⏭️ skipping end-4 dotfiles update (--quick)"
else
  echo "🖥️ updating end-4 dotfiles..."
  if [[ -d "$dots_repo" && -x "$dots_setup" ]]; then
    pushd "$dots_repo"
    git stash -u || true
    git pull
    bash -c "UV_VENV_CLEAR=1 \"$dots_setup\" install -f --skip-sysupdate --skip-allgreeting --skip-miscconf --skip-fish --clean"
    popd
  else
    echo "⚠️ skipping end-4 dotfiles update (missing $dots_repo or $dots_setup)"
  fi
fi
