local consts = require("nvim-scout.lib.consts")
scout_searchbar_manager = {}
scout_searchbar_manager.__index = scout_searchbar_manager

function scout_searchbar_manager:new(id, window_manager, config, extmark_id, theme)
    local obj = {
        id = id,
        window_manager = window_manager,
        virt_text_extid = extmark_id,
        width_percentage = config.size,
        theme = theme
    }

    return setmetatable(obj, self)
end

function scout_searchbar_manager:open_searchbar(should_focus, namespace)
    local config = self:get_searchbar_config()
    if config then
        config.focus_window = should_focus
    end
    self.window_manager:update_window_config(self.id, config)
    self.window_manager:open_window_by_name(self.id, namespace)
end

function scout_searchbar_manager:close_searchbar()
    self.window_manager:close_window_by_name(self.id)
end

function scout_searchbar_manager:calculate_config_width(host)
    if vim.api.nvim_win_is_valid(host) then
        return math.floor(vim.api.nvim_win_get_width(host) * self.width_percentage)
    end
end

function scout_searchbar_manager:calculate_config_col(host_window, resize_width)
    local host_win_start_col = vim.api.nvim_win_get_position(host_window)[2]
    local host_win_width = vim.api.nvim_win_get_width(host_window)

    return host_win_start_col + host_win_width - resize_width - 1
end

function scout_searchbar_manager:resize_searchbar()
    local window = self:get_searchbar()
    if window and window.open and window.host then
        vim.schedule(function ()
            if vim.api.nvim_win_is_valid(window.host) then
            local config = self:get_searchbar_config()
            self.window_manager:update_window_config(self.id, config)
         end
        end)
    end
end

function scout_searchbar_manager:toggle_window_focus()
    self.window_manager:toggle_window_focus(self.id)
end

function scout_searchbar_manager:clear_searchbar()
    self:set_searchbar_contents(Scout_Consts.buffer.EMPTY_BUFFER)
end

function scout_searchbar_manager:get_searchbar()
    return self.window_manager:get_managed_window(self.id)
end

function scout_searchbar_manager:is_searchbar_open()
    local searchbar = self:get_searchbar()
    return searchbar and searchbar.open
end

function scout_searchbar_manager:get_searchbar_contents()
    return self.window_manager:get_window_buf_line(self.id, 1)
end

function scout_searchbar_manager:set_searchbar_contents(contents)
    self.window_manager:set_window_buf_contents(self.id, contents)
end

function scout_searchbar_manager:reset_match_text(match_text)
    self.window_manager:clear_window_extmark_by_id(self.id, self.virt_text_extid)
    self.window_manager:set_window_extmarks(self.id, 0, -1, {
        virt_text = { {match_text, Scout_Consts.search.virt_text_hl} },
        virt_text_pos = "right_align",}, self.virt_text_extid)
end

function scout_searchbar_manager:get_searchbar_config()
    local window = self:get_searchbar()
    local host, col, width = nil, 0, 0
    if window and window.open and window.host then
        host = window.host
    else
        host = vim.api.nvim_get_current_win()
    end

    width = self:calculate_config_width(host)
    if width then
        col = self:calculate_config_col(host, width)
    end

    if col then
        return {
            focus_window = true,
            buffer = {
                list_buf = true,
                scratch_buf = true,
                name = Scout_Consts.search.search_name,
            },
            nvim_open_win_config = {
                relative='editor',
                row=0, -- todo make me dynamic
                col=col,
                width = width,
                zindex=1,
                focusable=false,
                height=1,
                style="minimal",
                border=self.theme:get_window_border("searchbar"),
                title_pos="center",
                title=self.theme:get_searchbar_title()
            }
        }
    end
end

return scout_searchbar_manager
