#!/usr/bin/env bash
# ==============================================================================
# Dotfiles Installer
# Compatible with: Ubuntu/Debian, Arch Linux, Fedora, and macOS
# ==============================================================================

set -eo pipefail

# Text formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

INSTALL_PACKAGES=true
INSTALL_FONTS=true

for arg in "$@"; do
	case $arg in
	--no-packages) INSTALL_PACKAGES=false ;;
	--no-fonts) INSTALL_FONTS=false ;;
	--help | -h)
		echo "Usage: ./install.sh [OPTIONS]"
		echo ""
		echo "Options:"
		echo "  --no-packages   Skip installing system packages via package manager"
		echo "  --no-fonts      Skip installing FiraCode Nerd Font"
		echo "  -h, --help      Display this help message"
		exit 0
		;;
	esac
done

# 1. Detect operating system
detect_os() {
	if [[ "$OSTYPE" == "darwin"* ]]; then
		OS="macos"
		PKG_MGR="brew"
	elif [ -f /etc/os-release ]; then
		. /etc/os-release
		case "$ID" in
		ubuntu | debian | pop | linuxmint)
			OS="debian"
			PKG_MGR="apt"
			;;
		arch | manjaro | endeavouros)
			OS="arch"
			PKG_MGR="pacman"
			;;
		fedora | rhel | centos)
			OS="fedora"
			PKG_MGR="dnf"
			;;
		*)
			OS="linux"
			PKG_MGR="unknown"
			;;
		esac
	else
		OS="unknown"
		PKG_MGR="unknown"
	fi

	ARCH=$(uname -m)
	case "$ARCH" in
	x86_64 | amd64) ARCH="x86_64" ;;
	aarch64 | arm64) ARCH="arm64" ;;
	*) ARCH="unknown" ;;
	esac

	info "Detected OS: ${OS} (${ARCH}, package manager: ${PKG_MGR})"
}

# 2. Install dependencies
install_packages() {
	if [ "$INSTALL_PACKAGES" = false ]; then
		warn "Skipping package installation (--no-packages)"
		return
	fi

	info "Installing required packages..."

	case "$PKG_MGR" in
	apt)
		sudo apt-get update -y
		sudo apt-get install -y zsh git curl ripgrep zoxide neovim unzip fontconfig bat fzf direnv git-delta tealdeer || true

		# Install eza (modern ls replacement)
		if ! command -v eza &>/dev/null && ! command -v exa &>/dev/null; then
			sudo mkdir -p /etc/apt/keyrings
			wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null || true
			echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null || true
			sudo apt-get update -y >/dev/null 2>&1 || true
			sudo apt-get install -y eza || sudo apt-get install -y exa || true
		fi

		#Install glow
		if ! command -v glow &>/dev/null; then
			sudo mkdir -p /etc/apt/keyrings
			curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
			echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
			sudo apt update && sudo apt install glow
		fi

		# Install lazygit binary if not available in apt
		if ! command -v lazygit &>/dev/null; then
			local lg_arch=""
			if [ "$ARCH" = "x86_64" ]; then
				lg_arch="Linux_x86_64"
			elif [ "$ARCH" = "arm64" ]; then
				lg_arch="Linux_arm64"
			fi

			if [ -n "$lg_arch" ]; then
				local lg_ver
				lg_ver=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" 2>/dev/null | grep -Po '"tag_name": "v\K[^"]*' || echo "")
				if [ -n "$lg_ver" ]; then
					curl -sLo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${lg_ver}_${lg_arch}.tar.gz"
					sudo tar -C /usr/local/bin -xzf /tmp/lazygit.tar.gz lazygit 2>/dev/null || true
					rm -f /tmp/lazygit.tar.gz
				fi
			fi
		fi

		sudo apt-get install -y kitty || true
		;;

	pacman)
		if [ -t 0 ]; then
			warn "Arch Linux: Running 'pacman -Syu' performs a full system rolling-release upgrade."
			warn "Note: Arch Linux does not support partial upgrades. Skipping full upgrade may cause dependency issues if system is out of date."
			read -rp "Perform full system upgrade before package installation? [y/N]: " do_upgrade
			if [[ "$do_upgrade" =~ ^[Yy]$ ]]; then
				if ! sudo pacman -Syu; then
					error "Full system upgrade failed."
					return 1
				fi
			else
				info "Skipping full system upgrade. Proceeding with package installation..."
			fi
		else
			warn "Non-interactive session: skipping full system upgrade (pacman -Syu)."
			warn "Note: Arch Linux does not support partial upgrades; dependency issues may occur if system is out of date."
		fi

		if ! sudo pacman -S --needed zsh git curl eza bat ripgrep zoxide neovim kitty ttf-firacode-nerd unzip fzf direnv git-delta tealdeer lazygit yazi glow xh dust; then
			error "Failed to install required packages via pacman."
			return 1
		fi
		;;

	dnf)
		sudo dnf install -y zsh git curl eza bat ripgrep zoxide neovim kitty fira-code-fonts unzip fzf direnv git-delta tealdeer lazygit glow
		;;

	brew)
		brew update
		brew install zsh git curl eza bat ripgrep zoxide neovim fzf direnv git-delta tealdeer lazygit yazi glow xh dust lazydocker
		brew install --cask kitty font-fira-code-nerd-font || true
		;;

	*)
		warn "Unsupported or unknown package manager. Please ensure required tools are installed manually."
		;;
	esac
	ok "Package installation completed."
}

