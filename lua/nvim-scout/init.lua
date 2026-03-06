local search_bar = require("nvim-scout.lib.search_bar")
local consts = require("nvim-scout.lib.consts")
local config_parser = require("nvim-scout.lib.config_parser")
local theme_parser = require("nvim-scout.lib.theme_parser")
local window_manager = require("nvim-scout.lib.window_manager")
local mode_mgr = require("nvim-scout.lib.mode_manager")
local keymaps_mgr = require("nvim-scout.lib.keymaps")
local history = require("nvim-scout.lib.history_manager")
local highlighter = require("nvim-scout.lib.highlighter")
local events = require("nvim-scout.lib.events")
local SCOUT = {}

function SCOUT.setup(user_options)
    SCOUT.namespace = vim.api.nvim_create_namespace(consts.highlight.SCOUT_NAMESPACE)
    local scout_config = config_parser:new(user_options):parse_config()
    SCOUT.register_global_components(scout_config.logging, scout_config.theme)
    SCOUT.init(scout_config)
    SCOUT.register_components(scout_config)
end

function SCOUT.init(scout_config)
    SCOUT.searchbar_id = consts.search.search_name
    SCOUT.search_bar = search_bar:new(window_manager, scout_config, SCOUT.namespace)
    SCOUT.window_manager = window_manager:new()
    SCOUT.search_events = events:new(consts.buffer.VALID_LUA_EVENTS)
    SCOUT.mode_mgr = mode_mgr:new(SCOUT.namespace, SCOUT.window_manager, Scout_Theme, SCOUT.searchbar_id)
    SCOUT.search_modes = {}
    SCOUT.highlighter = highlighter:new(SCOUT.namespace, SCOUT.mode_mgr)
    SCOUT.history = history:new(consts.history.MAX_ENTRIES)
end

function SCOUT.register_components(scout_config)
    SCOUT.window_manager:register_window(SCOUT.searchbar_id, SCOUT.search_bar:get_search_config())
    SCOUT.register_keymaps(scout_config.keymaps)
    SCOUT.set_keymaps(SCOUT.keymap_table.global)
    SCOUT.register_search_modes()
end

function SCOUT.register_global_components(logging_config, theme_config)
    _G.Scout_Logger = require("nvim-scout.lib.scout_logger"):new(logging_config, vim.print, vim.notify)
    _G.Scout_Colorscheme = require("nvim-scout.themes.colorscheme"):init(SCOUT.namespace)
    Scout_Colorscheme.schemes = {}
    _G.Scout_Theme = theme_parser:new(theme_config)
end

function SCOUT.on_lines_handler(...)
    SCOUT.run_search()
end

function SCOUT.run_search()
    local search = SCOUT.window_manager:get_window_buf_line(SCOUT.searchbar_id, 1) -- get first line from search buffer
    if search then
        vim.schedule(function()
            SCOUT.highlighter:clear_highlights()
            -- anytime we search update in case the file changed... this needs to be optimized for better performance?
            SCOUT.update_search_context(SCOUT.searchbar_id)
            Scout_Logger:debug_print("Searching buffer for pattern ", search)
            SCOUT.highlighter:highlight_file_by_pattern(search)
        end)
    end
end

function SCOUT.register_search_modes()
    SCOUT.search_modes[consts.modes.case_sensitive] = {name = "Match Case", symbol = "C", text_color = consts.colorscheme_groups.m_case_title_c}
    SCOUT.search_modes[consts.modes.lua_pattern] = {name= "Lua Pattern", symbol = "P", text_color = consts.colorscheme_groups.m_pat_title_c}

    for _, mode in pairs(SCOUT.search_modes) do
        SCOUT.mode_mgr:register_search_mode(mode)
    end
end

