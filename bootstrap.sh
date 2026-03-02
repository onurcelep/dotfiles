#!/bin/bash
set -euo pipefail

echo "==> Bootstrapping dotfiles..."

# --- Prerequisites (Linux) ---
if [ "$(uname)" = "Linux" ]; then
  if ! command -v git >/dev/null || ! command -v curl >/dev/null; then
    echo "==> Installing prerequisites (curl, git)..."
    sudo apt-get update -qq
    sudo apt-get install -y curl git
  fi
fi

# --- Install chezmoi and apply dotfiles ---
echo "==> Installing chezmoi and applying dotfiles..."
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply onurcelep

# --- Change shell to zsh ---
if command -v zsh >/dev/null && [ "$(basename "$SHELL")" != "zsh" ]; then
  echo "==> Changing default shell to zsh..."
  chsh -s "$(which zsh)"
fi

echo "==> Done! Log out and back in (or run 'zsh') to start."
