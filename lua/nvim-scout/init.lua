_G.Scout_Consts = require("nvim-scout.utils.consts")
local searchbar_manager = require("nvim-scout.managers.searchbar_manager")
local config_parser = require("nvim-scout.config.config_parser")
local theme_parser = require("nvim-scout.themes.theme_parser")
local window_manager = require("nvim-scout.managers.window_manager")
local mode_mgr = require("nvim-scout.managers.mode_manager")
local keymaps_mgr = require("nvim-scout.events.keymaps")
local history = require("nvim-scout.managers.history_manager")
local highlighter = require("nvim-scout.search.highlighter")
local events = require("nvim-scout.events.events")
local search_mode = require("nvim-scout.search.search_mode")
local SCOUT = {}

function SCOUT.setup(user_options)
    local scout_config = config_parser:new(user_options):parse_config()
    SCOUT.namespace = vim.api.nvim_create_namespace(Scout_Consts.highlight.SCOUT_NAMESPACE)
    SCOUT.autocmd_group = vim.api.nvim_create_augroup('SCOUT', {})
    SCOUT.register_global_components(scout_config.logging)
    SCOUT.init(scout_config)
    SCOUT.register_components(scout_config)
    SCOUT.register_autocmds()
end

function SCOUT.init(scout_config)
    SCOUT.searchbar_id = Scout_Consts.search.search_name
    SCOUT.searchbar_ext_id = "search_ext_mark"
    SCOUT.window_manager = window_manager:new()
    SCOUT.theme = theme_parser:new(scout_config.theme)
    SCOUT.search_events = events:new(Scout_Consts.buffer.VALID_LUA_EVENTS)
    SCOUT.mode_mgr = mode_mgr:new(SCOUT.namespace, SCOUT.window_manager, SCOUT.theme, SCOUT.searchbar_id, search_mode)
    SCOUT.searchbar_manager = searchbar_manager:new(SCOUT.searchbar_id, SCOUT.window_manager, scout_config.search, SCOUT.searchbar_ext_id, SCOUT.theme)
    SCOUT.search_modes = {}
    SCOUT.highlighter = highlighter:new(SCOUT.namespace, SCOUT.mode_mgr)
    SCOUT.history = history:new(Scout_Consts.history.MAX_ENTRIES)
end

function SCOUT.register_components(scout_config)
    SCOUT.window_manager:register_window(SCOUT.searchbar_id, SCOUT.searchbar_config)
    SCOUT.register_keymaps(scout_config.keymaps)
    SCOUT.set_keymaps(SCOUT.keymap_table.global)
    SCOUT.register_search_modes()
end

function SCOUT.register_global_components(logging_config)
    _G.Scout_Logger = require("nvim-scout.utils.scout_logger"):new(logging_config, vim.print, vim.notify)
    _G.Scout_Colorscheme = require("nvim-scout.themes.colorscheme"):init(SCOUT.namespace)
    Scout_Colorscheme.schemes = {}
end

function SCOUT.on_lines_handler(...)
    SCOUT.run_search()
end

function SCOUT.run_search()
    local search = SCOUT.searchbar_manager:get_searchbar_contents()
    if search then
        vim.schedule(function()
            SCOUT.highlighter:clear_highlights()
            -- anytime we search update in case the file changed... this needs to be optimized for better performance?
            SCOUT.update_search_context()
            Scout_Logger:debug_print("Searching buffer for pattern ", search)
            SCOUT.highlighter:highlight_file_by_pattern(search)
            SCOUT.update_match_text()

        end)
    end
end

function SCOUT.register_search_modes()
    SCOUT.search_modes[Scout_Consts.modes.case_sensitive] = {
        name = "Match Case",
        symbol = "C",
        text_color = Scout_Consts.colorscheme_groups.m_case_title_c,
        border_hl = Scout_Consts.colorscheme_groups.m_case_border_c
    }

    SCOUT.search_modes[Scout_Consts.modes.lua_pattern] = {
        name= "Lua Pattern",
        symbol = "P",
        text_color = Scout_Consts.colorscheme_groups.m_pat_title_c,
        border_hl = Scout_Consts.colorscheme_groups.m_pat_title_c
    }

    for _, mode in pairs(SCOUT.search_modes) do
        SCOUT.mode_mgr:register_search_mode(mode)
    end
