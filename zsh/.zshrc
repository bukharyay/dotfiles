# ==============================================================================
# ENVIRONMENT & BASIC SETTINGS
# ==============================================================================
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Default Editor (Auto-detect: nvim -> vim -> vi)
if command -v nvim &>/dev/null; then
  export EDITOR=nvim
elif command -v vim &>/dev/null; then
  export EDITOR=vim
else
  export EDITOR=vi
fi

# Ensure unique entries in PATH and FPATH
typeset -U path PATH
typeset -U fpath FPATH

# PATH additions
path=(
  "$HOME/.local/bin"
  "$HOME/.cargo/bin"
  "$HOME/go/bin"
  "$HOME/.opencode/bin"
  $path
)

# PYENV (Python Version Manager)
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && path=("$PYENV_ROOT/bin" $path)
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init - zsh)"
  eval "$(pyenv virtualenv-init - zsh)" 2>/dev/null
fi

# NVM (Node Version Manager - Hardened Pure Lazy Loader)
export NVM_DIR="$HOME/.nvm"
typeset -g _nvm_lazy_state=0

_load_nvm() {
  if (( _nvm_lazy_state == 2 )); then
    return 0
  fi
  if (( _nvm_lazy_state == 1 )); then
    return 1
  fi
  _nvm_lazy_state=1

  if [[ ! -r "$NVM_DIR/nvm.sh" ]]; then
    _nvm_lazy_state=0
    echo "[nvm] Error: NVM script not found or unreadable at '$NVM_DIR/nvm.sh'." >&2
    return 1
  fi

  local pre_path="$PATH"
  unset -f nvm node npm npx corepack 2>/dev/null

  local nvm_sh_status=0
  \. "$NVM_DIR/nvm.sh" || nvm_sh_status=$?

  if (( nvm_sh_status == 0 )) && typeset -f nvm >/dev/null 2>&1; then
    _nvm_lazy_state=2
    if [[ -r "$NVM_DIR/bash_completion" ]]; then
      \. "$NVM_DIR/bash_completion" || true
    fi
    return 0
  else
    _nvm_lazy_state=0
    export PATH="$pre_path"
    echo "[nvm] Error: Sourcing '$NVM_DIR/nvm.sh' failed (exit: $nvm_sh_status) or 'nvm' function was not defined." >&2
    _nvm_install_wrappers
    return 1
  fi
}

_nvm_dispatch_cmd() {
  local cmd="$1"; shift
  if _load_nvm; then
    "$cmd" "$@"
    return $?
  fi
  if (( $+commands[$cmd] )); then
    command "$cmd" "$@"
    return $?
  else
    echo "[nvm] Error: Command '$cmd' not found on system." >&2
    return 127
  fi
}

_nvm_install_wrappers() {
  nvm() {
    if _load_nvm; then
      nvm "$@"
      return $?
    fi
    echo "[nvm] Error: nvm command is unavailable (loader failed)." >&2
    return 127
  }
  node() { _nvm_dispatch_cmd node "$@"; }
  npm() { _nvm_dispatch_cmd npm "$@"; }
  npx() { _nvm_dispatch_cmd npx "$@"; }
  corepack() { _nvm_dispatch_cmd corepack "$@"; }
}

_nvm_install_wrappers


# --- NODE PROJECT LOCAL BIN ---
# Automatically expose the nearest node_modules/.bin in the current directory tree.
autoload -Uz add-zsh-hook

function update_node_project_path() {
  local dir="$PWD"
  local node_bin=""

  # Remove previously added node_modules/.bin entries
  path=("${(@)path:#*/node_modules/.bin}")

  # Walk upward until we find node_modules/.bin
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/node_modules/.bin" ]]; then
      node_bin="$dir/node_modules/.bin"
      break
    fi
    dir="${dir:h}"
  done

  # Add nearest project local binaries to PATH
  if [[ -n "$node_bin" ]]; then
    path=("$node_bin" $path)
  fi
}

