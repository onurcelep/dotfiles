#!/bin/bash
set -euo pipefail

# Usage: bootstrap.sh [--repo domain/user/repo] [--shell bash|zsh]
#   --repo   Dotfiles repository (default: prompt user)
#   --shell  Target login shell (default: prompt user)
#
# For private repos, the script installs and authenticates with the
# appropriate CLI (gh for GitHub, glab for GitLab/self-hosted).

REPO=""
TARGET_SHELL=""

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="$2"
      shift 2
      ;;
    --shell)
      TARGET_SHELL="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: bootstrap.sh [--repo domain/user/repo] [--shell bash|zsh]"
      exit 1
      ;;
  esac
done

# --- Prompt for repo if not provided ---
if [ -z "$REPO" ]; then
  printf "Dotfiles repo (e.g. github.com/user/dotfiles): "
  read -r REPO
  if [ -z "$REPO" ]; then
    echo "Error: repository is required."
    exit 1
  fi
fi

REPO_DOMAIN="${REPO%%/*}"

echo "==> Bootstrapping dotfiles from ${REPO}..."

# --- Prerequisites (Linux) ---
if [ "$(uname)" = "Linux" ]; then
  NEEDED=""
  command -v curl >/dev/null || NEEDED="$NEEDED curl"
  command -v git >/dev/null  || NEEDED="$NEEDED git"
  if [ -n "$NEEDED" ]; then
    echo "==> Installing prerequisites:${NEEDED}..."
    sudo apt-get update -qq
    sudo apt-get install -y $NEEDED
  fi
fi

# --- Check if repo is accessible, authenticate if not ---
if ! git ls-remote "https://${REPO}.git" HEAD >/dev/null 2>&1; then
  echo "==> Repository not publicly accessible, setting up authentication..."

  install_github_cli() {
    if command -v gh >/dev/null; then return; fi
    echo "==> Installing GitHub CLI..."
    if [ "$(uname)" = "Linux" ]; then
      sudo mkdir -p -m 755 /etc/apt/keyrings
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update -qq
      sudo apt-get install -y gh
    elif [ "$(uname)" = "Darwin" ]; then
      brew install gh
    fi
  }

  install_gitlab_cli() {
    if command -v glab >/dev/null; then return; fi
    echo "==> Installing GitLab CLI..."
    if [ "$(uname)" = "Linux" ]; then
      ARCH=$(dpkg --print-architecture)
      GLAB_TAG=$(curl -fsSL "https://gitlab.com/api/v4/projects/34675721/releases/permalink/latest" \
        | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4)
      GLAB_VER="${GLAB_TAG#v}"
      GLAB_DEB=$(mktemp /tmp/glab-XXXXXX.deb)
      curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/${GLAB_TAG}/downloads/glab_${GLAB_VER}_linux_${ARCH}.deb" \
        -o "$GLAB_DEB"
      sudo dpkg -i "$GLAB_DEB"
      rm -f "$GLAB_DEB"
    elif [ "$(uname)" = "Darwin" ]; then
      brew install glab
    fi
  }

  case "$REPO_DOMAIN" in
    github.com)
      install_github_cli
      if ! gh auth status >/dev/null 2>&1; then
        echo "==> Logging in to GitHub..."
        gh auth login
      fi
      gh auth setup-git
      ;;
    *)
      install_gitlab_cli
      if ! glab auth status --hostname "$REPO_DOMAIN" >/dev/null 2>&1; then
        echo "==> Logging in to GitLab ($REPO_DOMAIN)..."
        glab auth login --hostname "$REPO_DOMAIN"
      fi
      glab auth setup-git --hostname "$REPO_DOMAIN"
      ;;
  esac
fi

# --- Install chezmoi and apply dotfiles ---
echo "==> Installing chezmoi and applying dotfiles..."
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply "https://${REPO}.git"

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
