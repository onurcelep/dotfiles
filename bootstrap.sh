#!/bin/bash
set -euo pipefail

# Usage: bootstrap.sh [--shell bash|zsh]
#   --shell  Target login shell (default: prompt user)

TARGET_SHELL=""

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --shell)
      TARGET_SHELL="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: bootstrap.sh [--shell bash|zsh]"
      exit 1
      ;;
  esac
done

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

# --- Change shell ---
if [ -z "$TARGET_SHELL" ]; then
  echo ""
  echo "Which shell would you like as your default?"
  echo "  1) zsh"
  echo "  2) bash"
  echo "  3) Keep current ($SHELL)"
  printf "Choice [1/2/3]: "
  read -r choice
  case "$choice" in
    1) TARGET_SHELL="zsh" ;;
    2) TARGET_SHELL="bash" ;;
    *) TARGET_SHELL="" ;;
  esac
fi

if [ -n "$TARGET_SHELL" ]; then
  SHELL_PATH="$(command -v "$TARGET_SHELL" 2>/dev/null || true)"
  if [ -z "$SHELL_PATH" ]; then
    echo "==> $TARGET_SHELL not found, skipping shell change."
  elif [ "$(basename "$SHELL")" = "$TARGET_SHELL" ]; then
    echo "==> Already using $TARGET_SHELL, nothing to do."
  else
    echo "==> Changing default shell to $SHELL_PATH..."
    chsh -s "$SHELL_PATH"
    echo "==> Done! Log out and back in to start using $TARGET_SHELL."
  fi
else
  echo "==> Keeping current shell ($SHELL)."
fi

echo "==> Bootstrap complete."
