# server-setup

A single-script bootstrap that turns a fresh Linux box into a comfortable
zsh-based development environment — Neovim, a modern CLI toolchain, the Yazi
file manager, and tmux — with sensible dotfiles wired up. No sudo required, 
idempotent, and dependency-free (pure POSIX `sh`
plus ANSI colors).

## Quick start

### One-liner (downloads everything, including the dotfiles)

```sh
curl -fsSL https://raw.githubusercontent.com/mathaimp/server-setup/main/server-online.sh | sh
```

Skip the Neovim download (e.g. you already have it):

```sh
curl -fsSL https://raw.githubusercontent.com/mathaimp/server-setup/main/server-online.sh | sh -s -- --skip-nvim
```

### From a clone (copies the dotfiles from this repo)

```sh
git clone https://github.com/mathaimp/server-setup.git
cd server-setup
sh server.sh            # add --skip-nvim to skip Neovim
```

> `server-online.sh` and `server.sh` are identical except for how the dotfiles
> (`.zshrc`, `.p10k.zsh`, `tmux.conf`) are obtained: the online version fetches
> them from `raw.githubusercontent.com`, the local version copies them from the
> checked-out repo. Use the online version for `curl | sh`; use the local
> version when you've cloned the repo.

## Prerequisites

These must already be present (the script can't install them and will abort if
missing):

- **zsh**
- **git**
- **curl** *or* **wget**

The script also aborts if it can't change your login shell to zsh (`chsh`), if
Neovim fails to install, or if tmux can't be obtained. Everything else is
installed by the script and only warns on failure.

## What it sets up

| Area | Details |
| --- | --- |
| **Shell** | `chsh` to zsh; installs `~/.zshrc` and `~/.p10k.zsh`. |
| **zsh config** | [zinit](https://github.com/zdharma-continuum/zinit) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k), syntax-highlighting, autosuggestions, completions, and fzf-tab. Aliases (`ls`→eza, `cat`→bat, etc.), large deduped history, vi-style key bindings. |
| **Neovim** | Latest Linux x86_64 build extracted to `~/.local/nvim`; config cloned from [mathaimp/nvim](https://github.com/mathaimp/nvim) into `~/.config/nvim`. |
| **Pixi** | Installed to `~/.pixi` and used to provide CLI tools. |
| **uv** | Installed to `~/.local/bin`; used to install Yazi. |
| **CLI tools** | `fd`, `ripgrep`, `fzf`, `tree-sitter`, `ty`, `ruff`, `lua-language-server`, `stylua`, `eza`, `bat`, `zoxide`, `lazygit`, `tmux` — only the ones whose binary is missing. |
| **Yazi** | Installed via `uv tool install yazi-bin`; config + plugins (`full-border`, `max-preview`, `chmod`) written to `~/.config/yazi`. |
| **tmux** | Config written to `~/.config/tmux/tmux.conf` and symlinked from `~/.tmux.conf`; [TPM](https://github.com/tmux-plugins/tpm) cloned and plugins (`vim-tmux-navigator`, `tmux-yank`) installed headlessly. |

The following directories are added to `PATH` (in `~/.zshrc`):
`~/.pixi/bin`, `~/.local/bin`, `~/.local/nvim/bin`.

## Files

```
server.sh         # run from a clone; copies dotfiles with cp
server-online.sh  # run via curl | sh; fetches dotfiles from GitHub
.zshrc            # zsh + zinit + p10k config
.p10k.zsh         # Powerlevel10k config (generated)
tmux.conf         # tmux config (prefix is C-Space)
```

## Notes

- The setup is **idempotent**: tools and files that are already present are
  detected and skipped, so re-running is safe.
- `chsh` prompts for your password; it reads from `/dev/tty`, so it works even
  under `curl | sh`.
- The prompt and tmux status bar use Nerd Font glyphs — install a [Nerd
  Font](https://www.nerdfonts.com/) in your terminal for them to render
  correctly.
- tmux prefix is **`C-Space`** (not the default `C-b`). Reload the config with
  `prefix + R`.
