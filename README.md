# Dotfiles

Personal configuration files for **Zsh**, **Kitty Terminal**, and **Git**.

- **Primary Tested Platform:** Pop!_OS 24.04 LTS (Ubuntu 24.04 noble family, Linux x86_64).
- **Targeted / Unverified Platforms:** Arch Linux, Fedora, and macOS (portable installer logic included, but unverified in this test environment).

## Contents

- `zsh/`: Zsh configuration (`.zshrc`) with Spaceship prompt, fzf-tab, autosuggestions, syntax highlighting, and adaptive aliases.
- `kitty/`: Terminal emulator config (`kitty.conf`) and color scheme (`current-theme.conf`).
- `git/`: Base Git configuration with credential helper and `~/.gitconfig.local` support.
- `install.sh`: Setup script that installs dependencies, fonts, and symlinks configurations.

---

## Installation

Clone the repository and run the installer:

```bash
# Clone the repository (replace with your fork or username if applicable)
git clone https://github.com/bukharyay/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

### Script Flags

- `--no-packages`: Skip package manager installation (only link config files and fonts).
- `--no-fonts`: Skip FiraCode Nerd Font installation.
- `-h, --help`: Show help text.

---

## What `install.sh` Does

1. **Detects OS & Architecture**: Primary verified support for `apt` (tested on Pop!_OS 24.04 LTS). Includes unverified fallback logic for `pacman` (Arch), `dnf` (Fedora), and `brew` (macOS), handling `x86_64` and `arm64`.
2. **Installs Packages**:
   - **Core Packages**: `zsh`, `kitty`, `neovim`, `ripgrep`, `zoxide`, `bat`, `eza`, `fzf`, `direnv`, `git-delta`, `tealdeer`, `lazygit`.
   - **Extended Packages (Arch / macOS)**: `yazi`, `glow`, `xh`, `dust`, `lazydocker` (brew).
   - **Arch Linux Upgrade Prompt**: Prompts for explicit user confirmation before running a full system upgrade (`pacman -Syu`) with default `No`. If skipped, notes that Arch does not support partial upgrades and dependency issues may occur if the system is out of date. Package installation requires interactive confirmation (no `--noconfirm`).
3. **Installs Font**: Downloads and caches `FiraCode Nerd Font` to `~/.local/share/fonts/NerdFonts` on Linux if not already installed.
4. **Creates Symlinks & Safe Backups**:
   - `~/.zshrc` &rarr; `zsh/.zshrc`
   - `~/.config/kitty` &rarr; `kitty`
   - `~/.gitconfig` &rarr; `git/.gitconfig`
   - Sets up local `~/.zsh/completions/` for CLI autocompletions.
   *(Existing configurations are automatically backed up to `~/.dotfiles_backup_<YYYYMMDD_HHMMSS>/` before creating symlinks).*
5. **Configures Git Identity**: Preserves your existing Git `user.name` and `user.email` into `~/.gitconfig.local` (or prompts if unconfigured), keeping private identity separate from tracked configs.
6. **Generates CLI Completions**: Scans your system and generates autocompletions for installed CLI tools into local `~/.zsh/completions/` atomically.
7. **Sets Default Shell**: Updates your user shell to Zsh (`chsh -s $(which zsh)` in interactive sessions).

---

## Productivity Shortcuts

*(Note: These shortcuts are guarded by `command -v` in `.zshrc`: they automatically activate whenever the corresponding utility is installed on your system).*

- `top` / `sys`: Opens [btop](https://github.com/aristocratos/btop) interactive system monitor.
- `lg`: Opens [lazygit](https://github.com/jesseduffield/lazygit) (Terminal UI for Git).
- `lzd`: Opens [lazydocker](https://github.com/jesseduffield/lazydocker) (Terminal UI for Docker).
- `y`: Opens [yazi](https://github.com/sxyazi/yazi) file manager and automatically changes shell working directory (`cd`) upon exit.
- `md <file>`: Renders Markdown cleanly in terminal via [glow](https://github.com/charmbracelet/glow).
- `cht <tool> [topic...]`: Queries [cheat.sh](https://cheat.sh) directly with URL formatting and pager integration (e.g. `cht tar` or `cht python list comprehension`).
- `Ctrl + R`: Interactive fuzzy command history search (via FZF).
- `Ctrl + T`: Interactive fuzzy file/directory picker (via FZF).
- `git diff`: Rendered with line numbers and syntax highlighting via [delta](https://github.com/dandavison/delta) (with safe fallback for machines without delta).

### Kitty Terminal & Split Shortcuts

With `kitty_mod` set to `Alt`:

- `Alt + Enter`: Split window in current working directory (automatic direction).
- `Alt + \` / `Alt + -`: Create vertical / horizontal split in current working directory.
- `Alt + h / j / k / l`: Navigate between splits (left / down / up / right).
- `Alt + Shift + h / j / k / l` or `Alt + Shift + Arrows`: Resize active window.
- `Alt + z`: Toggle full-screen zoom on active window (`stack` layout toggle).
- `Alt + Space`: Cycle between layouts (`splits`, `stack`, `fat`, `tall`, `grid`).
- `Alt + m`: Quick overlay monitor (`btop`) over current window (press `q` to return).
- `Alt + t` / `Alt + q`: Open new tab with CWD / close active tab.
- `Alt + Left / Right`: Navigate between tabs.

---

## CLI Autocompletions

Most command-line utilities fall into three categories for shell completion:
1. **OS Packages** (`git`, `docker`, `gh`): Handled automatically by system package managers in `/usr/share/zsh/vendor-completions/`.
2. **Community Tools** (`terraform`, `aws`, `yarn`): Provided out-of-the-box by the `zsh-completions` plugin.
3. **Standalone CLIs** (`kubectl`, `helm`, `kind`, `minikube`, `warp-cli`, `poetry`, `deno`, etc.): Cached statically in `~/.zsh/completions/` to avoid slow subshell execution on every new terminal tab.

### Adding completions for any new tool:

If you install a new CLI tool that supports shell completion (e.g. `argocd`, `k9s`, `tailscale`), generate its completion in one command:

```zsh
add-completion <command-name>
# Example:
add-completion argocd
```

### Refreshing completions:

To scan and update completions for all installed tools in bulk:

```zsh
update-completions
```

---

## Git Identity & Privacy

This repository strictly separates public dotfiles from your personal identity:
- `git/.gitconfig` contains generic settings (editor, default branch, credential helper) and is safe to be made public.
- Your personal name, email, and signing keys are stored locally in `~/.gitconfig.local`, which is ignored by `.gitignore` and never tracked or committed.

### Setting up local Git identity manually:

```bash
cp git/.gitconfig.local.example ~/.gitconfig.local
# Edit ~/.gitconfig.local with your private name and email:
# [user]
# 	name = Your Name
# 	email = your.email@example.com
```
*(If you run `install.sh`, it will automatically detect and preserve your existing Git identity into `~/.gitconfig.local`).*