function SCOUT.update_search_context(searchbar_id)
    local search_buffer = SCOUT.window_manager:get_window_buffer(searchbar_id)
    local host_window = SCOUT.window_manager:get_window_host(searchbar_id)
    local host_buffer = vim.api.nvim_win_get_buf(host_window)
    if search_buffer and host_window and host_buffer and vim.api.nvim_buf_is_valid(host_buffer) then
        if SCOUT.highlighter then
            SCOUT.host_window = host_window
            SCOUT.query_buffer = search_buffer
            SCOUT.highlighter:update_hl_context(host_buffer, search_buffer, host_window)
        end
    end
end

function SCOUT.open_search()
    SCOUT.window_manager:open_window_by_name(SCOUT.searchbar_id, SCOUT.namespace)
    SCOUT.search_events:add_event("on_lines", SCOUT, "on_lines_handler") -- add the on_lines_handler to search bar's
    SCOUT.update_search_context(SCOUT.searchbar_id)
    if SCOUT.query_buffer then
        SCOUT.search_events:attach_buffer_events(SCOUT.query_buffer)
    end
    SCOUT.set_search_keymaps(SCOUT.keymap_table.search_bar, SCOUT.query_buffer)
end

function SCOUT.register_keymaps(keymap_config)
    SCOUT.keymap_mgr = keymaps_mgr:new()
    SCOUT.keymap_table = {
        global = {
            toggle_search = {mode = "n", key = keymap_config.toggle_search, handler = SCOUT.toggle, options = {}},
            toggle_focus = {mode = "n", key = keymap_config.toggle_focus, handler = SCOUT.toggle_scout_focus, options = {}},
            search_curr_word = {mode = "n", key = keymap_config.search_curr_word, handler = SCOUT.search_cursor_word, options = {}},
            search_curr_selection = {mode = "v", key = keymap_config.search_curr_word, handler = SCOUT.search_current_selection, options = {}}
        },
        search_bar = {
             clear_search = {mode = "n", key = keymap_config.clear_search, handler = SCOUT.clear_searchbar},
             prev_result = {mode = "n", key = keymap_config.prev_result, handler = SCOUT.previous_match},
             next_result = {mode = "n", key = keymap_config.next_result, handler = SCOUT.next_match},
             prev_history = {mode = "n", key = keymap_config.prev_history, handler = SCOUT.previous_history_entry},
             next_history = {mode = "n", key = keymap_config.next_history, handler = SCOUT.next_history_entry},
             case_sensitive_toggle = {mode = "n", key = keymap_config.case_sensitive_toggle, handler = SCOUT.toggle_case_mode},
             pattern_toggle = {mode = "n", key = keymap_config.pattern_toggle, handler = SCOUT.toggle_pattern_mode}
        },
    }

    for _, keymap_group in pairs(SCOUT.keymap_table) do
        for id, keymap in pairs(keymap_group) do
            SCOUT.keymap_mgr:register_keymap(id, keymap)
        end
    end
end

function SCOUT.set_search_keymaps(keymaps, buffer)
    for id, _ in pairs(keymaps) do
        SCOUT.keymap_mgr:set_keymap(id, buffer)
    end
end

function SCOUT.set_keymaps(keymaps)
    for id, _ in pairs(keymaps) do
        SCOUT.keymap_mgr:set_keymap(id)
    end
end

function SCOUT.del_keymaps(keymaps)
    for id, _ in pairs(keymaps) do
        SCOUT.keymap_mgr:del_keymap(id)
    end
end

function SCOUT.close_search()
    SCOUT.del_keymaps(SCOUT.keymap_table.search_bar)
    SCOUT.highlighter:clear_highlights()
    SCOUT.window_manager:close_window_by_name(SCOUT.searchbar_id)
    SCOUT.mode_mgr:close_all_modes()
end

-- keymap handlers ---
function SCOUT.toggle()
    if not SCOUT.window_manager:is_window_open(SCOUT.searchbar_id) then
        SCOUT.open_search()
    else
        SCOUT.close_search()
    end
end

function SCOUT.toggle_scout_focus()
    SCOUT.window_manager:toggle_window_focus(SCOUT.searchbar_id)
end

