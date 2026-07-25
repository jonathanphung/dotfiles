local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

local BASE_FONT_SIZE = 15
local BASE_WINDOW_OPACITY = 1.0
local BASE_IMAGE_TINT_OPACITY = 0.9

-- Fallback values copied from kitty/current-theme.conf. When that file is
-- present in the deployed dotfiles, it is parsed below and watched so that
-- Neovim's existing colorscheme sync updates both Kitty and WezTerm.
local south = {
  background = '#fcfcfd',
  foreground = '#323b45',
  selection_background = '#323b45',
  selection_foreground = '#fcfcfd',
  url_color = '#787571',
  cursor = '#323b45',
  cursor_text_color = 'background',
  active_border_color = '#93bcf5',
  inactive_border_color = '#edf2fd',
  active_tab_background = '#fcfcfd',
  active_tab_foreground = '#323b45',
  inactive_tab_background = '#edf2fd',
  inactive_tab_foreground = '#787571',
  tab_bar_background = '#edf2fd',
  color0 = '#fcfcfd',
  color1 = '#c1293d',
  color2 = '#2b9728',
  color3 = '#d99610',
  color4 = '#0850b5',
  color5 = '#615fb9',
  color6 = '#0092bf',
  color7 = '#323b45',
  color8 = '#b5bac4',
  color9 = '#f29130',
  color10 = '#2b9728',
  color11 = '#ceeaff',
  color12 = '#787571',
  color13 = '#323b45',
  color14 = '#008165',
  color15 = '#323b45',
}

local function read_kitty_colors(path)
  local file = io.open(path, 'r')
  if not file then
    return nil
  end

  local colors = {}
  for line in file:lines() do
    local name, value = line:match '^%s*([%w_]+)%s+([^%s]+)'
    if name and value then
      colors[name] = value
    end
  end
  file:close()

  if next(colors) then
    return colors
  end
  return nil
end

local kitty_theme_path = wezterm.home_dir .. '/.config/kitty/current-theme.conf'
local kitty_theme = read_kitty_colors(kitty_theme_path)
if kitty_theme then
  wezterm.add_to_config_reload_watch_list(kitty_theme_path)
end

local function kitty_color(name)
  local value = (kitty_theme and kitty_theme[name]) or south[name]
  if value == 'background' then
    return (kitty_theme and kitty_theme.background) or south.background
  end
  return value
end

local theme = {
  foreground = kitty_color 'foreground',
  background = kitty_color 'background',
  cursor_bg = kitty_color 'cursor',
  cursor_fg = kitty_color 'cursor_text_color',
  cursor_border = kitty_color 'cursor',
  selection_bg = kitty_color 'selection_background',
  selection_fg = kitty_color 'selection_foreground',
  split = kitty_color 'active_border_color',
  ansi = {
    kitty_color 'color0',
    kitty_color 'color1',
    kitty_color 'color2',
    kitty_color 'color3',
    kitty_color 'color4',
    kitty_color 'color5',
    kitty_color 'color6',
    kitty_color 'color7',
  },
  brights = {
    kitty_color 'color8',
    kitty_color 'color9',
    kitty_color 'color10',
    kitty_color 'color11',
    kitty_color 'color12',
    kitty_color 'color13',
    kitty_color 'color14',
    kitty_color 'color15',
  },
  tab_bar = {
    background = kitty_color 'tab_bar_background',
    active_tab = {
      bg_color = kitty_color 'active_tab_background',
      fg_color = kitty_color 'active_tab_foreground',
    },
    inactive_tab = {
      bg_color = kitty_color 'inactive_tab_background',
      fg_color = kitty_color 'inactive_tab_foreground',
    },
    inactive_tab_hover = {
      bg_color = kitty_color 'active_tab_background',
      fg_color = kitty_color 'active_tab_foreground',
    },
    new_tab = {
      bg_color = kitty_color 'inactive_tab_background',
      fg_color = kitty_color 'inactive_tab_foreground',
    },
    new_tab_hover = {
      bg_color = kitty_color 'active_tab_background',
      fg_color = kitty_color 'active_tab_foreground',
    },
  },
}

config.colors = theme
config.font = wezterm.font_with_fallback {
  'CaskaydiaMono Nerd Font Mono',
  'Symbols Nerd Font Mono',
}
config.font_size = BASE_FONT_SIZE
config.harfbuzz_features = {
  'calt=0',
  'clig=0',
  'liga=0',
}

config.window_padding = {
  left = 4,
  right = 4,
  top = 4,
  bottom = 4,
}
config.window_decorations = 'TITLE | RESIZE'
config.window_close_confirmation = 'AlwaysPrompt'
config.hide_mouse_cursor_when_typing = false

config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = false

-- Match Kitty's opaque non-default cell backgrounds.
config.text_background_opacity = 1.0

