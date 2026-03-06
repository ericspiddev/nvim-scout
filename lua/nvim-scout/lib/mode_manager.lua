scout_mode_manager = {}
local consts = require("nvim-scout.lib.consts")
local search_mode = require("nvim-scout.lib.search_mode")

scout_mode_manager.__index = scout_mode_manager
function scout_mode_manager:new(namespace, window_manager, theme, searchbar_name)
    local obj = {
        modes = {},
        namespace = namespace,
        search_id = searchbar_name,
        window_manager = window_manager,
        theme = theme,
        next_banner_col = 0
    }
    return setmetatable(obj, self)
end

function scout_mode_manager:register_search_mode(mode)
    local new_mode = search_mode:new(mode.name, mode.symbol, self.namespace, mode.text_color)
    self.window_manager:register_window(mode.name, {buffer = {list_buf = false, scratch_buf = false }})
    self.modes[mode.name]= new_mode
end

-- when each mode is active we should display a little window with a letter
-- toggling it to off should hide that window
function scout_mode_manager:validate_mode(mode_index)
    if self.modes[mode_index] == nil then
        Scout_Logger:error_print("Attempting to perform an operation on an unsupported mode")
        return false
    end
    return true
end

function scout_mode_manager:toggle_mode(mode_index)
    local search_window = self.window_manager:get_managed_window(self.search_id)
    if not self:validate_mode(mode_index) then
        Scout_Logger:error_print("Cannot toggle nonexistent mode")
        return
    end

    if not search_window then
        return
    end

    local target_mode = self.modes[mode_index]
    local banner_window_id = target_mode.name
    if target_mode.active then
        local potential_col = target_mode.display_col
        target_mode.display_col = 0
        if potential_col < self.next_banner_col then
            self.next_banner_col = potential_col
        end
        self.window_manager:close_window_by_name(target_mode.name, self.namespace)
    else
        local border = self.theme:get_window_border(banner_window_id)
        local banner_config = target_mode:update_banner_config(border, self.next_banner_col, search_window.id)
        self.window_manager:update_nvim_window_config(banner_window_id, banner_config)
        self.window_manager:open_window_by_name(target_mode.name, self.namespace)
        self.window_manager:set_window_buf_contents(target_mode.name, {" " ..target_mode.name .." "})
        self.next_banner_col = self.next_banner_col + target_mode:get_banner_display_width() + target_mode:get_extra_padding()
        --vim.api.nvim_buf_set_extmark(self.banner_buf, self.namespace, 0, 1, { end_col = #self.name + consts.modes.padding_space - 1, hl_group = self.hl_name}) -- FIX ME
    end
    target_mode.active = not target_mode.active
end

function scout_mode_manager:set_mode(mode, value)
    if not self:validate_mode(mode) then
        Scout_Logger:error_print("Cannot set mode")
        return
    end
    self.modes[mode].active = value
end

function scout_mode_manager:get_mode_status(mode)
    if not self:validate_mode(mode) then
        Scout_Logger:error_print("Cannot get mode's value")
        return
    end
    return self.modes[mode].active
end

function scout_mode_manager:update_relative_window(win_id)
    local new_window = nil
    if vim.api.nvim_win_is_valid(win_id) then
        new_window = win_id
    else
        new_window = consts.window.INVALID_WINDOW_ID
    end

    if self.modes ~= nil then
        for _, mode in pairs(self.modes) do
            mode.search_bar_win = new_window
        end
    end
end

function scout_mode_manager:close_all_modes()
    if self.modes ~= nil then
        for _, mode in pairs(self.modes) do
            if mode.active then
                self.window_manager:close_window_by_name(mode.name)
                mode.active = false
            end
        end
        self.next_banner_col = 0
    end
end

function scout_mode_manager:apply_modes_to_search_text(line, pattern)
    line, pattern = self:apply_match_case(line, pattern)
    return line, pattern
end

function scout_mode_manager:apply_match_case(line, pattern)
    if not self:get_mode_status(consts.modes.case_sensitive) and not self:get_mode_status(consts.modes.lua_pattern) then
        line = string.lower(line)
        pattern = string.lower(pattern)
    end
    return line, pattern
end

function scout_mode_manager:apply_lua_pattern_mode()
    -- when set to false pattern matching is used when set to true only exact matches are shown...
    return not self:get_mode_status(consts.modes.lua_pattern)
end
return scout_mode_manager
