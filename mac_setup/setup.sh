#!/usr/bin/env bash
# =============================================================================
# setup.sh - Idempotent macOS dev environment bootstrap
# =============================================================================
# Usage: ./setup.sh [--dry-run] [--skip-brew] [--no-upgrade]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
SKIP_BREW=false
NO_UPGRADE=false

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)    DRY_RUN=true; shift ;;
    --skip-brew)  SKIP_BREW=true; shift ;;
    --no-upgrade) NO_UPGRADE=true; shift ;;
    --help)
      echo "Usage: $(basename "$0") [--dry-run] [--skip-brew] [--no-upgrade]"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

info()  { printf "${BLUE}==> %s${RESET}\n" "$1"; }
ok()    { printf "${GREEN} ✓  %s${RESET}\n" "$1"; }
skip()  { printf "${YELLOW} –  %s${RESET}\n" "$1"; }
warn()  { printf "${YELLOW} ⚠  %s${RESET}\n" "$1"; }

run() {
  if $DRY_RUN; then
    skip "[dry-run] $*"
  else
    "$@"
  fi
}

# ---------------------------------------------------------------------------
# Symlink helper
# ---------------------------------------------------------------------------
link_file() {
  local source="$1" target="$2"

  # Ensure parent directory exists
  local parent
  parent="$(dirname "$target")"
  [[ -d "$parent" ]] || run mkdir -p "$parent"

  # If target is already a symlink pointing to source, skip
  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
    ok "Already linked: $target"
    return 0
  fi

  # If target exists (file or different symlink), backup
  if [[ -e "$target" ]] || [[ -L "$target" ]]; then
    local backup="${target}.backup.$(date +%Y%m%d-%H%M%S)"
    warn "Backing up $target → $backup"
    run mv "$target" "$backup"
  fi

  info "Linking $source → $target"
  run ln -sf "$source" "$target"
  ok "Linked: $target"
}

# =============================================================================
# Step 1: Symlink configs
# =============================================================================
info "Step 1: Symlinking config files..."

link_file "$SCRIPT_DIR/configs/zshrc"              "$HOME/.zshrc"
link_file "$SCRIPT_DIR/configs/gitconfig"           "$HOME/.gitconfig"
link_file "$SCRIPT_DIR/configs/gitignore_global"    "$HOME/.gitignore"
link_file "$SCRIPT_DIR/configs/vim/init.vim"        "$HOME/.config/nvim/init.vim"
link_file "$SCRIPT_DIR/configs/tmux/tmux.conf"      "$HOME/.tmux.conf"
link_file "$SCRIPT_DIR/configs/tmux/start_tmux_dev" "$HOME/start_tmux_dev"
link_file "$SCRIPT_DIR/configs/tmux/help"           "$HOME/tmux_help"
link_file "$SCRIPT_DIR/configs/ghostty/config"      "$HOME/.config/ghostty/config"
link_file "$SCRIPT_DIR/configs/starship.toml"       "$HOME/.config/starship.toml"
link_file "$SCRIPT_DIR/configs/worktreerc"          "$HOME/.worktreerc"

# SSH config (ensure directory permissions)
run mkdir -p "$HOME/.ssh"
run chmod 700 "$HOME/.ssh"
link_file "$SCRIPT_DIR/configs/ssh/config"          "$HOME/.ssh/config"
if [[ -f "$HOME/.ssh/config" ]]; then
  run chmod 600 "$HOME/.ssh/config"
fi

# Make scripts executable
run chmod +x "$SCRIPT_DIR/configs/tmux/start_tmux_dev"
run chmod +x "$SCRIPT_DIR/configs/tmux/help"

echo ""

# =============================================================================
# Step 2: Homebrew + brew bundle
# =============================================================================
if ! $SKIP_BREW; then
  info "Step 2: Homebrew..."

  if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add to PATH for Apple Silicon
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  else
    ok "Homebrew already installed"
  fi

  if ! $NO_UPGRADE; then
    info "Updating Homebrew..."
    run brew update || true
  fi

  info "Running brew bundle (this may take a while)..."
  if $NO_UPGRADE; then
    brew bundle --file="$SCRIPT_DIR/Brewfile" --no-upgrade || warn "Some packages may have failed to install"
  else
    brew bundle --file="$SCRIPT_DIR/Brewfile"  || warn "Some packages may have failed to install"
  fi

  # Link keg-only formulae
  info "Linking keg-only formulae..."
  brew link --force libpq 2>/dev/null && ok "Linked libpq" || skip "libpq already linked or unavailable"

  echo ""
else
  skip "Step 2: Skipping Homebrew (--skip-brew)"
  echo ""
fi

# =============================================================================
# Step 3: vim-plug
# =============================================================================
info "Step 3: vim-plug..."

VIM_PLUG_DIR="$HOME/.vim/autoload"
VIM_PLUG="$VIM_PLUG_DIR/plug.vim"
if [[ ! -f "$VIM_PLUG" ]]; then
  info "Installing vim-plug..."
  run curl -fLo "$VIM_PLUG" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  ok "vim-plug installed"
else
  ok "vim-plug already installed"
fi
echo ""

# =============================================================================
# Step 4: TPM (Tmux Plugin Manager)
# =============================================================================
info "Step 4: TPM..."

TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
  info "Installing TPM..."
  run git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
  ok "TPM installed"
