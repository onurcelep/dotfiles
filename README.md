# Dotfiles

Shell and tool configuration managed by [chezmoi](https://www.chezmoi.io/).

## What's tracked

| File | Purpose |
|------|---------|
| `.zshrc` | Zsh interactive config — completions, keybindings, plugin loading |
| `.zshenv` | Zsh environment (machine-local env goes in `.zshenv.local`) |
| `run_onchange_after_brew-bundle.sh.tmpl` | Auto-installs Homebrew packages on macOS via `brew bundle` |
| `run_onchange_after_apt-install.sh.tmpl` | Auto-installs apt packages + tools on Debian/Ubuntu Linux |
| `.zprofile` | Zsh login — pipx PATH |
| `.bashrc` | Bash interactive config — completions, prompt |
| `.shell_common` | Shared aliases and functions (bat, eza, fzf, trash, etc.) |
| `.gitconfig` | Git config — templated name/email, credential helper, includes `.gitconfig.local` |
| `.config/starship.toml` | Starship cross-shell prompt config |
| `.tmux.conf` | tmux — catppuccin theme, plugins, keybindings |

All tool references use `command -v` guards so configs work on machines where a tool isn't installed.

## Prerequisites

- [chezmoi](https://www.chezmoi.io/install/)
- **macOS**: [Homebrew](https://brew.sh/) — on the first `chezmoi apply`, a `run_onchange` script automatically runs `brew bundle` to install all required packages (Starship, bat, eza, fzf, etc.)
- **Linux** (Debian/Ubuntu): `apt` + `curl` — a `run_onchange` script installs apt packages and downloads tools not in default repos (starship, atuin, eza, zoxide, delta, etc.)

## Quick start

### New machine

```bash
# One-liner (prompts for repo, name, email, shell)
bash <(curl -fsSL https://raw.githubusercontent.com/onurcelep/dotfiles/main/bootstrap.sh)

# Non-interactive
bash <(curl -fsSL ...) --repo github.com/youruser/dotfiles --shell zsh

# Private / self-hosted GitLab (auto-detects, installs glab, prompts for auth)
bash bootstrap.sh --repo gitlab.company.com/user/dotfiles
```

On first run, chezmoi will prompt for your name, email, and GitHub username. These are saved in `~/.config/chezmoi/chezmoi.toml` and used to template `.gitconfig` and other personal configs.

### Existing machine

```bash
# Pull latest changes and apply
chezmoi update

# See what would change before applying
chezmoi diff
```

## Daily workflow

```bash
# Edit a managed file (opens in $EDITOR, applies on save)
chezmoi edit ~/.zshrc

# Or edit directly then re-add
vim ~/.zshrc
chezmoi add ~/.zshrc

# Push changes
cd ~/.local/share/chezmoi
git add -A && git commit -m "update zshrc" && git push
```

## Machine-local overrides

Machine-specific settings go in untracked local files:

- **`~/.zshenv.local`** — sourced at the top of `.zshrc` (puts brew in PATH before anything else)
- **`~/.bashrc.local`** — sourced at the top of `.bashrc`

Example for an ARM Mac (`~/.zshenv.local`):

```bash
# Homebrew
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Java (Homebrew OpenJDK)
if [[ -d /opt/homebrew/opt/openjdk ]]; then
  export JAVA_HOME=/opt/homebrew/opt/openjdk
  export PATH="$JAVA_HOME/bin:$PATH"
fi

# Flutter
[[ -d "$HOME/Code/flutter/bin" ]] && export PATH="$HOME/Code/flutter/bin:$PATH"
```

## Bash setup note

chezmoi manages `~/.bashrc` but **not** `~/.bash_profile`. If you use bash as a login shell, add the following to your `~/.bash_profile`:

```bash
[[ -f ~/.bashrc ]] && source ~/.bashrc
```

This is not done automatically because `.bash_profile` may contain machine-local setup (SDKMAN, conda, etc.).

## Secrets

Secrets (API keys, tokens, SSH config) are **never** committed to this repo.

### Options for managing secrets

**1. Local override files** — simplest approach for environment variables:

```bash
# ~/.zshenv.local or ~/.bashrc.local (not tracked)
export OPENAI_API_KEY="sk-..."
export AWS_ACCESS_KEY_ID="..."
```

**2. Bitwarden** — chezmoi has built-in support:

```bash
# In a chezmoi template file (e.g. dot_zshrc.tmpl)
export API_KEY="{{ (bitwarden "item" "api-key").login.password }}"
```

Requires `bw` CLI and an active session (`bwu` helper is defined in `.shell_common`).

**3. 1Password / other managers** — chezmoi supports [many backends](https://www.chezmoi.io/user-guide/password-managers/).

## Templates

Templates let a single file adapt to different machines. Rename a source file to add `.tmpl`:

```bash
chezmoi add --template ~/.zshrc
# Creates dot_zshrc.tmpl instead of dot_zshrc
```

### Template basics

chezmoi uses Go's `text/template` syntax:

```bash
# Conditional on OS
{{ if eq .chezmoi.os "darwin" -}}
alias flush-dns="sudo dscacheutil -flushcache"
{{ end -}}

# Conditional on hostname
{{ if eq .chezmoi.hostname "work-laptop" -}}
export HTTP_PROXY="http://proxy.corp:8080"
{{ end -}}

# Conditional on architecture
{{ if eq .chezmoi.arch "arm64" -}}
eval "$(/opt/homebrew/bin/brew shellenv)"
{{ else -}}
eval "$(/usr/local/bin/brew shellenv)"
{{ end -}}
```

### Available variables

```bash
# See all available data
chezmoi data

# Common variables:
# .chezmoi.os          -> "darwin", "linux"
# .chezmoi.arch        -> "arm64", "amd64"
# .chezmoi.hostname    -> machine hostname
# .chezmoi.username    -> current user
# .chezmoi.homeDir     -> home directory path
```

## Useful commands

```bash
chezmoi doctor          # Health check
chezmoi managed         # List all managed files
chezmoi diff            # Show pending changes
chezmoi apply -v        # Apply changes (verbose)
chezmoi cd              # cd into source directory
chezmoi data            # Show template variables
chezmoi cat ~/.zshrc    # Show what chezmoi would write
```

## Files NOT tracked (by design)

- `.ssh/config` — machine-specific hosts
- `.bash_profile` — SDKMAN + conda with hardcoded paths
- `.zshenv.local` / `.bashrc.local` — machine-local environment (see above)
- `.oh-my-zsh/` — no longer used; can be removed after verifying Starship setup
