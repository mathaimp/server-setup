#!/usr/bin/env sh
set -u

# ── Pretty output (no external dependencies) ──────────────────────────────
if [ -t 1 ]; then
    E=$(printf '\033')
    C_RESET="$E[0m"; C_BOLD="$E[1m"; C_DIM="$E[2m"
    C_RED="$E[31m"; C_GREEN="$E[32m"; C_YELLOW="$E[33m"
    C_BLUE="$E[34m"; C_CYAN="$E[36m"; C_MAGENTA="$E[35m"
else
    C_RESET=''; C_BOLD=''; C_DIM=''
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_MAGENTA=''
fi

section() { printf '\n%s%s▸ %s%s\n'   "$C_BOLD" "$C_BLUE" "$*" "$C_RESET"; }
ok()      { printf '  %s✓%s %s\n'     "$C_GREEN"  "$C_RESET" "$*"; }
skip()    { printf '  %s· %s%s\n'     "$C_DIM"    "$*" "$C_RESET"; }
info()    { printf '  %s\n'           "$*"; }
warn()    { printf '  %s!%s %s\n'     "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()     { printf '  %s✗%s %s\n'     "$C_RED"    "$C_RESET" "$*" >&2; exit 1; }

SKIP_NVIM=0
while [ $# -gt 0 ]; do
    case "$1" in
        --skip-nvim) SKIP_NVIM=1 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

printf '\n%s%s▌ server setup%s\n' "$C_BOLD" "$C_MAGENTA" "$C_RESET"
printf '%s─────────────────────%s\n\n' "$C_MAGENTA" "$C_RESET"

# Base URL for dotfiles (this script is meant to be run via `curl ... | sh`).
REMOTE_BASE="https://raw.githubusercontent.com/mathaimp/server-setup/main"

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
        warn "pixi not available, skipping: $*"
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
        info "installing via pixi:$missing"
        if pixi global install $missing; then
            ok "installed:$missing"
        else
            warn "failed to install some pixi packages ($missing)"
        fi
    else
        ok "all requested packages already installed"
    fi
}

# ── Prerequisites (fatal) ─────────────────────────────────────────────────
section "Prerequisites"
for cmd in zsh git; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is not installed — install it and rerun"
done
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    die "neither curl nor wget is installed — install one and rerun"
fi
ok "zsh, git, and a downloader are available"

# ── Default shell (fatal if it can't be changed) ──────────────────────────
section "Default shell"
ZSH_PATH="$(command -v zsh)"
if [ "${SHELL:-}" != "$ZSH_PATH" ]; then
    info "changing default shell to zsh..."
    if chsh -s "$ZSH_PATH" </dev/tty; then
        ok "default shell set to zsh"
    else
        die "failed to change default shell to zsh"
    fi
else
    skip "default shell is already zsh"
fi

# ── Dotfiles ──────────────────────────────────────────────────────────────
section "Dotfiles"
if [ ! -e "$HOME/.zshrc" ]; then
    if download "$HOME/.zshrc" "$REMOTE_BASE/.zshrc"; then ok "downloaded ~/.zshrc"; else warn "failed to download .zshrc"; fi
else
    skip "~/.zshrc already present"
fi
if download "$HOME/.p10k.zsh" "$REMOTE_BASE/.p10k.zsh"; then ok "downloaded ~/.p10k.zsh"; else warn "failed to download .p10k.zsh"; fi

# ── Neovim (fatal if it can't be installed) ───────────────────────────────
if [ "$SKIP_NVIM" -eq 0 ]; then
    section "Neovim"
    info "downloading latest Neovim..."

    INSTALL_DIR="$HOME/.local/nvim"
    ARCHIVE="nvim-linux-x86_64.tar.gz"
    URL="https://github.com/neovim/neovim/releases/latest/download/${ARCHIVE}"

    if ! download "$ARCHIVE" "$URL"; then
        die "failed to download Neovim"
    fi

    rm -rf "$INSTALL_DIR"
    mkdir -p "$HOME/.local"

    if ! tar -xzf "$ARCHIVE"; then
        rm -f "$ARCHIVE"
        die "failed to extract Neovim archive"
    fi
    mv nvim-linux-x86_64 "$INSTALL_DIR"
    rm "$ARCHIVE"

    export PATH="$INSTALL_DIR/bin:$PATH"
    if command -v nvim >/dev/null 2>&1; then
        ok "installed $(nvim --version | head -n1)"
    else
        die "Neovim was not installed correctly"
    fi
else
    section "Neovim"
    skip "install skipped (--skip-nvim)"
fi