local supported_image_extensions = {
  bmp = true,
  dds = true,
  ff = true,
  gif = true,
  ico = true,
  jpeg = true,
  jpg = true,
  png = true,
  pnm = true,
  tga = true,
  tif = true,
  tiff = true,
}

local function find_background_images()
  local images = {}
  local seen = {}
  local patterns = {
    wezterm.config_dir .. '/backgrounds/*',
    wezterm.home_dir .. '/.config/kitty/backgrounds/*',
  }

  for _, pattern in ipairs(patterns) do
    local ok, matches = pcall(wezterm.glob, pattern)
    if ok then
      for _, path in ipairs(matches) do
        local extension = path:lower():match '%.([^./\\]+)$'
        local key = path:lower()
        if supported_image_extensions[extension] and not seen[key] then
          seen[key] = true
          table.insert(images, path)
        end
      end
    end
  end

  table.sort(images)
  return images
end

local background_images = find_background_images()

-- Kitty's "scaled" layout stretches the image to the window. The solid color
-- layer over it gives default-background cells the configured 90% opacity.
local function image_background(path, opacity)
  return {
    {
      source = { File = path },
      width = '100%',
      height = '100%',
      repeat_x = 'NoRepeat',
      repeat_y = 'NoRepeat',
    },
    {
      source = { Color = theme.background },
      width = '100%',
      height = '100%',
      opacity = opacity,
    },
  }
end

if #background_images > 0 then
  config.background = image_background(background_images[1], BASE_IMAGE_TINT_OPACITY)
  config.window_background_opacity = 1.0
else
  config.window_background_opacity = BASE_WINDOW_OPACITY
end

-- Acrylic causes noticeable DWM latency while dragging this window.
if wezterm.target_triple:find 'windows' then
  config.win32_system_backdrop = 'Disable'
end

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function basename(path)
  return (path:gsub('^.*[/\\]', ''))
end

local function image_path_from_background(background)
  if not background or not background[1] or not background[1].source then
    return nil
  end

  local file = background[1].source.File
  if type(file) == 'table' then
    return file.path
  end
  return file
end

local function current_image(window)
  local overrides = window:get_config_overrides() or {}
  return image_path_from_background(overrides.background) or background_images[1]
end

local function current_image_opacity(window)
  local overrides = window:get_config_overrides() or {}
  if overrides.background and overrides.background[2] then
    return overrides.background[2].opacity or BASE_IMAGE_TINT_OPACITY
  end
  return BASE_IMAGE_TINT_OPACITY
end

local function adjust_opacity(delta)
  return wezterm.action_callback(function(window, pane)
    local overrides = window:get_config_overrides() or {}
    local opacity

    if #background_images > 0 then
      opacity = clamp(current_image_opacity(window) + delta, 0.1, 1.0)
      overrides.background = image_background(current_image(window), opacity)
    else
      local effective = window:effective_config()
      opacity = clamp(effective.window_background_opacity + delta, 0.1, 1.0)
      overrides.window_background_opacity = opacity
    end

    window:set_config_overrides(overrides)
    window:toast_notification(
      'WezTerm',
      string.format('Background opacity: %d%%', math.floor(opacity * 100 + 0.5)),
      nil,
      1500
    )
  end)
end

