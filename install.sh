#!/usr/bin/env zsh
set -euo pipefail

INSTALL_DIR="$HOME/trace"
BIN_DIR="$HOME/.local/bin"
WRAPPER_PATH="$BIN_DIR/trace"
REPO_URL="https://github.com/johnsellin93/trace.git"

PATH_EXPORT_LOCAL='export PATH="$HOME/.local/bin:$PATH"'
PATH_EXPORT_TRACE='export PATH="$HOME/trace:$PATH"'

info() { echo "[trace] $*"; }
ok() { echo "✓ $*"; }
warn() { echo "⚠ $*"; }

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

install_packages() {
    local packages=("$@")

    if (( ${#packages[@]} == 0 )); then
        return
    fi

    if has_cmd apt; then
        sudo apt update
        sudo apt install -y "${packages[@]}"
    elif has_cmd dnf; then
        sudo dnf install -y "${packages[@]}"
    elif has_cmd yum; then
        sudo yum install -y "${packages[@]}"
    elif has_cmd pacman; then
        sudo pacman -Sy --needed "${packages[@]}"
    elif has_cmd zypper; then
        sudo zypper install -y "${packages[@]}"
    elif has_cmd brew; then
        brew install "${packages[@]}"
    else
        warn "No supported package manager found. Please install manually: ${packages[*]}"
        return 1
    fi
}

ensure_required_dependency() {
    local cmd="$1"
    local package="$2"

    if has_cmd "$cmd"; then
        ok "$cmd installed"
        return
    fi

    info "$cmd not found. Installing $package..."
    install_packages "$package"

    if has_cmd "$cmd"; then
        ok "$cmd installed"
    else
        echo "[trace] ERROR: failed to install required dependency: $cmd" >&2
        exit 1
    fi
}

ensure_optional_dependency() {
    local cmd="$1"
    local package="$2"

    if has_cmd "$cmd"; then
        ok "$cmd installed"
        return
    fi

    info "$cmd not found. Attempting optional install..."
    if install_packages "$package"; then
        if has_cmd "$cmd"; then
            ok "$cmd installed"
        else
            warn "$cmd still not found"
        fi
    else
        warn "$cmd not installed; trace will fall back where possible"
    fi
}

append_path_if_missing() {
    local shell_rc="$1"
    local line="$2"

    touch "$shell_rc"

    if ! grep -Fxq "$line" "$shell_rc" 2>/dev/null; then
        echo "$line" >> "$shell_rc"
        ok "Added PATH entry to $shell_rc"
    else
        ok "PATH entry already present in $shell_rc"
    fi
}

info "Checking dependencies..."

ensure_required_dependency zsh zsh
ensure_required_dependency git git
ensure_required_dependency rg ripgrep
ensure_optional_dependency tree tree

if has_cmd tmux; then ok "tmux detected"; else warn "tmux not found"; fi
if has_cmd wl-copy; then ok "wl-copy detected"; else warn "wl-copy not found"; fi
if has_cmd xclip; then ok "xclip detected"; else warn "xclip not found"; fi
if has_cmd pbcopy; then ok "pbcopy detected"; else warn "pbcopy not found"; fi

info "Installing trace..."

if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "Existing installation found. Updating..."
    git -C "$INSTALL_DIR" pull
else
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/trace"

info "Installing wrapper..."

mkdir -p "$BIN_DIR"

cat > "$WRAPPER_PATH" <<'EOF'
#!/usr/bin/env bash
exec zsh "$HOME/trace/trace" "$@"
EOF

chmod +x "$WRAPPER_PATH"
ok "Installed wrapper at $WRAPPER_PATH"

append_path_if_missing "$HOME/.zshrc" "$PATH_EXPORT_LOCAL"

if [[ -f "$HOME/.bashrc" ]]; then
    append_path_if_missing "$HOME/.bashrc" "$PATH_EXPORT_LOCAL"
fi

echo
info "Installation complete."
info "Restart your shell or run:"
echo
echo "    source ~/.zshrc"
echo
info "Verify with:"
echo
echo "    trace --help"
echo "    trace --functions ."
