scout_mode_manager = {}
local consts = require("nvim-scout.lib.consts")

scout_mode_manager.__index = scout_mode_manager
function scout_mode_manager:new(modes)
    local obj = {
        modes = modes,
        next_banner_col = 0
    }

    return setmetatable(obj, self)
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
    if not self:validate_mode(mode_index) then
        Scout_Logger:error_print("Cannot toggle mode")
        return
    end
    local target_mode_status = self.modes[mode_index] -- validated so should be ok to just use here
    if target_mode_status.active then
        if target_mode_status:hide_banner() then
            local potential_col = target_mode_status.display_col
            target_mode_status.display_col = 0
            if potential_col < self.next_banner_col then
                self.next_banner_col = potential_col
            end
        end
    else
        if target_mode_status:show_banner(self.next_banner_col) then
            self.next_banner_col = self.next_banner_col + target_mode_status:get_banner_display_width() + consts.modes.banner_gap
        end
    end
    target_mode_status.active = not target_mode_status.active
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
                mode:hide_banner()
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