end

function SCOUT.update_search_context()
    local searchbar = SCOUT.searchbar_manager:get_searchbar()
    if not searchbar.open or not searchbar.host or not searchbar.buffer then
        return
    end
    local host_buffer = vim.api.nvim_win_get_buf(searchbar.host)
    if host_buffer and vim.api.nvim_buf_is_valid(host_buffer) then
        if SCOUT.highlighter then
            SCOUT.host_window = searchbar.host
            SCOUT.query_buffer = searchbar.buffer
            SCOUT.highlighter:update_hl_context(host_buffer, searchbar.buffer, searchbar.host)
        end
    end
end

function SCOUT.open_search(enter_insert, focus)
    if enter_insert == nil then
        enter_insert = true
    end
    if focus == nil then
        focus = true
    end
    SCOUT.searchbar_manager:open_searchbar(focus, SCOUT.namespace)
    SCOUT.search_events:add_event("on_lines", SCOUT, "on_lines_handler") -- add the on_lines_handler to search bar's
    SCOUT.update_search_context()
    if SCOUT.query_buffer then
        SCOUT.search_events:attach_buffer_events(SCOUT.query_buffer)
    end

    if enter_insert then
        vim.cmd('startinsert') -- allow for typing right away
    else
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-c>', true, false, true), 'n', true)
        --vim.cmd('normal! <Esc>') -- hack to go back to normal mode
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
            pattern_toggle = {mode = "n", key = keymap_config.pattern_toggle, handler = SCOUT.toggle_pattern_mode},
            block_enter = {mode = "i", key = "<CR>", handler = function () end}
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
    SCOUT.searchbar_manager:close_searchbar()
    SCOUT.mode_mgr:close_all_modes()
end

-- keymap handlers ---
function SCOUT.toggle()
    if not SCOUT.searchbar_manager:is_searchbar_open() then
        SCOUT.open_search(true, true)
    else
        SCOUT.close_search()
    end
end

function SCOUT.toggle_scout_focus()
    SCOUT.searchbar_manager:toggle_window_focus()
end

function SCOUT.clear_searchbar()
    SCOUT.searchbar_manager:clear_searchbar()
end

function SCOUT.next_match()
    local query = SCOUT.searchbar_manager:get_searchbar_contents() -- get first line from search buffer
    if query and #query > 0 then
        SCOUT.history:add_entry(query) -- add the entry
    end
    local next_index = SCOUT.highlighter:get_closest_match(Scout_Consts.search.FORWARD)
    SCOUT.move_selected_match(next_index)
end

function SCOUT.next_history_entry()
    local entry = SCOUT.history:get_next_entry()
    SCOUT.searchbar_manager:set_searchbar_contents(entry)
end

function SCOUT.previous_history_entry()
    local entry = SCOUT.history:get_previous_entry()
    SCOUT.searchbar_manager:set_searchbar_contents(entry)
end

function SCOUT.previous_match()
    local query = SCOUT.searchbar_manager:get_searchbar_contents() -- get first line from search buffer
    if query and #query > 0 then
        SCOUT.history:add_entry(query) -- add the entry
    end
    local next_index = SCOUT.highlighter:get_closest_match(Scout_Consts.search.BACKWARD)
    SCOUT.move_selected_match(next_index)
end

function SCOUT.update_match_text()
    local match_virt_text = SCOUT.highlighter:get_current_match_text()
    local contents = SCOUT.searchbar_manager:get_searchbar_contents()
    if not match_virt_text or contents == "" then
        match_virt_text = ""
    end

    SCOUT.searchbar_manager:reset_match_text(match_virt_text)
end

function SCOUT.move_selected_match(index)
    if SCOUT.highlighter.matches ~= nil and #SCOUT.highlighter.matches > 0 then
        SCOUT.highlighter:move_cursor(index, SCOUT.host_window)
        SCOUT.update_match_text()
    else
        Scout_Logger:debug_print("Matches is either undefined or empty ignoring enter")
    end
end

function SCOUT.toggle_case_mode()
    SCOUT.mode_mgr:toggle_mode(Scout_Consts.modes.case_sensitive)
    SCOUT.run_search()
end