# 3. Install FiraCode Nerd Font (Linux)
install_nerd_fonts() {
	if [ "$INSTALL_FONTS" = false ] || [ "$OS" = "macos" ]; then
		return
	fi

	if fc-list : family 2>/dev/null | grep -qi "FiraCode Nerd Font"; then
		ok "FiraCode Nerd Font is already installed."
		return
	fi

	info "Installing FiraCode Nerd Font..."
	local font_dir="$HOME/.local/share/fonts/NerdFonts"
	mkdir -p "$font_dir"
	local tmp_zip="/tmp/FiraCode.zip"

	if curl -fLo "$tmp_zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip; then
		unzip -qo "$tmp_zip" -d "$font_dir"
		rm -f "$tmp_zip"
		fc-cache -fv >/dev/null 2>&1 || true
		ok "FiraCode Nerd Font installed."
	else
		warn "Failed to download FiraCode Nerd Font. You can install it manually from https://www.nerdfonts.com"
	fi
}

# 3b. Install Zsh plugins
install_zsh_plugins() {
	info "Installing Zsh plugins..."
	local plugin_dir="$HOME/.zsh_plugins"
	mkdir -p "$plugin_dir"

	local plugins=(
		"zsh-users/zsh-completions"
		"Aloxaf/fzf-tab"
		"zsh-users/zsh-autosuggestions"
		"zdharma-continuum/fast-syntax-highlighting"
		"zsh-users/zsh-history-substring-search"
		"spaceship-prompt/spaceship-vi-mode"
		"spaceship-prompt/spaceship-prompt"
	)

	for plugin in "${plugins[@]}"; do
		local plugin_name="${plugin##*/}"
		if [ ! -d "$plugin_dir/$plugin_name" ]; then
			info "Cloning $plugin_name..."
			git clone --depth 1 "https://github.com/${plugin}" "$plugin_dir/$plugin_name" 2>/dev/null || warn "Failed to clone $plugin_name"
		else
			ok "Plugin $plugin_name is already installed."
		fi
	done
}

# 4. Safe symlink helper
link_file() {
	local src="$1"
	local dst="$2"

	mkdir -p "$(dirname "$dst")"

	if [ -e "$dst" ] || [ -L "$dst" ]; then
		if [ "$(readlink "$dst" 2>/dev/null)" = "$src" ]; then
			ok "Already linked: ${dst}"
			return
		fi

		mkdir -p "$BACKUP_DIR"
		warn "Backing up existing ${dst} -> ${BACKUP_DIR}/"
		mv "$dst" "$BACKUP_DIR/"
	fi

	ln -sf "$src" "$dst"
	ok "Created symlink: ${dst} -> ${src}"
}

# 5. Setup symlinks
setup_symlinks() {
	info "Linking configuration files..."

	link_file "${DOTFILES_DIR}/zsh/.zshrc" "$HOME/.zshrc"

	# Setup local completions directory
	if [ -L "$HOME/.zsh/completions" ] && [ "$(readlink "$HOME/.zsh/completions" 2>/dev/null)" = "${DOTFILES_DIR}/zsh/completions" ]; then
		rm -f "$HOME/.zsh/completions"
	fi
	mkdir -p "$HOME/.zsh/completions"

	# Link Kitty configuration
	mkdir -p "$HOME/.config"
	link_file "${DOTFILES_DIR}/kitty" "$HOME/.config/kitty"

	# Link Git configuration
	link_file "${DOTFILES_DIR}/git/.gitconfig" "$HOME/.gitconfig"

	ok "Symlinks created successfully."
}