function SCOUT.clear_searchbar()
    SCOUT.window_manager:set_window_buf_contents(SCOUT.searchbar_id, consts.buffer.EMPTY_BUFFER)
end

-------------------------------------------------------------
--- search_bar.next_match KEYMAP: used to move forward in the
--- match list
---
function SCOUT.next_match()
    local query = SCOUT.window_manager:get_window_buf_line(SCOUT.searchbar_id, 1) -- get first line from search buffer
    if query and #query > 0 then
        SCOUT.history:add_entry(query) -- add the entry
    end
    local next_index = SCOUT.highlighter:get_closest_match(consts.search.FORWARD)
    SCOUT.move_selected_match(next_index)
end

function SCOUT.next_history_entry()
    local entry = SCOUT.history:get_next_entry()
    SCOUT.window_manager:set_window_buf_contents(SCOUT.searchbar_id, {entry})
end

function SCOUT.previous_history_entry()
    local entry = SCOUT.history:get_previous_entry()
    SCOUT.window_manager:set_window_buf_contents(SCOUT.searchbar_id, {entry})
end

-------------------------------------------------------------
--- search_bar.previous_match KEYMAP: used to move backward in
--- the match list
---
function SCOUT.previous_match()
    local query = SCOUT.window_manager:get_window_buf_line(SCOUT.searchbar_id, 1) -- get first line from search buffer
    if query and #query > 0 then
        SCOUT.history:add_entry(query) -- add the entry
    end
    local next_index = SCOUT.highlighter:get_closest_match(consts.search.BACKWARD)
    SCOUT.move_selected_match(next_index)
end

-------------------------------------------------------------
--- search_bar.move_selected_match: moves the search result
--- in the desired direction taking care of highlighting and
--- cursor movement
--- @direction: which way to go when iterating ove the list
--- (FORWARD OR BACKWARD)
---
function SCOUT.move_selected_match(index)
    if SCOUT.highlighter.matches ~= nil and #SCOUT.highlighter.matches > 0 then
        SCOUT.highlighter:move_cursor(index, SCOUT.host_window)
        SCOUT.highlighter:clear_match_count(SCOUT.query_buffer)
        SCOUT.highlighter:update_match_count(SCOUT.query_buffer)
    else
        Scout_Logger:debug_print("Matches is either undefined or empty ignoring enter")
    end
end

function SCOUT.toggle_case_mode()
    SCOUT.mode_mgr:toggle_mode(consts.modes.case_sensitive)
    SCOUT.run_search()
end

function SCOUT.toggle_pattern_mode()
    SCOUT.mode_mgr:toggle_mode(consts.modes.lua_pattern)
    SCOUT.run_search()
end

function SCOUT.search_current_selection()
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
        SCOUT.search_selection(selection)
    end
end

function SCOUT.search_cursor_word()
    local selection = vim.fn.expand("<cword>") -- in the future maybe we can check for the keypress and grab more then one word?
    SCOUT.search_selection(selection)
end

function SCOUT.search_selection(selection)
     if not SCOUT.window_manager:is_window_open() then
        SCOUT.open_search()
     end
    SCOUT.window_manager:set_window_buf_contents(SCOUT.searchbar_id, {selection})
    local searchbar = SCOUT.window_manager:get_managed_window(SCOUT.searchbar_id)
    if searchbar then
        vim.api.nvim_set_current_win(searchbar.id)
    end
end

--- AU GROUP EVENTS ---
function SCOUT.move_scout_search_bar()
    if vim.api.nvim_win_is_valid(SCOUT.search_bar.host_window) then
        vim.api.nvim_win_call(SCOUT.search_bar.host_window, function()
            SCOUT.search_bar:move_window()
        end)
    end
end