function SCOUT.toggle_pattern_mode()
    SCOUT.mode_mgr:toggle_mode(Scout_Consts.modes.lua_pattern)
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
    if not SCOUT.searchbar_manager:is_searchbar_open() then
        SCOUT.open_search(false, false)
    end
    SCOUT.searchbar_manager:set_searchbar_contents(selection)
    local searchbar = SCOUT.searchbar_manager:get_searchbar()
    if searchbar then
        vim.api.nvim_set_current_win(searchbar.id)
    end
end

--- AU GROUP EVENTS ---
-------------------------------------------------------------
--- search_bar.move_window: handles moving the search window
--- so it stays attached to the current buffer it's searching
--- (i.e a neotree window opens and shrinks current buffer win)
--- @new_col: the new column where the new window has opened
--- this is used to calculate where to start the search bar window
---
function SCOUT.handle_resize()
    SCOUT.searchbar_manager:resize_searchbar()
end

function SCOUT.update_scout_context(ev)
    local enterBuf = ev.buf
    if vim.api.nvim_buf_is_valid(enterBuf) then
        if enterBuf ~= SCOUT.query_buffer then
            SCOUT.update_search_context()
        else
            SCOUT.run_search()
        end
    end
end

function SCOUT.force_search_window(ev)
    local searchbar = SCOUT.searchbar_manager:get_searchbar()
    if searchbar and searchbar.id and vim.api.nvim_get_current_win() == searchbar.id then
        if SCOUT.query_buffer and ev.buf ~= SCOUT.query_buffer then
            vim.api.nvim_win_set_buf(searchbar.id, SCOUT.query_buffer) -- FIX ME: we need to close the buffer that was attempted to be opened?
            vim.api.nvim_win_set_buf(searchbar.host, ev.buf)
        end
    end
end

function SCOUT.scout_graceful_close(ev)
    local targetWin = ev.file
    if targetWin:find(Scout_Consts.search.search_name, 1, true) then
        vim.schedule(function ()
            SCOUT.close_search()
        end)
    end
end

function SCOUT.register_autocmds()
    vim.api.nvim_create_autocmd({Scout_Consts.events.WINDOW_RESIZED}, {
        group = SCOUT.autocmd_group,
        callback = SCOUT.handle_resize
    })

    vim.api.nvim_create_autocmd({Scout_Consts.events.WINDOW_LEAVE_EVENT}, {
        group = SCOUT.autocmd_group,
        callback = function(ev)
            if ev.buf == SCOUT.query_buffer then
                SCOUT.highlighter:clear_highlights()
            end
            SCOUT.was_last_focused = ev.buf == SCOUT.query_buffer
        end,
    })

    vim.api.nvim_create_autocmd({Scout_Consts.events.BUFFER_ENTER}, {
        group = SCOUT.autocmd_group,
        callback = SCOUT.update_scout_context
    })
    --
    vim.api.nvim_create_autocmd({Scout_Consts.events.BUFFER_ENTER}, {
        group = SCOUT.autocmd_group,
        callback = SCOUT.force_search_window
    })

    vim.api.nvim_create_autocmd({Scout_Consts.events.QUIT_PRE_HOOK}, {
        group = SCOUT.autocmd_group,
        callback = SCOUT.scout_graceful_close
    })

    vim.api.nvim_create_autocmd({Scout_Consts.events.WINDOW_ENTER_EVENT, Scout_Consts.events.TAB_ENTER_EVENT}, {
        group = SCOUT.autocmd_group,
        callback = function(ev)
            vim.schedule(function()
                local new_window = vim.api.nvim_get_current_win()
                local config = vim.api.nvim_win_get_config(new_window)
                local buffer_type = vim.api.nvim_get_option_value("buftype", {buf = vim.api.nvim_get_current_buf()})

                if not SCOUT.searchbar_manager:is_searchbar_open() or config.relative ~= "" then
                    return
                end

                if buffer_type == "nofile" and ev.event == "WinEnter" then
                    return
                end

                local window = SCOUT.searchbar_manager:get_searchbar()
                if new_window ~= window.id and new_window ~= window.host then
                    local contents = SCOUT.searchbar_manager:get_searchbar_contents()
                    SCOUT.close_search()
                    SCOUT.open_search(false, SCOUT.was_last_focused) -- do not enter insert mode and DO focus the window
                    SCOUT.searchbar_manager:set_searchbar_contents(contents)
                end
            end)
        end
    })
end
return SCOUT
