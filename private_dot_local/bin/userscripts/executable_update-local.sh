#! /bin/bash

# --- script setup ---
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

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

# --- System detection ---
. /etc/os-release

is_cachyos=false

if [[ "${ID:-}" == "cachyos" ]]; then
  is_cachyos=true
elif [[ " ${ID_LIKE:-} " == *" cachyos "* ]]; then
  is_cachyos=true
fi

if $is_cachyos; then
  echo "🤩 CachyOS detected!"
else
  echo "🖥️ system detected: ${ID:-}"
fi

# --- Options ---
skip_end4="0"
skip_chezmoi="0"
force_update="0"

usage() {
  echo "Usage: $0 [--quick] [--nochezmoi] [--verbose|-v] [--dry-run] [--help]"
  echo ""
  echo "Options:"
  echo "  --quick         Skip end-4 dotfiles update"
  echo "  --nochezmoi     Skip chezmoi update"
  echo "  --force-update  Forces update via pacman and yay"
  echo "  --verbose,-v    Enable verbose output"
  echo "  --dry-run       Don't make changes (simulation)"
  echo "  --help,-h       Show this help"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --quick)
    skip_end4="1"
    shift
    ;;
  --nochezmoi)
    skip_chezmoi="1"
    shift
    ;;
  --verbose | -v)
    USERSCRIPTS_VERBOSE="1"
    shift
    ;;
  --force-update)
    force_update="1"
    shift
    ;;
  --dry-run)
    USERSCRIPTS_DRY_RUN="1"
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "❌ Unknown option: $1"
    usage
    exit 1
    ;;
  esac
done

# --- Initialization ---
error_handler_init
log_init "update-local"
require_no_root
lock_acquire "update-local"

if [[ ! -f "$config_file" ]]; then
  die "Configuration file missing - please run setup-local first"
fi

command -v yay >/dev/null || die "yay missing"
command -v checkupdates >/dev/null || die "checkupdates missing"

requires_pacman_updates=false
requires_yay_updates=false

if checkupdates >/dev/null 2>&1; then
  requires_pacman_updates=true
  echo "⚙️ requires pacman updates"
fi

if yay -Qua >/dev/null 2>&1; then
  requires_yay_updates=true
  echo "⚙️ requires yay updates"
fi

# shellcheck source=/dev/null
source "$config_file"

# --- Start sudo keepalive ---
sudo_keepalive_start

# --- installers ---
installPacman() {
  local package_file
  package_file="$pkginfo_dir/$1.pacman"
  if [[ -f "$package_file" ]]; then
    log "Installing pacman packages from $package_file"
    if [[ "$USERSCRIPTS_DRY_RUN" != "1" ]]; then
      extract_packages "$package_file" | sudo pacman --needed --noconfirm -S - || {
        log "Pacman installation had errors (ignored)"
        warn "Some pacman packages could not be installed"
      }
    else
      echo "[DRY-RUN] pacman -S $(extract_packages "$package_file" | tr '\n' ' ')"
    fi
  fi
}

installYay() {
  local package_file
  package_file="$pkginfo_dir/$1.yay"
  if [[ -f "$package_file" ]]; then
    log "Installing AUR packages from $package_file"
    if [[ "$USERSCRIPTS_DRY_RUN" != "1" ]]; then
      extract_packages "$package_file" | yay --needed --noconfirm --removemake --answerclean All --answeredit N --answerupgrade Y -S - || {
        log "Yay installation had errors (ignored)"
        warn "Some AUR packages could not be installed"
      }
    else
      echo "[DRY-RUN] yay -S $(extract_packages "$package_file" | tr '\n' ' ')"
    fi
  fi
}

installFlatpak() {
  local package_file
  package_file="$pkginfo_dir/$1.flatpak"
  if [[ -f "$package_file" ]]; then
    log "Installing Flatpak packages from $package_file"
    if [[ "$USERSCRIPTS_DRY_RUN" != "1" ]]; then
      extract_packages "$package_file" | xargs -r flatpak install --user -y --noninteractive || {
        log "Flatpak installation had errors (ignored)"
        warn "Some Flatpak packages could not be installed"
      }
    else
      echo "[DRY-RUN] flatpak install $(extract_packages "$package_file" | tr '\n' ' ')"
    fi
  fi
}

install() {
  installPacman "$1"
  installYay "$1"
  installFlatpak "$1"
}

# --- package update ---
info "🌐 Package update..."
if [[ "$USERSCRIPTS_DRY_RUN" != "1" ]]; then
  if $requires_pacman_updates; then
    sudo pacman -Syu --noconfirm || {
      log "Pacman update had errors"
      warn "Pacman update not fully completed"
    }
  else
    echo "✅ no pacman updates required"
  fi

  if $requires_yay_updates; then
    yay -Syu --noconfirm || {
      log "Yay update had errors"
      warn "Yay update not fully completed"
    }
  else
    echo "✅ no yay updates required"
  fi
else
  echo "[DRY-RUN] pacman -Syu"
  echo "[DRY-RUN] yay -Syu"
fi

# --- hyprwalz installation ---
info "💻 Installing hyprwalz..."
mkdir -p "$tmp_root"
rm -rf "$hyprwalz_dir"
if [[ "$USERSCRIPTS_DRY_RUN" != "1" ]]; then
  git clone "$hyprwalz_repo" "$hyprwalz_dir"
  bash -c "$hyprwalz_dir/install.sh"
  rm -rf "$hyprwalz_dir"
else
  echo "[DRY-RUN] git clone $hyprwalz_repo"
fi

# --- hardware installation ---
info "💽 Enabling SSD trimming service..."
sudo_cmd systemctl enable fstrim.timer

