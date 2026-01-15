#! /bin/bash

if [ ! -f ~/.config/nvim/init.lua ]; then
  echo "📝 installing lazyvim..."
  git clone https://github.com/LazyVim/starter ~/.config/nvim
fi

echo "⚙️ updating lazyvim..."
cd ~/.config/nvim && git pull
nvim --headless "+Lazy! sync" +qa