# 6. Generate completions for installed CLI tools
generate_completions() {
	info "Checking and generating autocompletions for installed CLI tools..."
	local comp_dir="$HOME/.zsh/completions"
	mkdir -p "$comp_dir"

	# Broad catalog of tools across Cloud, Containers, Dev tools, and Runtimes
	# Note: terraform is handled via zsh-completions, not stdout redirection
	declare -A tools=(
		["kubectl"]="kubectl completion zsh"
		["helm"]="helm completion zsh"
		["kind"]="kind completion zsh"
		["minikube"]="minikube completion zsh"
		["k9s"]="k9s completion zsh"
		["cilium"]="cilium completion zsh"
		["argocd"]="argocd completion zsh"
		["podman"]="podman completion zsh"
		["nerdctl"]="nerdctl completion zsh"
		["stern"]="stern --completion zsh"
		["pulumi"]="pulumi gen-completion zsh"
		["tailscale"]="tailscale completion zsh"
		["warp-cli"]="warp-cli generate-completions zsh"
		["poetry"]="poetry completions zsh"
		["deno"]="deno completions zsh"
		["bun"]="bun completions zsh"
		["rustup"]="rustup completions zsh"
		["uv"]="uv generate-shell-completion zsh"
		["task"]="task --completion zsh"
	)

	local tmp_file
	for cmd in "${!tools[@]}"; do
		if command -v "$cmd" &>/dev/null; then
			if [ ! -f "$comp_dir/_$cmd" ] || [ ! -s "$comp_dir/_$cmd" ]; then
				info "Generating completion for $cmd..."
				tmp_file="$(mktemp "${comp_dir}/.comp_tmp.XXXXXX")"
				if eval "${tools[$cmd]}" >"$tmp_file" 2>/dev/null && [ -s "$tmp_file" ]; then
					mv "$tmp_file" "$comp_dir/_$cmd"
				else
					rm -f "$tmp_file"
				fi
			else
				ok "Completion for $cmd already present in ${comp_dir}/_$cmd"
			fi
		fi
	done
}

# 7. Setup local Git identity if missing
setup_git_identity() {
	if [ -f "$HOME/.gitconfig.local" ]; then
		ok "Local Git identity (~/.gitconfig.local) already exists."
		return
	fi

	# Attempt to preserve existing Git identity before linking
	local existing_name existing_email
	existing_name=$(git config --global user.name 2>/dev/null || echo "")
	existing_email=$(git config --global user.email 2>/dev/null || echo "")

	if [ -n "$existing_name" ] && [ -n "$existing_email" ]; then
		info "Preserving existing Git identity in ~/.gitconfig.local (${existing_name} <${existing_email}>)..."
		cat <<EOF >"$HOME/.gitconfig.local"
[user]
	name = ${existing_name}
	email = ${existing_email}
EOF
		ok "Created ~/.gitconfig.local from current Git configuration."
		return
	fi

	info "Setting up local Git identity (~/.gitconfig.local)..."
	if [ -t 0 ]; then
		read -rp "Enter your Git name: " git_name
		read -rp "Enter your Git email: " git_email
		if [ -n "$git_name" ] && [ -n "$git_email" ]; then
			cat <<EOF >"$HOME/.gitconfig.local"
[user]
	name = ${git_name}
	email = ${git_email}
EOF
			ok "Created ~/.gitconfig.local with your name and email."
			return
		fi
	fi

	cp "${DOTFILES_DIR}/git/.gitconfig.local.example" "$HOME/.gitconfig.local"
	warn "Created ~/.gitconfig.local template. Please update your name and email in ~/.gitconfig.local."
}

# 8. Set default shell to Zsh
set_default_shell() {
	local zsh_path
	zsh_path="$(which zsh 2>/dev/null)"
	if [ "$SHELL" != "$zsh_path" ] && [ -n "$zsh_path" ]; then
		if [ -t 0 ]; then
			info "Changing default shell to Zsh..."
			chsh -s "$zsh_path" || warn "Could not change shell automatically. Run: chsh -s ${zsh_path}"
		else
			warn "Non-interactive shell detected. To switch default shell to Zsh, run: chsh -s ${zsh_path}"
		fi
	else
		ok "Default shell is already Zsh."
	fi
}

main() {
	echo "=========================================="
	echo "  Dotfiles Installation"
	echo "=========================================="
	info "Source: ${DOTFILES_DIR}"

	detect_os
	install_packages || return 1
	install_nerd_fonts
	setup_git_identity
	setup_symlinks
	install_zsh_plugins
	generate_completions
	set_default_shell

	# Invalidate Zsh completion cache
	rm -f "$HOME"/.zcompdump* 2>/dev/null || true

	echo ""
	ok "Installation complete."
	echo "Restart your terminal or run 'exec zsh' to apply changes."
}

main "$@"
