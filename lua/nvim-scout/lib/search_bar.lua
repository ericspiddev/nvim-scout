local consts = require("nvim-scout.lib.consts")
local events = require("nvim-scout.lib.events")
local mode_manager = require("nvim-scout.lib.mode_manager")
local search_mode = require("nvim-scout.lib.search_mode")

keymap_mgr = nil -- global varaible used to init the keymappings for the search bar
scout_search_bar = {}
scout_search_bar.__index = scout_search_bar

scout_search_bar.MIN_WIDTH = 0.10
scout_search_bar.MAX_WIDTH = 1

function scout_search_bar:new(window_manager, scout_config, scout_namespace)
    local obj = {
        window_manager = window_manager,
        query_buffer = consts.buffer.INVALID_BUFFER,
        namespace = scout_namespace,
        width_percent = scout_config.search.size,
        should_enter = true,
        search_events = nil,
        win_id = consts.window.INVALID_WINDOW_ID,
        host_window = consts.window.INVALID_WINDOW_ID,
    }
    t = setmetatable(obj, self)
    --keymap_mgr = keymaps:new(t, scout_config.keymaps)
    return t
end

function scout_search_bar:get_search_config()
    local window = vim.api.nvim_get_current_win()
    local config = vim.api.nvim_win_get_config(window)
    if config.relative ~= "" then -- IGNORE floating windows
        return
    end
    self.host_window = window

    local width = self:get_search_bar_width(self.host_window, self.width_percent)
    return {
        focus_window = true,
        buffer = {
            list_buf = true,
            scratch_buf = true,
            name = consts.search.search_name,
        },
        nvim_open_win_config = {
            relative='editor',
            row=0,
            col=self:get_search_bar_col(self.host_window, width),
            width = width,
            zindex=1,
            focusable=true,
            height=1,
            style="minimal",
            border=Scout_Theme:get_window_border("searchbar"),
            title_pos="center",
            title=Scout_Theme:get_searchbar_title()
        }
    }
end

-------------------------------------------------------------
--- search_bar.move_window: handles moving the search window
--- so it stays attached to the current buffer it's searching
--- (i.e a neotree window opens and shrinks current buffer win)
--- @new_col: the new column where the new window has opened
--- this is used to calculate where to start the search bar window
---
function scout_search_bar:move_window()
    if self:is_open() then
        if vim.api.nvim_win_is_valid(self.host_window) then
            self.query_win_config.width = self:get_search_bar_width(self.host_window, self.width_percent)
            self.query_win_config.col = self:get_search_bar_col(self.host_window, self.query_win_config.width)
            vim.api.nvim_win_set_config(self.win_id, self.query_win_config)
        end
    end
end

function scout_search_bar:cap_width(width)
    if width > self.MAX_WIDTH then
        width = self.MAX_WIDTH
    elseif width < self.MIN_WIDTH then
        width = self.MIN_WIDTH
    end
    return width
end

-------------------------------------------------------------
--- search_bar.open: opens the search bar for searching this
--- function considers the width_percent that the bar should
--- take up and then calculates it's width based on that
---
function scout_search_bar:open(enter_insert, focus_search)
    if focus_search == nil then
        focus_search = true
    end
    if enter_insert == nil then
        enter_insert = true
    end
    if not self:is_open() then
        Scout_Logger:debug_print("Opening window")
        local window = vim.api.nvim_get_current_win()
        local config = vim.api.nvim_win_get_config(window)
        if config.relative ~= "" then -- IGNORE floating windows
            return
        end
        self.host_window = window
        self.width_percent = self:cap_width(self.width_percent)
        self.query_buffer = vim.api.nvim_create_buf(consts.buffer.LIST_BUFFER, consts.buffer.SCRATCH_BUFFER)
        self.query_win_config.width = self:get_search_bar_width(self.host_window, self.width_percent)
        self.query_win_config.col = self:get_search_bar_col(self.host_window, self.query_win_config.width)
        self.win_id = vim.api.nvim_open_win(self.query_buffer, focus_search, self.query_win_config)
        vim.api.nvim_buf_set_name(self.query_buffer, consts.search.search_name)

        self.mode_manager:update_relative_window(self.win_id)
        if self.highlighter.hl_context == consts.buffer.NO_CONTEXT then
            Scout_Logger:warning_print("No valid context found attempting to populate now")
            self.highlighter:update_hl_context(window, self.query_buffer, self.host_window)
        end
        if enter_insert then
            vim.cmd('startinsert') -- allow for typing right away
        else
            vim.cmd('normal 0') -- hack to go back to normal mode
        end
        vim.api.nvim_win_set_hl_ns(self.win_id, self.namespace)
        keymap_mgr:setup_scout_keymaps()
    else
        Scout_Logger:debug_print("Attempted to open an already open window ignoring...")
    end
end

function scout_search_bar:get_search_bar_col(hl_buf_window, search_bar_width)
    local hl_win_start_col = vim.api.nvim_win_get_position(hl_buf_window)[2]
    local hl_win_width = vim.api.nvim_win_get_width(hl_buf_window)

    return hl_win_start_col + hl_win_width - search_bar_width - 1
end

function scout_search_bar:get_search_bar_width(hl_buf_window, width_percent)
    if vim.api.nvim_win_is_valid(hl_buf_window) then
        return math.floor(vim.api.nvim_win_get_width(hl_buf_window) * width_percent)
    end
end

return scout_search_bar