else
  ok "TPM already installed"
fi
echo ""

# =============================================================================
# Step 5: Oh My Zsh
# =============================================================================
info "Step 5: Oh My Zsh..."

OMZ_DIR="$HOME/.oh-my-zsh"
if [[ ! -d "$OMZ_DIR" ]]; then
  info "Installing Oh My Zsh..."
  run env RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  ok "Oh My Zsh installed"
else
  ok "Oh My Zsh already installed"
fi
echo ""

# =============================================================================
# Step 6: Zsh custom plugins
# =============================================================================
info "Step 6: Zsh custom plugins..."

ZSH_CUSTOM="${ZSH_CUSTOM:-$OMZ_DIR/custom}"

clone_plugin() {
  local repo="$1" name="$2"
  local dest="$ZSH_CUSTOM/plugins/$name"
  if [[ ! -d "$dest" ]]; then
    info "Cloning $name..."
    run git clone "$repo" "$dest"
    ok "$name installed"
  else
    ok "$name already installed"
  fi
}

clone_plugin "https://github.com/zsh-users/zsh-autosuggestions" "zsh-autosuggestions"
clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "zsh-syntax-highlighting"
clone_plugin "https://github.com/Aloxaf/fzf-tab" "fzf-tab"
echo ""

# =============================================================================
# Step 7: pyenv
# =============================================================================
info "Step 7: pyenv..."

if [[ ! -d "$HOME/.pyenv" ]]; then
  info "Installing pyenv..."
  if $DRY_RUN; then
    skip "[dry-run] curl https://pyenv.run | bash"
  else
    curl https://pyenv.run | bash
  fi
  ok "pyenv installed"
else
  ok "pyenv already installed"
fi
echo ""

# =============================================================================
# Step 8: mise
# =============================================================================
info "Step 8: mise..."

if ! command -v mise &>/dev/null && [[ ! -f "$HOME/.local/bin/mise" ]]; then
  info "Installing mise..."
  if $DRY_RUN; then
    skip "[dry-run] curl https://mise.run | sh"
  else
    curl https://mise.run | sh
  fi
  ok "mise installed"
else
  ok "mise already installed"
fi
echo ""

# =============================================================================
# Step 9: Secrets template
# =============================================================================
info "Step 9: Secrets template..."

SECRETS_FILE="$HOME/ee"
if [[ ! -f "$SECRETS_FILE" ]]; then
  info "Creating secrets template at ~/ee..."
  if ! $DRY_RUN; then
    cat > "$SECRETS_FILE" << 'SECRETS'
# Secrets — sourced by .zshrc
# This file should NEVER be committed to version control.
# export API_KEY="your-key-here"
SECRETS
    chmod 600 "$SECRETS_FILE"
  else
    skip "[dry-run] Would create $SECRETS_FILE"
  fi
  ok "Secrets template created (chmod 600)"
else
  ok "Secrets file ~/ee already exists"
fi
echo ""

# =============================================================================
# Step 10: macOS defaults
# =============================================================================
info "Step 10: macOS defaults..."

if [[ -f "$SCRIPT_DIR/macos_defaults.sh" ]]; then
  run bash "$SCRIPT_DIR/macos_defaults.sh"
  ok "macOS defaults applied"
else
  warn "macos_defaults.sh not found, skipping"
fi
echo ""

# =============================================================================
# Step 11: Neovim plugins (headless)
# =============================================================================
info "Step 11: Neovim plugins..."

if command -v nvim &>/dev/null; then
  info "Installing Neovim plugins headlessly..."
  run nvim --headless +PlugInstall +qall 2>&1 || true
  ok "Neovim plugins installed"
else
  warn "nvim not found, skipping plugin install"
fi
echo ""

# =============================================================================
# Step 12: TPM plugins
# =============================================================================
info "Step 12: TPM plugins..."

TPM_INSTALL="$HOME/.tmux/plugins/tpm/bin/install_plugins"
if [[ -x "$TPM_INSTALL" ]]; then
  info "Installing tmux plugins..."
  run "$TPM_INSTALL" || true
  ok "tmux plugins installed"
else
  warn "TPM install script not found"
fi
echo ""

# =============================================================================
# Step 13: Create gitconfig.local if missing
# =============================================================================
info "Step 13: Git identity..."

if [[ ! -f "$HOME/.gitconfig.local" ]]; then
  info "Creating ~/.gitconfig.local template..."
  if ! $DRY_RUN; then
    cat > "$HOME/.gitconfig.local" << 'GITLOCAL'
[user]
	name = Your Name
	email = your@email.com
GITLOCAL
  fi
  warn "Edit ~/.gitconfig.local with your name and email"
else
  ok "~/.gitconfig.local already exists"
fi
echo ""

# =============================================================================
# Done
# =============================================================================
echo ""
printf "${GREEN}=============================================${RESET}\n"
printf "${GREEN}  Setup complete!${RESET}\n"
printf "${GREEN}=============================================${RESET}\n"
echo ""
echo "Next steps:"
echo "  1. Edit ~/.gitconfig.local with your name and email"
echo "  2. Run: gh auth login"
echo "  3. Open a new terminal (or: exec zsh)"
echo "  4. Type 't' to start tmux Dev session"
echo "  5. See SECRETS_CHECKLIST.md for credentials to configure"
echo ""
