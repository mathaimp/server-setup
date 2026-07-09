#!/usr/bin/env sh
set -u

SKIP_NVIM=0

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-nvim)
            SKIP_NVIM=1
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

# --- Fatal prerequisite checks ---
for cmd in zsh git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is not installed. Install it and rerun." >&2
        exit 1
    fi
done

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    echo "Error: neither curl nor wget is installed. Install one and rerun." >&2
    exit 1
fi

# Pick a downloader based on what is available.
download() {
    if command -v curl >/dev/null 2>&1; then
        curl -fL -o "$1" "$2"
    else
        wget -O "$1" "$2"
    fi
}

# Install pixi global packages only when their exposed binary is missing.
pixi_global_install_missing() {
    if ! command -v pixi >/dev/null 2>&1; then
        echo "Warning: pixi not available, skipping: $*" >&2
        return 0
    fi
    missing=""
    for spec in "$@"; do
        pkg="${spec%%:*}"
        bin="${spec#*:}"
        [ "$bin" = "$spec" ] && bin="$pkg"
        if ! command -v "$bin" >/dev/null 2>&1; then
            missing="$missing $pkg"
        fi
    done
    if [ -n "$missing" ]; then
        echo "Installing via pixi:$missing"
        pixi global install $missing || echo "Warning: failed to install some pixi packages ($missing)." >&2
    else
        echo "All requested pixi packages already installed."
    fi
}

# --- Change default shell to zsh (fatal if it fails) ---
ZSH_PATH="$(command -v zsh)"
if [ "${SHELL:-}" != "$ZSH_PATH" ]; then
    echo "Changing default shell to zsh..."
    if ! chsh -s "$ZSH_PATH"; then
        echo "Error: failed to change default shell to zsh." >&2
        exit 1
    fi
else
    echo "Default shell is already zsh."
fi

# --- .zshrc / .p10k.zsh ---
echo "adding .zshrc"
if [ ! -e "$HOME/.zshrc" ]; then
    cp ./.zshrc "$HOME/.zshrc" || echo "Warning: failed to copy .zshrc." >&2
else
    echo ".zshrc already present in ~/.zshrc"
fi


echo "adding p10k"
cp ./.p10k.zsh "$HOME/.p10k.zsh" || echo "Warning: failed to copy .p10k.zsh." >&2

# --- Neovim (fatal if it can't be installed) ---
if [ "$SKIP_NVIM" -eq 0 ]; then
    echo "Installing Neovim..."

    INSTALL_DIR="$HOME/.local/nvim"
    ARCHIVE="nvim-linux-x86_64.tar.gz"
    URL="https://github.com/neovim/neovim/releases/latest/download/${ARCHIVE}"

    if ! download "$ARCHIVE" "$URL"; then
        echo "Error: failed to download Neovim." >&2
        exit 1
    fi

    rm -rf "$INSTALL_DIR"
    mkdir -p "$HOME/.local"

    if ! tar -xzf "$ARCHIVE"; then
        echo "Error: failed to extract Neovim archive." >&2
        rm -f "$ARCHIVE"
        exit 1
    fi
    mv nvim-linux-x86_64 "$INSTALL_DIR"
    rm "$ARCHIVE"

    export PATH="$INSTALL_DIR/bin:$PATH"

    if command -v nvim >/dev/null 2>&1; then
        echo "Installed $(nvim --version | head -n1)"
    else
        echo "Error: Neovim was not installed correctly." >&2
        exit 1
    fi
else
    echo "Skipping Neovim installation."
fi

mkdir -p "$HOME/.config"
if [ ! -d "$HOME/.config/nvim" ]; then
    git clone https://github.com/mathaimp/nvim.git "$HOME/.config/nvim" || echo "Warning: failed to clone nvim config." >&2
else
    echo "nvim config already present in ~/.config/nvim"
fi

# --- Pixi ---
if command -v pixi >/dev/null 2>&1; then
    echo "Pixi is already installed: $(pixi --version)"
else
    echo "Installing Pixi..."
    if command -v curl >/dev/null 2>&1; then
        INSTALL_CMD="curl -fsSL https://pixi.sh/install.sh | sh"
    else
        INSTALL_CMD="wget -qO- https://pixi.sh/install.sh | sh"
    fi
    sh -c "$INSTALL_CMD" || echo "Warning: Pixi installation failed." >&2