add-zsh-hook chpwd update_node_project_path
update_node_project_path


# ==============================================================================
# THEME CONFIGURATION (SPACESHIP)
# ==============================================================================
SPACESHIP_PROMPT_ORDER=(
  time           # Time stamps section
  user           # Username section
  dir            # Current directory section
  host           # Hostname section
  git            # Git section (git_branch + git_status)
  hg             # Mercurial section
  package        # Package version
  node           # Node.js section
  bun            # Bun section
  deno           # Deno section
  ruby           # Ruby section
  python         # Python section
  elm            # Elm section
  elixir         # Elixir section
  xcode          # Xcode section
  xcenv          # xcenv section
  swift          # Swift section
  swiftenv       # swiftenv section
  golang         # Go section
  perl           # Perl section
  php            # PHP section
  rust           # Rust section
  haskell        # Haskell section
  scala          # Scala section
  kotlin         # Kotlin section
  java           # Java section
  lua            # Lua section
  dart           # Dart section
  julia          # Julia section
  crystal        # Crystal section
  docker         # Docker section
  docker_compose # Docker compose section
  aws            # AWS section
  gcloud         # GCP section
  azure          # Azure section
  venv           # virtualenv section
  conda          # conda section
  uv             # uv section
  dotnet         # .NET section
  ocaml          # OCaml section
  vlang          # V section
  zig            # Zig section
  purescript     # PureScript section
  erlang         # Erlang section
  gleam          # Gleam section
  kubectl        # Kubectl context section
  ansible        # Ansible section
  terraform      # Terraform section
  pulumi         # Pulumi stack section
  ibmcloud       # IBM Cloud section
  nix_shell      # Nix shell
  gnu_screen     # GNU Screen section
  exec_time      # Execution time
  async          # Async jobs indicator
  line_sep       # Line break
  battery        # Battery level
  jobs           # Background jobs indicator
  exit_code      # Exit code section
  sudo           # Sudo indicator
  vi_mode        # Vi-mode indicator
  char           # Prompt character
)

SPACESHIP_CHAR_SYMBOL="❯"
SPACESHIP_CHAR_SUFFIX=" "


# ==============================================================================
# PLUGIN MANAGER & AUTOCOMPLETION
# ==============================================================================
autoload -Uz zrecompile

PLUGIN_DIR=$HOME/.zsh_plugins

plugins=(
  zsh-users/zsh-completions
  Aloxaf/fzf-tab
  zsh-users/zsh-autosuggestions
  zdharma-continuum/fast-syntax-highlighting
  zsh-users/zsh-history-substring-search
  spaceship-prompt/spaceship-vi-mode
  spaceship-prompt/spaceship-prompt
)

# 1. Check for missing plugins passively (no network access during shell startup)
local -a _missing_plugins=()
for plugin in $plugins; do
  local plugin_name=${plugin:t}
  [[ ! -d "$PLUGIN_DIR/$plugin_name" ]] && _missing_plugins+=("$plugin_name")
done

