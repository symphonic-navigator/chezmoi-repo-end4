#! /bin/bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=../lib.sh
source "$script_dir/../lib.sh"

nvim_dir="$HOME/.config/nvim"
starter_repo="https://github.com/LazyVim/starter"

if ! command -v nvim >/dev/null; then
  echo "⚠️ neovim not installed, skipping LazyVim update"
  exit 0
fi

if [[ ! -d "$nvim_dir" ]]; then
  if [[ "$USERSCRIPTS_DRY_RUN" == "1" ]]; then
    echo "[DRY-RUN] git clone $starter_repo $nvim_dir"
  else
    echo "📝 Installing LazyVim..."
    git clone "$starter_repo" "$nvim_dir"
  fi
fi

if [[ ! -d "$nvim_dir/.git" ]]; then
  echo "⚠️ $nvim_dir is not a git repository, skipping update"
  exit 0
fi

if [[ "$USERSCRIPTS_DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] cd $nvim_dir && git pull"
  echo "[DRY-RUN] nvim --headless '+Lazy! sync' +qa"
else
  echo "⚙️ Updating LazyVim..."
  cd "$nvim_dir" && git pull --ff-only

  echo "🔄 Syncing plugins..."
  nvim --headless "+Lazy! sync" +qa

  echo "✅ LazyVim updated"
fi
