local config_options = require('nvim-scout.lib.config_options')

logging_defaults = {
    level = config_options.scout_log_level.OFF
}

search_bar_defaults = {
   size = config_options.scout_sizes.MED,
   theme = config_options.scout_themes.DEFAULT
}

keymap_defaults = {
    toggle_search = '/',
    focus_search = 'f',
    clear_search = 'c',
    search_curr_word = '#',
    prev_result = 'N',
    next_result = 'n',
    prev_history = '<UP>',
    next_history = '<DOWN>',
    case_sensitive_toggle = '<leader>c',
    pattern_toggle = '<leader>r',
}

local config = {

defaults = {
    keymaps = keymap_defaults,
    search = search_bar_defaults,
    logging = logging_defaults,
}

}

local function create_config_copy(t)
  local copy = {}
  for k, v in pairs(t) do
    copy[k] = type(v) == "table" and create_config_copy(v) or v
  end
  return copy
end
config.new = function()
    return create_config_copy(config)
end

return config