if hostnamectl | grep -qi 'tuxedo\|xmg\|clevo'; then
  info "🖥️ TUXEDO / XMG / Clevo hardware detected, installing..."
  install tuxedo
fi

if command -v inxi >/dev/null && inxi -G | grep -iq nvidia; then
  info "🔧 Nvidia GPU detected, enabling nvidia-powerd..."
  sudo_cmd systemctl enable --now nvidia-powerd.service
fi

# --- Keychron Rules (atomic write) ---
info "⌨️ Enabling Keychron access for Chromium..."

GROUP="input"
USER_NAME="${SUDO_USER:-$USER}"

if ! getent group "$GROUP" >/dev/null; then
  echo "Creating group: $GROUP"
  groupadd "$GROUP"
else
  echo "Group $GROUP already exists"
fi

if id -nG "$USER_NAME" | grep -qw "$GROUP"; then
  echo "User $USER_NAME already in group $GROUP"
else
  echo "Adding user $USER_NAME to group $GROUP"
  usermod -aG "$GROUP" "$USER_NAME"
  echo "NOTE: User must log out/in for group change to take effect"
fi

keychron_rules='SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", MODE="0660", GROUP="input"'
if [[ "$USERSCRIPTS_DRY_RUN" != "1" ]]; then
  sudo mkdir -p "$keychron_rules_dir"
  if atomic_write "$keychron_rules_file" "$keychron_rules" 1; then
    sudo_cmd udevadm control --reload-rules
    sudo_cmd udevadm trigger
    info "✅ Keychron rules updated"
  else
    log "Keychron rules unchanged"
  fi
else
  echo "[DRY-RUN] Write Keychron rules to $keychron_rules_file"
fi

# --- privacy setup (atomic write) ---
info "🥷 Volatile journald..."
journald_conf="[Journal]
Storage=volatile
RuntimeMaxUse=128M
SystemMaxUse=0"
if [[ "$USERSCRIPTS_DRY_RUN" != "1" ]]; then
  sudo mkdir -p "$journald_conf_dir"
  if atomic_write "$journald_conf_file" "$journald_conf" 1; then
    sudo_cmd systemctl restart systemd-journald
    info "✅ journald configuration updated"
  else
    log "journald configuration unchanged"
  fi
else
  echo "[DRY-RUN] Write journald configuration to $journald_conf_file"
fi

# --- software installation ---
info "🛠️ Installing common packages..."
install common

if [[ "${INSTALL_PERSONAL:-0}" = "1" ]]; then
  info "🤘 Installing personal packages..."
  install personal
fi

if [[ "${INSTALL_GAMING:-0}" = "1" ]]; then
  info "🎮 Installing gaming packages..."
  install gaming

  if $is_cachyos; then
    echo "🤩 CachyOS detected - installing cachyos-gaming-meta..."
    sudo pacman -S --needed cachyos-gaming-meta
  fi
fi

if [[ "${INSTALL_TOYS:-0}" = "1" ]]; then
  info "🤡 Installing toy packages..."
  install toys
fi

# --- nicing ---
info "❤️ Enabling ananicy..."
sudo_cmd systemctl enable --now ananicy-cpp

# --- sddm theme installation ---
info "🎨 Installing SDDM themes..."
install sddm-themes

# --- update lazyvim ---
bash -c "$scripts_dir/update-lazyvim.sh"

# --- chezmoi update ---
if [[ $skip_chezmoi = "1" ]]; then
  info "⏭️ chezmoi update skipped (--nochezmoi)"
else
  info "🥐 Updating chezmoi..."
  if [[ "$USERSCRIPTS_DRY_RUN" != "1" ]]; then
    chezmoi add "$script_dir"
    chezmoi update --force
  else
    echo "[DRY-RUN] chezmoi add && chezmoi update --force"
  fi
fi

# --- tldr update ---
info "📘 Updating tldr..."
tldr --update

# --- update end-4 dotfiles ---
if [[ $skip_end4 = "1" ]]; then
  info "⏭️ end-4 dotfiles update skipped (--quick)"
else
  info "🖥️ Updating end-4 dotfiles..."
  if [[ -d "$dots_repo" && -x "$dots_setup" ]]; then
    if [[ "$USERSCRIPTS_DRY_RUN" == "1" ]]; then
      echo "[DRY-RUN] cd $dots_repo"
      echo "[DRY-RUN] git stash --include-untracked --all"
      echo "[DRY-RUN] git pull --ff-only"
      echo "[DRY-RUN] UV_VENV_CLEAR=1 $dots_setup install -f --skip-sysupdate --skip-allgreeting --skip-miscconf --skip-fish --clean"
    else
      # Safe pushd/popd with error handling
      if pushd "$dots_repo" >/dev/null 2>&1; then
        # Force git stash - save all changes
        git stash --include-untracked --all --quiet || {
          # If stash fails, try reset
          log "git stash failed, trying reset"
          git checkout -- . 2>/dev/null || true
          git clean -fd 2>/dev/null || true
        }

        git pull --ff-only || {
          warn "git pull failed, trying reset to origin"
          git fetch origin
          git reset --hard origin/main || git reset --hard origin/master || true
        }

        UV_VENV_CLEAR=1 "$dots_setup" install -f --skip-sysupdate --skip-allgreeting --skip-miscconf --skip-fish --clean

        popd >/dev/null 2>&1 || true
      else
        warn "Could not change to $dots_repo"
      fi
    fi
  else
    warn "end-4 dotfiles update skipped (missing: $dots_repo or $dots_setup)"
  fi
fi

info "✅ Update completed!"
notify_done "Update completed" "System update completed successfully"
