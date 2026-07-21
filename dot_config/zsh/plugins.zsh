# =========================================================
# Plugins
# =========================================================

ZPLUGINDIR="${ZDOTDIR:-$HOME/.config/zsh}/plugins"

_zplugin_load() {
  local plugin_path="${ZPLUGINDIR}/${2}"
  if [[ ! -d "$plugin_path" ]]; then
    mkdir -p "$ZPLUGINDIR"
    echo "Installing ${2}..."
    git clone --depth=1 "https://github.com/${1}/${2}" "$plugin_path" \
      || { echo "ERROR: failed to install ${2}" >&2; return 1; }
  fi
  source "${plugin_path}/${2}.plugin.zsh"
}

export ZVM_SYSTEM_CLIPBOARD_ENABLED=true

zplugin-update() {
  local dir
  for dir in "${ZPLUGINDIR}"/*/; do
    echo "Updating ${dir:t}..."
    git -C "$dir" pull --ff-only
  done
}

_zplugin_load zsh-users zsh-autosuggestions
_zplugin_load zsh-users zsh-history-substring-search
_zplugin_load jeffreytse zsh-vi-mode
_zplugin_load zdharma-continuum fast-syntax-highlighting

# fast-syntax-highlighting compiles its theme into a cache dir outside the
# plugin's own (gitignored) directory. Recompile from our overlay
# (~/.config/fsh/overlay.ini, recolors unrecognized-command text from red to
# blue) if that cache is missing, e.g. on a fresh machine.
if [[ ! -f "${XDG_CACHE_HOME:-$HOME/.cache}/fsh/theme_overlay.zsh" ]]; then
  fast-theme XDG:overlay -q
fi