local cycle_background = wezterm.action_callback(function(window, pane)
  if #background_images == 0 then
    window:toast_notification(
      'WezTerm',
      'No images found in ~/.config/wezterm/backgrounds or ~/.config/kitty/backgrounds',
      nil,
      2500
    )
    return
  end

  local active = current_image(window)
  local current_index = 1
  for index, path in ipairs(background_images) do
    if path == active then
      current_index = index
      break
    end
  end

  local next_index = (current_index % #background_images) + 1
  local overrides = window:get_config_overrides() or {}
  overrides.background =
    image_background(background_images[next_index], current_image_opacity(window))
  window:set_config_overrides(overrides)
  window:toast_notification(
    'WezTerm',
    'Background: ' .. basename(background_images[next_index]),
    nil,
    1500
  )
end)

local function change_font_size(delta)
  return wezterm.action_callback(function(window, pane)
    local overrides = window:get_config_overrides() or {}
    overrides.font_size = clamp(window:effective_config().font_size + delta, 6, 72)
    window:set_config_overrides(overrides)
  end)
end

local reset_font_size = wezterm.action_callback(function(window, pane)
  local overrides = window:get_config_overrides() or {}
  overrides.font_size = nil
  window:set_config_overrides(overrides)
end)

local rename_tab = act.PromptInputLine {
  description = 'Enter a title for this tab',
  action = wezterm.action_callback(function(window, pane, line)
    if line then
      window:active_tab():set_title(line)
    end
  end),
}

-- Mirror pass_keys.py: send CTRL-SHIFT-hjkl through to Vim/Neovim/fzf,
-- otherwise use the same keys to focus a neighboring WezTerm pane.
local passthrough_processes = {
  fzf = true,
  nvim = true,
  vim = true,
}

local function is_passthrough_process(pane)
  local ok, info = pcall(function()
    return pane:get_foreground_process_info()
  end)
  if not ok or not info or not info.executable then
    return false
  end

  local process = basename(info.executable):lower():gsub('%.exe$', '')
  return passthrough_processes[process] or false
end

local function smart_pane_navigation(direction, key)
  return wezterm.action_callback(function(window, pane)
    if is_passthrough_process(pane) then
      window:perform_action(
        act.SendKey {
          key = key,
          mods = 'CTRL|SHIFT',
        },
        pane
      )
    else
      window:perform_action(act.ActivatePaneDirection(direction), pane)
    end
  end)
end

local function nvim_is_available()
  local command
  if wezterm.target_triple:find 'windows' then
    command = { 'where.exe', 'nvim' }
  else
    command = { 'sh', '-c', 'command -v nvim' }
  end
  return wezterm.run_child_process(command)
end

local function scrollback_in_nvim(last_command_only)
  return wezterm.action_callback(function(window, pane)
    if not nvim_is_available() then
      window:toast_notification(
        'WezTerm',
        'Neovim is not on PATH; opening WezTerm copy mode instead',
        nil,
        2500
      )
      window:perform_action(act.ActivateCopyMode, pane)
      return
    end

    local text
    if last_command_only then
      local ok, zones = pcall(function()
        return pane:get_semantic_zones 'Output'
      end)
      if ok and zones and #zones > 0 then
        text = pane:get_text_from_semantic_zone(zones[#zones])
      end
    end

    if not text or text == '' then
      local dimensions = pane:get_dimensions()
      text = pane:get_lines_as_text(dimensions.scrollback_rows)
    end

    local name = os.tmpname()
    local file, err = io.open(name, 'wb')
    if not file then
      window:toast_notification('WezTerm', 'Could not save scrollback: ' .. err, nil, 2500)
      return
    end

    file:write(text)
    file:close()
    window:perform_action(
      act.SpawnCommandInNewTab {
        args = { 'nvim', name },
      },
      pane
    )

    -- This follows WezTerm's documented scrollback-to-Vim recipe: Neovim
    -- reads the file immediately, so it can be removed after a short delay.
    wezterm.sleep_ms(1000)
    os.remove(name)
  end)
end

config.keys = {
  -- Dynamic background opacity and background image rotation.
  { key = '-', mods = 'CTRL', action = adjust_opacity(-0.1) },
  { key = '=', mods = 'CTRL', action = adjust_opacity(0.1) },
  { key = 'B', mods = 'CTRL|SHIFT', action = cycle_background },

  -- Kitty's Command-key controls become Alt-key controls on Windows.
  { key = '+', mods = 'ALT', action = change_font_size(4) },
  { key = '=', mods = 'ALT', action = change_font_size(4) },
  { key = '-', mods = 'ALT', action = change_font_size(-4) },
  { key = '0', mods = 'ALT', action = reset_font_size },
  { key = 'Enter', mods = 'ALT', action = rename_tab },
  { key = 'w', mods = 'ALT', action = act.CloseCurrentTab { confirm = false } },

  -- Tab navigation and ordering.
  { key = 'l', mods = 'CTRL', action = act.ActivateTabRelative(1) },
  { key = 'h', mods = 'CTRL', action = act.ActivateTabRelative(-1) },
  { key = ',', mods = 'CTRL', action = act.MoveTabRelative(-1) },
  { key = '.', mods = 'CTRL', action = act.MoveTabRelative(1) },
  { key = ',', mods = 'CTRL|SHIFT', action = act.Nop },
  { key = '.', mods = 'CTRL|SHIFT', action = act.Nop },

  -- Pane creation and smart pane/Neovim navigation.
  {
    key = 'Enter',
    mods = 'CTRL',
    action = act.SplitPane { direction = 'Down', size = { Percent = 50 } },
  },
  {
    key = 'Enter',
    mods = 'CTRL|SHIFT',
    action = act.SplitPane { direction = 'Right', size = { Percent = 50 } },
  },
  { key = 'H', mods = 'CTRL|SHIFT', action = smart_pane_navigation('Left', 'h') },
  { key = 'J', mods = 'CTRL|SHIFT', action = smart_pane_navigation('Down', 'j') },
  { key = 'K', mods = 'CTRL|SHIFT', action = smart_pane_navigation('Up', 'k') },
  { key = 'L', mods = 'CTRL|SHIFT', action = smart_pane_navigation('Right', 'l') },

  -- Last command output and full scrollback in a real Neovim tab.
  { key = 'V', mods = 'ALT|SHIFT', action = scrollback_in_nvim(true) },
  { key = 'V', mods = 'CTRL|ALT|SHIFT', action = scrollback_in_nvim(false) },
}

for index = 1, 9 do
  table.insert(config.keys, {
    key = tostring(index),
    mods = 'ALT',
    action = act.ActivateTab(index - 1),
  })
end

return config
