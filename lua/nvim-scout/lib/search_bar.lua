local consts = require("nvim-scout.lib.consts")
local highlighter = require("nvim-scout.lib.highlighter")
local keymaps = require("nvim-scout.lib.keymaps")
local events = require("nvim-scout.lib.events")
local history = require("nvim-scout.lib.history_manager")
local mode_manager = require("nvim-scout.lib.mode_manager")
local search_mode = require("nvim-scout.lib.search_mode")

keymap_mgr = nil -- global varaible used to init the keymappings for the search bar
scout_search_bar = {}
scout_search_bar.__index = scout_search_bar

scout_search_bar.VALID_WINDOW_EVENTS = {"on_lines", "on_bytes", "on_changedtick", "on_detach", "on_reload"}
scout_search_bar.MIN_WIDTH = 0.10
scout_search_bar.MAX_WIDTH = 1

function scout_search_bar:new(window_config, scout_config)
    local current_editing_win = vim.api.nvim_get_current_win()
    local namespace = vim.api.nvim_create_namespace(consts.highlight.SCOUT_NAMESPACE)
    local mode_mgr = mode_manager:new(create_search_bar_modes(namespace))
    local obj = {
        query_buffer = consts.buffer.INVALID_BUFFER,
        query_win_config = window_config,
        width_percent = scout_config.search.size,
        should_enter = true,
        send_buffer = false, -- unused since we use lua cbs
        mode_manager = mode_mgr,
        highlighter = highlighter:new(current_editing_win, consts.highlight.MATCH_HIGHLIGHT, consts.highlight.CURR_MATCH_HIGHLIGHT, namespace, mode_mgr),
        search_events = nil,
        history = history:new(consts.history.MAX_ENTRIES),
        win_id = consts.window.INVALID_WINDOW_ID,
        host_window = consts.window.INVALID_WINDOW_ID,
    }
    t = setmetatable(obj, self)
    keymap_mgr = keymaps:new(t, scout_config.keymaps)
    return t
end

function create_search_bar_modes(namespace_id)
    local search_modes = {}
    search_modes[consts.modes.lua_pattern] = search_mode:new("Lua Pattern", "P", namespace_id, consts.modes.pattern_color)
    search_modes[consts.modes.case_sensitive] = search_mode:new("Match Case", "C", namespace_id, consts.modes.case_sensitive_color)
    return search_modes
end

-------------------------------------------------------------
--- search_bar.on_lines_handler: function that is called when
--- text is typed or deleted in the search buffer this handler
--- schedules the matching algo that then highlights text and
--- allows the user to go to and from search results
--- @...: varadic arguments not really used however since none
--- of the parameters are used at this time
function scout_search_bar:on_lines_handler(...)
  local event, bufnr, changedtick,
    first_line, last_line,
    new_lastline, bytecount = ...
    self:run_search()
end

function scout_search_bar:run_search()
    local search = self:get_window_contents() --grab the current contents of the window
    vim.schedule(function()
        self.highlighter:clear_highlights(self.highlighter.hl_buf, self.query_buffer)
        -- anytime we search update in case the file changed... this needs to be optimized for better performance?
        self.highlighter:update_hl_context(self.highlighter.hl_buf, self.query_buffer, self.host_window)
        self.highlighter.match_index = 1
        self.highlighter.matches = {}
        Scout_Logger:debug_print("Searching buffer for pattern ", search)
        self.highlighter:highlight_file_by_pattern(self.query_buffer, search)

    end)
end

-------------------------------------------------------------
--- search_bar.is_open: checks wether or not the scout search
--- bar is open based on the current window id
---
function scout_search_bar:is_open()
    return self.win_id ~= consts.window.INVALID_WINDOW_ID
end

-------------------------------------------------------------
--- search_bar.get_window_contents: gets the contents of the
--- search bar window (currently hardcoded to the first line)
---
function scout_search_bar:get_window_contents()
    if self.query_buffer ~= consts.buffer.INVALID_BUFFER then
        return vim.api.nvim_buf_get_lines(self.query_buffer, 0, 1, true)[1]
    end
end

-------------------------------------------------------------
--- search_bar.set_window_contents: set the contents of the
--- search bar window
---
function scout_search_bar:set_window_contents(contents)
    if self.query_buffer ~= consts.buffer.INVALID_BUFFER then
        vim.api.nvim_buf_set_lines(self.query_buffer, consts.lines.START, consts.lines.END,
                              true, {contents})
    end
end

-------------------------------------------------------------
--- search_bar.toggle: toggles the status of the window so
--- if it's closed open it and vice versa
---
function scout_search_bar:toggle()
    if self:is_open() then
        self:close()
    else
        self:open()
    end
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