if (( ${#_missing_plugins[@]} > 0 )) && [[ -o interactive ]] && [[ -t 2 ]]; then
  echo "[!] Zsh plugins missing (${#_missing_plugins[@]}): run 'install-plugins' to download them." >&2
fi

# Function to explicitly install or update plugins on demand
install-plugins() {
  local count=0
  mkdir -p "$PLUGIN_DIR"
  for plugin in $plugins; do
    local plugin_name=${plugin:t}
    if [[ ! -d "$PLUGIN_DIR/$plugin_name" ]]; then
      echo "  [+] Cloning $plugin_name from GitHub..."
      if git clone --depth 1 "https://github.com/${plugin}" "$PLUGIN_DIR/$plugin_name"; then
        (( count++ ))
      else
        echo "  [!] Failed to clone $plugin_name" >&2
      fi
    else
      echo "  [ok] $plugin_name is already installed"
    fi
  done
  if (( count > 0 )); then
    echo "Done. Installed $count plugin(s). Run 'exec zsh' to activate."
  else
    echo "All plugins are already installed."
  fi
}

# 2. Add completion paths to fpath BEFORE compinit
# Prioritizes custom completions from dotfiles repo
[[ -d $HOME/.zsh/completions ]] && fpath=($HOME/.zsh/completions $fpath)
[[ -d $HOME/.zfunc ]] && fpath=($HOME/.zfunc $fpath)
if [[ -d $PLUGIN_DIR/zsh-completions/src ]]; then
  fpath=($PLUGIN_DIR/zsh-completions/src $fpath)
fi

# 3. Initialize Completion System (compinit)
# Load complist before compinit per official documentation for menu-select widget
zmodload -i zsh/complist
autoload -Uz compinit
compinit -i


# 4. Completion Styling (zstyle) & FZF-TAB Options
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' # Case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}" # Colors
zstyle ':completion:*' menu no # Let fzf-tab take over

# Adaptive preview command for fzf-tab
if command -v eza &>/dev/null; then
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --color=always --icons=always -1 $realpath'
elif command -v exa &>/dev/null; then
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa --color=always --icons -1 $realpath'
else
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath'
fi

# 5. Load plugins in proper sequence
load_plugin() {
  local name=$1
  if [[ -f $PLUGIN_DIR/$name/$name.plugin.zsh ]]; then
    source $PLUGIN_DIR/$name/$name.plugin.zsh
  elif [[ -f $PLUGIN_DIR/$name/$name.zsh ]]; then
    source $PLUGIN_DIR/$name/$name.zsh
  elif [[ -f $PLUGIN_DIR/$name/spaceship.zsh ]]; then
    source $PLUGIN_DIR/$name/spaceship.zsh
  fi
}

# fzf-tab MUST be loaded after compinit, but before widget-wrapping plugins
load_plugin fzf-tab

# Autosuggestions
load_plugin zsh-autosuggestions

# Fast Syntax Highlighting (should be near end)
load_plugin fast-syntax-highlighting

# History Substring Search (must be loaded after syntax highlighting)
load_plugin zsh-history-substring-search

# Spaceship Prompt and additions
load_plugin spaceship-vi-mode
load_plugin spaceship-prompt


# ==============================================================================
# HISTORY CONFIGURATION
# ==============================================================================
HISTFILE=$HOME/.zsh_history
HISTSIZE=100000
SAVEHIST=$HISTSIZE
setopt append_history hist_expire_dups_first hist_ignore_dups hist_ignore_all_dups \
       hist_find_no_dups hist_ignore_space hist_save_no_dups share_history


# ==============================================================================
# SHELL OPTIONS (setopt)
# ==============================================================================
setopt auto_cd auto_list auto_menu always_to_end interactive_comments


# ==============================================================================
# KEYBINDINGS
# ==============================================================================
# History substring search (Up / Down)
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[[3~' delete-char
bindkey '^L' clear-screen

# Ctrl + Panah Kiri / Kanan
bindkey '^[[1;5C' forward-word  # Ctrl + panah kanan
bindkey '^[[1;5D' backward-word # Ctrl + panah kiri

# Native Select & Delete
bindkey '^@' set-mark-command
bindkey '^x' kill-region
bindkey '^v' yank


# ==============================================================================
# TOOL INTEGRATIONS & COMPLETIONS
# ==============================================================================
# ZOXIDE (Smarter cd)
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# FZF (Interactive fuzzy finder keybindings & completion)
if command -v fzf &>/dev/null; then
  if fzf --zsh &>/dev/null; then
    source <(fzf --zsh)
  else
    for fzf_dir in /usr/share/doc/fzf/examples /usr/share/fzf /opt/homebrew/opt/fzf/shell /usr/local/opt/fzf/shell; do
      if [[ -f "$fzf_dir/key-bindings.zsh" ]]; then
        source "$fzf_dir/key-bindings.zsh"
        [[ -f "$fzf_dir/completion.zsh" ]] && source "$fzf_dir/completion.zsh"
        break
      fi
    done
  fi
  export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"
fi

# DIRENV (Auto load/unload per-directory environment variables)
if command -v direnv &>/dev/null; then
  eval "$(direnv hook zsh)"
fi

# ------------------------------------------------------------------------------
# Universal Autocompletion Helpers
# ------------------------------------------------------------------------------

# Add/generate autocompletion for ANY installed CLI command
# Usage: add-completion <command>
add-completion() {
  local cmd="$1"
  if [[ -z "$cmd" ]]; then
    echo "Usage: add-completion <command-name>"
    echo "Example: add-completion argocd"
    return 1
  fi

  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: Command '$cmd' not found on this system." >&2
    return 1
  fi

  local comp_dir="$HOME/.zsh/completions"
  mkdir -p "$comp_dir"
  local target="$comp_dir/_$cmd"
  local tmp_file
  tmp_file="$(mktemp "${comp_dir}/.comp_tmp.XXXXXX")"

  # Probe common completion subcommands and flags
  if "$cmd" completion zsh > "$tmp_file" 2>/dev/null && [[ -s "$tmp_file" ]]; then
    mv "$tmp_file" "$target"
  elif "$cmd" generate-completions zsh > "$tmp_file" 2>/dev/null && [[ -s "$tmp_file" ]]; then
    mv "$tmp_file" "$target"
  elif "$cmd" completions zsh > "$tmp_file" 2>/dev/null && [[ -s "$tmp_file" ]]; then
    mv "$tmp_file" "$target"
  elif "$cmd" --completion zsh > "$tmp_file" 2>/dev/null && [[ -s "$tmp_file" ]]; then
    mv "$tmp_file" "$target"
  else
    rm -f "$tmp_file"
    echo "Could not auto-detect completion syntax for '$cmd'." >&2
    echo "Please check '$cmd --help' to see its completion command." >&2
    return 1
  fi

  rm -f "$HOME"/.zcompdump* 2>/dev/null
  echo "[+] Generated autocompletion for '$cmd' in $target"
  echo "Reload shell with 'exec zsh' to activate."
}

# Scan and update completions for all known modern CLI tools installed on this machine
update-completions() {
  local comp_dir="$HOME/.zsh/completions"
  mkdir -p "$comp_dir"
  local count=0

  # Broad catalog covering Cloud, Kubernetes, Container, Language Runtimes, and Utilities
  # Note: terraform is handled via zsh-completions or autocomplete install, not stdout generation
  local -A tools=(
    # Kubernetes & Containers
    [kubectl]="kubectl completion zsh"
    [helm]="helm completion zsh"
    [kind]="kind completion zsh"
    [minikube]="minikube completion zsh"
    [k9s]="k9s completion zsh"
    [cilium]="cilium completion zsh"
    [argocd]="argocd completion zsh"
    [podman]="podman completion zsh"
    [nerdctl]="nerdctl completion zsh"
    [stern]="stern --completion zsh"
    # Cloud, Networking & Infra
    [pulumi]="pulumi gen-completion zsh"
    [tailscale]="tailscale completion zsh"
    [warp-cli]="warp-cli generate-completions zsh"
    # Runtimes & Dev Tools
    [poetry]="poetry completions zsh"
    [deno]="deno completions zsh"
    [bun]="bun completions zsh"
    [rustup]="rustup completions zsh"
    [uv]="uv generate-shell-completion zsh"
    [task]="task --completion zsh"
  )

  local tmp_file
  for cmd in ${(k)tools}; do
    if command -v "$cmd" &>/dev/null; then
      tmp_file="$(mktemp "${comp_dir}/.comp_tmp.XXXXXX")"
      if eval "${tools[$cmd]}" > "$tmp_file" 2>/dev/null && [[ -s "$tmp_file" ]]; then
        mv "$tmp_file" "$comp_dir/_$cmd"
        echo "  [+] Generated: $cmd"
        (( count++ ))
      else
        rm -f "$tmp_file"
      fi
    fi
  done

  rm -f "$HOME"/.zcompdump* 2>/dev/null
  echo "Done. $count completion(s) generated/updated in $comp_dir."
  echo "Reload shell with 'exec zsh' to activate."
}


# ==============================================================================
# UNIVERSAL ALIASES (CROSS-PLATFORM)
# ==============================================================================
# ls / ll (eza -> exa -> ls)
if command -v eza &>/dev/null; then
  alias ls='eza --icons'
  alias ll='eza -l --all --group --icons --time-style=long-iso'
  alias lln='ll --sort=name'
  alias llt='ll --sort=modified --reverse'
  alias lls='ll --sort=size --reverse'
elif command -v exa &>/dev/null; then
  alias ls='exa --icons'
  alias ll='exa -l --all --group --icons --time-style=long-iso'
  alias lln='ll --sort=name'
  alias llt='ll --sort=modified --reverse'
  alias lls='ll --sort=size --reverse'
else
  alias ls='ls --color=auto'
  alias ll='ls -la'
fi

# cat (batcat -> bat -> cat)
if command -v batcat &>/dev/null; then
  alias cat='batcat --style=plain --paging=never'
elif command -v bat &>/dev/null; then
  alias cat='bat --style=plain --paging=never'
fi

# Editor & CLI productivity tools
command -v nvim &>/dev/null && alias vi='nvim'
command -v lazygit &>/dev/null && alias lg='lazygit'
command -v glow &>/dev/null && alias md='glow'
command -v du-dust &>/dev/null && ! command -v dust &>/dev/null && alias dust='du-dust'
command -v btop &>/dev/null && alias top='btop' && alias sys='btop'

# Yazi file manager with auto-cd on exit
if command -v yazi &>/dev/null; then
  function y() {
    local tmp
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    local cwd
    if cwd="$(cat -- "$tmp" 2>/dev/null)" && [[ -n "$cwd" ]] && [[ "$cwd" != "$PWD" ]]; then
      builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
  }
fi

# Docker shortcuts
alias d='docker'
alias dc='docker compose'
alias don='docker container'
alias dv='docker volume'
alias di='docker image'
alias dp='docker ps'
alias dl='docker logs'
alias dst='docker stats'
command -v lazydocker &>/dev/null && alias lzd='lazydocker'

# Cheat.sh query helper (Usage: cht <tool> or cht <lang> <topic...>)
cht() {
  if [ "$#" -eq 0 ]; then
    echo "Usage: cht <command> OR cht <language> <topic...>"
    echo "Example: cht tar"
    echo "Example: cht python list comprehension"
    return 1
  fi

  if ! command -v curl &>/dev/null; then
    echo "Error: curl is required for cht." >&2
    return 1
  fi

  local target="$1"
  shift

  local url
  if [ "$#" -eq 0 ]; then
    url="https://cht.sh/${target// /+}"
  else
    local query
    query=$(printf "%s+" "$@")
    query="${query%+}"
    query="${query// /+}"
    url="https://cht.sh/${target}/${query}"
  fi

  # Safely resolve pager in Zsh (avoids unquoted scalar tokenization bug)
  local -a pager_cmd
  if [[ -n "$PAGER" ]]; then
    pager_cmd=(${(z)PAGER})
  elif command -v less &>/dev/null; then
    pager_cmd=(less -R)
  else
    pager_cmd=(cat)
  fi

  local response
  if ! response=$(curl -fsSL "$url"); then
    echo "Error: Failed to fetch cheat sheet from cht.sh (URL: $url)" >&2
    return 1
  fi

  if [[ -t 1 ]]; then
    echo "$response" | "${pager_cmd[@]}"
  else
    echo "$response"
  fi
}