function SCOUT.update_scout_context(ev)
    local enterBuf = ev.buf
    if vim.api.nvim_buf_is_valid(enterBuf) then
        if enterBuf ~= SCOUT.search_bar.query_buffer then
            SCOUT.search_bar.highlighter:update_hl_context(ev.buf, SCOUT.search_bar.query_buffer, SCOUT.search_bar.host_window)
        else
            local file_buf = vim.api.nvim_win_get_buf(SCOUT.search_bar.host_window)
            SCOUT.search_bar.highlighter:update_hl_context(file_buf, SCOUT.search_bar.query_buffer, SCOUT.search_bar.host_window)
            SCOUT.search_bar:run_search() -- search again
        end
    end
end

function SCOUT.force_search_window(ev)
    if vim.api.nvim_get_current_win() == SCOUT.search_bar.win_id then
        if SCOUT.search_bar.query_buffer and SCOUT.search_bar.query_buffer ~= consts.buffer.INVALID_BUFFER and ev.buf ~= SCOUT.search_bar.query_buffer then
            vim.api.nvim_win_set_buf(SCOUT.search_bar.win_id, SCOUT.search_bar.query_buffer) -- FIX ME: we need to close the buffer that was attempted to be opened?
            vim.api.nvim_win_set_buf(SCOUT.search_bar.host_window, ev.buf)
        end
    end
end

function SCOUT.scout_graceful_close(ev)
    local targetWin = ev.file
    if targetWin:find(consts.search.search_name, 1, true) then
        SCOUT.search_bar.highlighter:clear_highlights(SCOUT.search_bar.highlighter.hl_buf)
        SCOUT.search_bar:close()
    end
end

function SCOUT.main(keymap_conf)
    -- vim.api.nvim_create_autocmd({consts.events.WINDOW_RESIZED}, {
    --     callback = SCOUT.move_scout_search_bar
    -- })
    -- vim.api.nvim_create_autocmd({consts.events.WINDOW_LEAVE_EVENT}, {
    --     callback = function(ev)
    --         if ev.buf == SCOUT.search_bar.query_buffer then
    --             SCOUT.search_bar.highlighter:clear_highlights(SCOUT.search_bar.highlighter.hl_buf)
    --         end
    --         SCOUT.search_bar.was_last_focused = ev.buf == SCOUT.search_bar.query_buffer
    --     end
    -- })
    -- vim.api.nvim_create_autocmd({consts.events.BUFFER_ENTER}, {
    --     callback = SCOUT.update_scout_context
    -- })
    --
    -- vim.api.nvim_create_autocmd({consts.events.BUFFER_ENTER}, {
    --     callback = SCOUT.force_search_window
    -- })
    --
    -- vim.api.nvim_create_autocmd({consts.events.QUIT_PRE_HOOK}, {
    --     callback = SCOUT.scout_graceful_close
    -- })
    --
    -- vim.api.nvim_create_autocmd({consts.events.WINDOW_ENTER_EVENT, consts.events.TAB_ENTER_EVENT}, {
    --     callback = function(ev)
    --         --vim.print("Object is " .. vim.inspect(ev) )
    --
    --     vim.schedule(function()
    --         local new_window = vim.api.nvim_get_current_win()
    --         local config = vim.api.nvim_win_get_config(new_window)
    --         local buffer_type = vim.api.nvim_get_option_value("buftype", {buf = vim.api.nvim_get_current_buf()})
    --
    --         if not SCOUT.search_bar:is_open() or config.relative ~= "" then
    --             return
    --         end
    --
    --         if buffer_type == "nofile" and ev.event == "WinEnter" then
    --             return
    --         end
    --
    --         if (new_window ~= SCOUT.search_bar.win_id and new_window ~= SCOUT.search_bar.host_window) then
    --             local contents = SCOUT.search_bar:get_window_contents()
    --             SCOUT.search_bar:close()
    --             if SCOUT.search_bar.was_last_focused then -- there's likely a better way to handle this...?
    --                 SCOUT.search_bar:open(false, true) -- do not enter insert mode or DO focus the window
    --             else
    --                 SCOUT.search_bar:open(false, false) -- do not enter insert mode and do not focus the window
    --             end
    --             SCOUT.search_bar:set_window_contents(contents)
    --             end
    --         end)
    --     end
    -- })
end
return SCOUT