function scout_search_bar:search_current_selection()
    local selection = ""
    local mode = vim.api.nvim_get_mode().mode
    if mode == "v" or mode == "V" then
        local v_start = vim.fn.getpos('v') -- get start of visual selection
        local v_end = vim.fn.getpos('.') -- current cursor position

        if v_start[2] > v_end[2] or (v_start[2] == v_end[2] and (v_start[3] > v_end[3]))then -- user selected backwards so invert
            local tmp = v_start
            v_start = v_end
            v_end = tmp
        end
        for _, str in ipairs(vim.api.nvim_buf_get_text(vim.api.nvim_win_get_buf(0), v_start[2] - 1, v_start[3] - 1, v_end[2] - 1, v_end[3], {})) do
            selection = selection .. str
        end
        self:search_selection(selection)
    end
end

function scout_search_bar:search_cursor_word()
    local selection = vim.fn.expand("<cword>") -- in the future maybe we can check for the keypress and grab more then one word?
    self:search_selection(selection)
end

function scout_search_bar:search_selection(selection)
    if not self:is_open() then
        self:open(false)
    end
    self:set_window_contents(selection)
    vim.api.nvim_set_current_win(self.win_id)
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
        self.search_events = events:new(consts.buffer.VALID_LUA_EVENTS) -- make new events table with buffer events
        self.search_events:add_event("on_lines", self, "on_lines_handler") -- add the on_lines_handler to search bar's
        self.search_events:attach_buffer_events(self.query_buffer)
        if enter_insert then
            vim.cmd('startinsert') -- allow for typing right away
        else
            vim.cmd('normal 0') -- hack to go back to normal mode
        end
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

-------------------------------------------------------------
--- search_bar.close: closes the search bar and unregisters
--- all of the associated keymaps also frees the buffers
--- associated with the searching
---
function scout_search_bar:close()
    if self:is_open() then
        local close_id = self.win_id
        self.win_id = consts.window.INVALID_WINDOW_ID
        self.host_window = consts.window.INVALID_WINDOW_ID
        Scout_Logger:debug_print("Closing open window")

        keymap_mgr:teardown_search_keymaps()
        keymap_mgr:teardown_history_keymaps()

        self.mode_manager:close_all_modes()
        if vim.api.nvim_win_is_valid(close_id) then
            vim.api.nvim_win_close(close_id, false) -- there is a chance if the parent window is closed neovim has already closed us
        end
        vim.api.nvim_buf_delete(self.query_buffer, {force = true}) -- buffer must be deleted after window otherwise window_close gives bad id
        self.query_buffer = consts.buffer.INVALID_BUFFER
    else
        Scout_Logger:debug_print("Attempted to close a but now window was open ignoring...")
    end
end

-------------------------------------------------------------
--- search_bar.previous_match KEYMAP: used to move backward in
--- the match list
---
function scout_search_bar:previous_match()
    self.history:add_entry(self:get_window_contents())
    local next_index = self.highlighter:get_closest_match(consts.search.BACKWARD)
    self:move_selected_match(next_index)
end

-------------------------------------------------------------
--- search_bar.next_match KEYMAP: used to move forward in the
--- match list
---
function scout_search_bar:next_match()
    self.history:add_entry(self:get_window_contents()) -- add the entry
    local next_index = self.highlighter:get_closest_match(consts.search.FORWARD)
    self:move_selected_match(next_index)
end

function scout_search_bar:next_history_entry()
    local entry = self.history:get_next_entry()
    self:set_window_contents(entry)
end

function scout_search_bar:previous_history_entry()
    local entry = self.history:get_previous_entry()
    self:set_window_contents(entry)
end

-------------------------------------------------------------
--- search_bar.move_selected_match: moves the search result
--- in the desired direction taking care of highlighting and
--- cursor movement
--- @direction: which way to go when iterating ove the list
--- (FORWARD OR BACKWARD)
---
function scout_search_bar:move_selected_match(index)
    if self.highlighter.matches ~= nil and #self.highlighter.matches > 0 then
        self.highlighter:move_cursor(index, self.host_window)
        self.highlighter:clear_match_count(self.query_buffer)
        self.highlighter:update_match_count(self.query_buffer)
    else
        Scout_Logger:debug_print("Matches is either undefined or empty ignoring enter")
    end
end

-------------------------------------------------------------
--- search_bar.clear_search KEYMAP: used to clear the contents
--- of the search bar buffer and window
---
function scout_search_bar:clear_search()
    vim.api.nvim_buf_set_lines(self.query_buffer, consts.lines.START, consts.lines.END,
                              true, consts.buffer.EMPTY_BUFFER)
end

return scout_search_bar
