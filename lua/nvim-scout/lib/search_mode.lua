scout_search_mode = {}
local consts = require("nvim-scout.lib.consts")

scout_search_mode.__index = scout_search_mode
function scout_search_mode:new(mode_name, mode_symbol, ns, text_color, border_hl)
    local obj = {
        name = mode_name,
        symbol = mode_symbol,
        search_bar_win = consts.window.INVALID_WINDOW_ID,
        display_col = 0,
        banner_config = {
            relative='win',
            row=2,
            zindex=1,
            width=#mode_name + consts.modes.padding_space,
            height=1,
            border = {},
            focusable=false,
            footer={{consts.modes.footer_text, consts.colorscheme_groups.m_virt_text_c}},
            style="minimal",
        },
        active = false,
        namespace = ns,
        text_hl = text_color,
        border_hl = border_hl
    }
    return setmetatable(obj, self)
end

function scout_search_mode:update_banner_config(border, display_col, search_bar_window)
    self.banner_config["border"] = border
    self.banner_config["col"] = display_col
    self.banner_config["win"] = search_bar_window
    self.display_col = display_col
    return self.banner_config
end

function scout_search_mode:get_banner_display_width()
    return  #self.name + consts.modes.padding_space
end

function scout_search_mode:get_extra_padding()
    local has_bg_color = vim.api.nvim_get_hl(self.namespace, {name = self.border_hl, link = false}).bg
    if has_bg_color then
        return consts.modes.padding_space + 1
    else
        return consts.modes.padding_space
    end
end

return scout_search_mode