fi

# Make pixi available for the rest of this script.
export PATH="$HOME/.pixi/bin:$PATH"
if ! command -v pixi >/dev/null 2>&1; then
    echo "Warning: pixi not on PATH; pixi-managed tools will be skipped." >&2
fi

# --- uv ---
echo "Installing uv..."
if command -v uv >/dev/null 2>&1; then
    echo "uv already installed: $(uv --version)"
else
    if command -v curl >/dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh | sh || echo "Warning: uv installation failed." >&2
    else
        wget -qO- https://astral.sh/uv/install.sh | sh || echo "Warning: uv installation failed." >&2
    fi
fi

export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
    echo "Warning: uv not on PATH; uv-managed tools will be skipped." >&2
fi

# --- Pixi-managed tools (only missing ones) ---
echo "Installing Neovim dependencies..."
pixi_global_install_missing \
    fd-find:fd \
    ripgrep:rg \
    fzf \
    tree-sitter-cli:tree-sitter \
    ty \
    ruff \
    lua-language-server \
    stylua

echo "Installing other dependencies"
pixi_global_install_missing \
    eza \
    bat \
    zoxide \
    lazygit

# --- Yazi (via uv) ---
echo "Installing Yazi..."
if command -v yazi >/dev/null 2>&1; then
    echo "yazi already installed: $(yazi --version)"
else
    if command -v uv >/dev/null 2>&1; then
        uv tool install yazi-bin || echo "Warning: failed to install yazi via uv." >&2
    else
        echo "Warning: uv not available, skipping yazi install." >&2
    fi
fi

export PATH="$HOME/.local/bin:$PATH"
if command -v yazi >/dev/null 2>&1; then
    echo "Installed $(yazi --version)"
fi

echo "Setting up yazi"

mkdir -p "$HOME/.config/yazi"

cat > "$HOME/.config/yazi/yazi.toml" <<'EOF'
[mgr]
show_hidden = true
show_symlink = true
sort_by = "natural"

[preview]
max_width = 1000
max_height = 1000
EOF

cat > "$HOME/.config/yazi/init.lua" <<'EOF'
require("full-border"):setup()
EOF

cat > "$HOME/.config/yazi/keymap.toml" <<'EOF'
[[mgr.prepend_keymap]]
on = "T"
run = "plugin max-preview"
desc = "Maximize or restore the preview pane"

[[mgr.prepend_keymap]]
on = ["c", "m"]
run = "plugin chmod"
desc = "Chmod on selected files"
EOF

echo "Installing yazi plugins..."
if ! command -v ya >/dev/null 2>&1; then
    echo "Warning: ya not available, skipping yazi plugins." >&2
else
    ya pkg add yazi-rs/plugins:full-border || echo "Warning: failed to add full-border plugin." >&2
    ya pkg add yazi-rs/plugins:max-preview || echo "Warning: failed to add max-preview plugin." >&2
    ya pkg add yazi-rs/plugins:chmod || echo "Warning: failed to add chmod plugin." >&2
fi

# --- tmux ---
echo "Adding tmux"

if command -v tmux >/dev/null 2>&1; then
    echo "tmux already installed: $(tmux -V)"
else
    pixi_global_install_missing tmux
fi

if ! command -v tmux >/dev/null 2>&1; then
    echo "Error: tmux is required but could not be found or installed." >&2
    exit 1
fi

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm || echo "Warning: failed to clone tpm." >&2
else
    echo "tpm already cloned"
fi

mkdir -p "$HOME/.config/tmux"
cp ./tmux.conf "$HOME/.config/tmux/tmux.conf" || echo "Warning: failed to copy tmux.conf." >&2

# Older tmux reads ~/.tmux.conf by default; symlink so the config is found.
if [ ! -e "$HOME/.tmux.conf" ]; then
    ln -s "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf" || echo "Warning: failed to symlink ~/.tmux.conf." >&2
fi

echo "Installing tmux plugins..."
if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" || echo "Warning: tmux plugin install reported errors." >&2
else
    echo "Warning: tpm install_plugins not found, skipping." >&2
fi

echo "Setup complete."