section "Neovim config"
mkdir -p "$HOME/.config"
if [ ! -d "$HOME/.config/nvim" ]; then
    info "cloning nvim config..."
    if git clone https://github.com/mathaimp/nvim.git "$HOME/.config/nvim"; then
        ok "cloned nvim config"
    else
        warn "failed to clone nvim config"
    fi
else
    skip "nvim config already present"
fi

# ── Pixi ──────────────────────────────────────────────────────────────────
section "Pixi"
if command -v pixi >/dev/null 2>&1; then
    skip "pixi already installed ($(pixi --version))"
else
    info "installing pixi..."
    if command -v curl >/dev/null 2>&1; then
        INSTALL_CMD="curl -fsSL https://pixi.sh/install.sh | sh"
    else
        INSTALL_CMD="wget -qO- https://pixi.sh/install.sh | sh"
    fi
    if sh -c "$INSTALL_CMD"; then ok "pixi installed"; else warn "pixi installation failed"; fi
fi

export PATH="$HOME/.pixi/bin:$PATH"
if ! command -v pixi >/dev/null 2>&1; then
    warn "pixi not on PATH; pixi-managed tools will be skipped"
fi

# ── uv ────────────────────────────────────────────────────────────────────
section "uv"
if command -v uv >/dev/null 2>&1; then
    skip "uv already installed ($(uv --version))"
else
    info "installing uv..."
    if command -v curl >/dev/null 2>&1; then
        if curl -LsSf https://astral.sh/uv/install.sh | sh; then ok "uv installed"; else warn "uv installation failed"; fi
    else
        if wget -qO- https://astral.sh/uv/install.sh | sh; then ok "uv installed"; else warn "uv installation failed"; fi
    fi
fi

export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
    warn "uv not on PATH; uv-managed tools will be skipped"
fi

# ── CLI tools (pixi-managed, only missing ones) ───────────────────────────
section "CLI tools"
info "neovim dependencies"
pixi_global_install_missing \
    fd-find:fd \
    ripgrep:rg \
    fzf \
    tree-sitter-cli:tree-sitter \
    ty \
    ruff \
    lua-language-server \
    stylua

info "other utilities"
pixi_global_install_missing \
    eza \
    bat \
    zoxide \
    lazygit

# ── Yazi (via uv) ─────────────────────────────────────────────────────────
section "Yazi"
if command -v yazi >/dev/null 2>&1; then
    skip "yazi already installed ($(yazi --version))"
else
    if command -v uv >/dev/null 2>&1; then
        info "installing yazi via uv..."
        if uv tool install yazi-bin; then ok "yazi installed ($(yazi --version))"; else warn "failed to install yazi via uv"; fi
    else
        warn "uv not available, skipping yazi install"
    fi
fi

export PATH="$HOME/.local/bin:$PATH"

info "writing yazi config"
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
ok "wrote yazi config"

info "installing yazi plugins"
if ! command -v ya >/dev/null 2>&1; then
    warn "ya not available, skipping yazi plugins"
else
    ya pkg add yazi-rs/plugins:full-border || warn "failed to add full-border plugin"
    ya pkg add yazi-rs/plugins:max-preview || warn "failed to add max-preview plugin"
    ya pkg add yazi-rs/plugins:chmod || warn "failed to add chmod plugin"
fi

# ── tmux ──────────────────────────────────────────────────────────────────
section "tmux"
if command -v tmux >/dev/null 2>&1; then
    skip "tmux already installed ($(tmux -V))"
else
    info "installing tmux via pixi..."
    pixi_global_install_missing tmux
fi

if ! command -v tmux >/dev/null 2>&1; then
    die "tmux is required but could not be found or installed"
fi

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    info "cloning tpm..."
    if git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm; then ok "cloned tpm"; else warn "failed to clone tpm"; fi
else
    skip "tpm already cloned"
fi

mkdir -p "$HOME/.config/tmux"
if download "$HOME/.config/tmux/tmux.conf" "$REMOTE_BASE/tmux.conf"; then ok "downloaded tmux.conf"; else warn "failed to download tmux.conf"; fi

if [ ! -e "$HOME/.tmux.conf" ]; then
    if ln -s "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"; then ok "linked ~/.tmux.conf"; else warn "failed to symlink ~/.tmux.conf"; fi
else
    skip "~/.tmux.conf already present"
fi

info "installing tmux plugins"
if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn "tmux plugin install reported errors"
else
    warn "tpm install_plugins not found, skipping"
fi

printf '\n%s%s✓ Setup complete.%s\n' "$C_BOLD" "$C_GREEN" "$C_RESET"
