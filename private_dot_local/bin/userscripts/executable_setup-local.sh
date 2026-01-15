#! /bin/bash

# --- script setup ---
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
config_dir="$HOME/.config"
config_name="local-system.conf"
config_file="$config_dir/$config_name"
update_script="$script_dir/update-local.sh"

mkdir -p "$config_dir"

# --- interactive functions ---
ask() {
	local prompt="$1"
	local answer
	read -r -p "$prompt [y/N]: " answer
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

# --- ssh agent ---
echo "🔑 starting ssh agent..."

systemctl --user daemon-reexec
systemctl --user daemon-reload

systemctl --user enable --now ssh-agent.service

loginctl enable-linger "$USER"

echo "✅ ssh-agent user service set up and running."

# --- prerequisites ---
echo "❕preparing installation of the system (prerequisites)..."

sudo pacman -S --noconfirm --needed flatpak
yay -S --noconfirm --needed pyprland
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# --- installing docker ---
echo "🐋 installing docker..."
sudo pacman -S --noconfirm --needed docker docker-compose
sudo groupadd docker || true
sudo usermod -aG docker $USER || true

# --- update ---
bash -c "$update_script"
