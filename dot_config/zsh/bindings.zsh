# =========================================================
# Keybindings
# =========================================================

# Cursor shape per vi mode
ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK

# Disable command mode line highlight
ZVM_VI_HIGHLIGHT_BACKGROUND=none
ZVM_VI_HIGHLIGHT_FOREGROUND=none
ZVM_VI_HIGHLIGHT_EXTRASTYLE=none

# Starship cannot detect zsh visual mode from KEYMAP. Export zsh-vi-mode's
# explicit mode state for the prompt instead.
zvm_after_select_vi_mode() {
  case $ZVM_MODE in
    $ZVM_MODE_NORMAL)
      export STARSHIP_ZVM_SYMBOL=N
      ;;
    $ZVM_MODE_VISUAL|$ZVM_MODE_VISUAL_LINE)
      export STARSHIP_ZVM_SYMBOL=❮
      ;;
    $ZVM_MODE_REPLACE)
      export STARSHIP_ZVM_SYMBOL=R
      ;;
    *)
      unset STARSHIP_ZVM_SYMBOL
      ;;
  esac
}

# zsh-vi-mode resets all bindings on init, so custom bindings
# must be registered via this hook to survive.
zvm_after_init() {
  # Ctrl+Right -> move forward one word (^[[1;5C is the terminal escape code)
  bindkey '^[[1;5C' forward-word

  # Ctrl+Left -> move backward one word (^[[1;5D is the terminal escape code)
  bindkey '^[[1;5D' backward-word

  # Ctrl+F -> fzf file picker (no hidden files)
  bindkey '^F' _fzf_file_no_hidden

  # Ctrl+R -> fzf history search (zsh-vi-mode's reset restores zsh's stock
  # history-incremental-search-backward on this key, clobbering fzf's binding)
  bindkey '^R' fzf-history-widget

  # Ctrl+\ -> toggle autosuggestions (useful for screen recordings)
  bindkey '^\' autosuggest-toggle

  # Up/Down -> history search by substring (^[[A/^[[B are up/down arrow escape codes)
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
}

# zsh's normal mode only edits the current command line -- it has no
# visibility into the terminal's scrollback. These widgets shell out to
# kitty's remote control to scroll the actual window instead, bound to vi
# mode (vicmd) only, using Vim's own scroll keys (^E/^Y line, ^U/^D
# half-page, ^B/^F full-page) so it feels like scrolling inside real Vim.
# ^D overrides zsh-vi-mode's default list-choices binding in normal mode.
function zvm_after_lazy_keybindings() {
  _kitty_scroll() { kitty @ scroll-window "$1" >/dev/null 2>&1 }
  zvm_kitty_scroll_line_down() { _kitty_scroll 1 }
  zvm_kitty_scroll_line_up()   { _kitty_scroll 1- }
  zvm_kitty_scroll_half_down() { _kitty_scroll 0.5p }
  zvm_kitty_scroll_half_up()   { _kitty_scroll 0.5p- }
  zvm_kitty_scroll_page_down() { _kitty_scroll 1p }
  zvm_kitty_scroll_page_up()   { _kitty_scroll 1p- }

  zvm_define_widget zvm_kitty_scroll_line_down
  zvm_define_widget zvm_kitty_scroll_line_up
  zvm_define_widget zvm_kitty_scroll_half_down
  zvm_define_widget zvm_kitty_scroll_half_up
  zvm_define_widget zvm_kitty_scroll_page_down
  zvm_define_widget zvm_kitty_scroll_page_up

  zvm_bindkey vicmd '^E' zvm_kitty_scroll_line_down
  zvm_bindkey vicmd '^Y' zvm_kitty_scroll_line_up
  zvm_bindkey vicmd '^D' zvm_kitty_scroll_half_down
  zvm_bindkey vicmd '^U' zvm_kitty_scroll_half_up
  zvm_bindkey vicmd '^F' zvm_kitty_scroll_page_down
  zvm_bindkey vicmd '^B' zvm_kitty_scroll_page_up

  # Keep j/k for command-history navigation in vi command mode.
  zvm_bindkey vicmd 'j' down-line-or-history
  zvm_bindkey vicmd 'k' up-line-or-history

  # Match Vim: pressing v again exits Visual mode instead of opening $EDITOR.
  zvm_bindkey visual 'v' zvm_enter_visual_mode

  # Open terminal scrollback in real NeoVim with V from vi command mode,
  # leaving lowercase v available for Visual mode.
  zvm_vi_scrollback() {
    kitty @ action kitty_scrollback_nvim --no-response >/dev/null 2>&1
  }
  zvm_define_widget zvm_vi_scrollback
  zvm_bindkey vicmd 'V' zvm_vi_scrollback
}
