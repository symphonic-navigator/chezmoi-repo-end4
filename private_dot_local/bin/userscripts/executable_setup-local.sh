#! /bin/bash

# --- script setup ---
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

config_dir="$HOME/.config"
config_name="local-system.conf"
config_file="$config_dir/$config_name"
update_script="$script_dir/update-local.sh"
hf_dir="$HOME/hf"

# --- Argument parsing ---
remaining_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v)
      USERSCRIPTS_VERBOSE="1"
      shift
      ;;
    --dry-run)
      USERSCRIPTS_DRY_RUN="1"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--verbose|-v] [--dry-run] [--help]"
      exit 0
      ;;
    *)
      remaining_args+=("$1")
      shift
      ;;
  esac
done
set -- "${remaining_args[@]}"

# --- Initialization ---
error_handler_init
log_init "setup-local"
require_no_root

mkdir -p "$config_dir"
mkdir -p "$hf_dir"

# --- yay installation ---
install_yay() {
  info "📦 Installing yay..."

  local tmp_dir="/tmp/yay-install"
  rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"

  log_cmd sudo pacman -S --noconfirm --needed base-devel git

  git clone https://aur.archlinux.org/yay.git "$tmp_dir"
  (cd "$tmp_dir" && makepkg -si --noconfirm)

  rm -rf "$tmp_dir"
  info "✅ yay installed"
}

if ! command -v yay >/dev/null; then
  info "⚠️ yay not found, installing..."
  install_yay
fi

# --- Config migration ---
if [[ -f "$config_file" ]]; then
  echo ""
  echo "📄 Existing configuration found:"
  echo "---"
  cat "$config_file"
  echo "---"
  echo ""

  if ask_confirm "Keep configuration?"; then
    info "✅ Keeping configuration"
    # shellcheck source=/dev/null
    source "$config_file"

    # Continue to update
    bash "$update_script" "$@"
    exit 0
  else
    info "🔄 Creating new configuration..."
  fi
fi

# --- Interactive prompts ---
installPersonal=$(ask "🔒 Install personal packages (only on your own devices)?")

installGaming="0"
if [[ $installPersonal = "1" ]]; then
  installGaming=$(ask "🎮 Install gaming packages?")
fi

installToys=$(ask "🤡 Install extra (toy) packages?")

# --- Write config ---
{
  echo "INSTALL_PERSONAL=$installPersonal"
  echo "INSTALL_GAMING=$installGaming"
  echo "INSTALL_TOYS=$installToys"
} > "$config_file"

info "✅ Configuration saved: $config_file"

# --- ssh agent ---
info "🔑 Setting up ssh-agent..."

systemctl --user daemon-reload
systemctl --user daemon-reexec

systemctl --user enable --now ssh-agent.service

loginctl enable-linger "$USER"

info "✅ ssh-agent user service set up and running."

# --- prerequisites ---
info "❕ Installing prerequisites..."

log_cmd sudo pacman -S --noconfirm --needed flatpak
log_cmd yay -S --noconfirm --needed pyprland

# Flatpak with retry
retry 3 5 flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# --- installing docker ---
info "🐋 Installing Docker..."
log_cmd sudo pacman -S --noconfirm --needed docker docker-compose

# create docker group (idempotent)
if ! getent group docker >/dev/null; then
  log_cmd sudo groupadd docker
fi

# add user to group
if ! groups "$USER" | grep -qw docker; then
  log_cmd sudo usermod -aG docker "$USER"
fi

log_cmd sudo systemctl enable --now docker
info "ℹ️ docker group membership requires logout/login (or: newgrp docker)"

# --- update ---
bash "$update_script" "$@"

notify_done "Setup completed" "System setup completed successfully"
