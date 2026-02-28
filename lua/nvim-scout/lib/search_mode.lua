scout_search_mode = {}
local consts = require("nvim-scout.lib.consts")

scout_search_mode.__index = scout_search_mode
function scout_search_mode:new(mode_name, mode_symbol, ns, mode_hl)

    local obj = {
        name = mode_name,
        symbol = mode_symbol,
        banner_window_id = consts.window.INVALID_WINDOW_ID,
        banner_buf = consts.buffer.INVALID_BUFFER,
        search_bar_win = consts.window.INVALID_WINDOW_ID,
        display_col = 0,
        active = false,
        namespace = ns,
        hl_name = mode_hl,
    }
    return setmetatable(obj, self)
end

function scout_search_mode:show_banner(display_col)

    if self.banner_window_id == consts.window.INVALID_WINDOW_ID and self.search_bar_win ~= consts.window.INVALID_WINDOW_ID then
        local banner_border = Scout_Theme:get_window_border(self.name)
        self.border_hl = banner_border[1][2]
        local banner_config = {
            relative='win',
            row=2,
            col=display_col,
            zindex=1,
            width=#self.name + consts.modes.padding_space,
            height=1,
            border = banner_border,
            focusable=false,
            footer={{"mod", consts.colorscheme_groups.m_virt_text_c}},
            style="minimal",
            win=self.search_bar_win,
        }
        self.display_col = display_col

        self.banner_buf = vim.api.nvim_create_buf(false, true)
        self.banner_window_id = vim.api.nvim_open_win(self.banner_buf, false, banner_config)
        vim.api.nvim_win_set_hl_ns(self.banner_window_id, self.namespace)
        vim.api.nvim_buf_set_lines(self.banner_buf, 0, 1, true, {" " .. self.name .." "})
        vim.api.nvim_buf_set_extmark(self.banner_buf, self.namespace, 0, 1, { end_col = #self.name + consts.modes.padding_space - 1, hl_group = self.hl_name})
        return true
    else
        return false
    end
end

function scout_search_mode:get_banner_display_width()
    return  #self.name + consts.modes.padding_space
end

function scout_search_mode:get_extra_padding()
    local has_bg_color = vim.api.nvim_get_hl(self.namespace, {name = self.border_hl}).bg
    if has_bg_color then
        return consts.modes.padding_space + 1
    else
        return consts.modes.padding_space
    end
end

function scout_search_mode:hide_banner()
    if self.banner_window_id ~= consts.window.INVALID_WINDOW_ID then
        local close_id = self.banner_window_id
        vim.api.nvim_win_close(close_id, false)
        vim.api.nvim_buf_delete(self.banner_buf, {force = true})
        self.banner_window_id = consts.window.INVALID_WINDOW_ID
        self.banner_buf = consts.buffer.INVALID_BUFFER
        return true
    else
        return false
    end
end

return scout_search_mode
