local search_bar = require("nvim-scout.lib.search_bar")
local consts = require("nvim-scout.lib.consts")
local config_parser = require("nvim-scout.lib.config_parser")
local M = {}

function M.setup(user_options)
    local scout_config = config_parser:new(user_options):parse_config() -- hmm think about how to use logger maybe print directly?
    _G.Scout_Logger = require("nvim-scout.lib.scout_logger"):new(scout_config.logging, vim.print, vim.notify)
    local search_bar_config = {
        relative='editor',
        row=0,
        zindex=1,
        focusable=true,
        height=1,
        style="minimal",
        border={ "╔", "═","╗", "║", "╝", "═", "╚", "║" }, -- double border for now fix me later
        title_pos="center",
        title="Search"
    }
    --Scout_Logger:debug_print("window: making a new window with config ", search_bar_config)


    M.search_bar = search_bar:new(search_bar_config, scout_config)
    M.search_bar.highlighter:populate_hl_context(consts.window.CURRENT_WINDOW)
    M.main(scout_config.keymaps)
end

-- need to clean these all up into the search bar and dedicated auto group file
function M.toggle()
    M.search_bar:toggle()
end

function M.toggle_scout_focus()
    local curr_buf = vim.api.nvim_get_current_buf()
    if not M.search_bar:is_open() then
        return
    end
    if curr_buf == M.search_bar.highlighter.hl_buf and vim.api.nvim_win_is_valid(M.search_bar.win_id) then
        vim.api.nvim_set_current_win(M.search_bar.win_id)
    elseif curr_buf == M.search_bar.query_buffer then
        vim.api.nvim_set_current_win(M.search_bar.host_window)
    end
end

function M.move_scout_search_bar()
    if vim.api.nvim_win_is_valid(M.search_bar.host_window) then
        vim.api.nvim_win_call(M.search_bar.host_window, function()
            M.search_bar:move_window()
        end)
    end
end

function M.update_scout_context(ev)
    local enterBuf = ev.buf
    if vim.api.nvim_buf_is_valid(enterBuf) then
        if enterBuf ~= M.search_bar.query_buffer then
            M.search_bar.highlighter:update_hl_context(ev.buf, M.search_bar.query_buffer)
        else
            local file_buf = vim.api.nvim_win_get_buf(M.search_bar.host_window)
            M.search_bar.highlighter:update_hl_context(file_buf, M.search_bar.query_buffer)
            M.search_bar:run_search() -- search again
        end
    end
end

function M.force_search_window(ev)
    if vim.api.nvim_get_current_win() == M.search_bar.win_id then
        if M.search_bar.query_buffer and M.search_bar.query_buffer ~= consts.buffer.INVALID_BUFFER and ev.buf ~= M.search_bar.query_buffer then
            vim.api.nvim_win_set_buf(M.search_bar.win_id, M.search_bar.query_buffer) -- FIX ME: we need to close the buffer that was attempted to be opened?
            vim.api.nvim_win_call(M.search_bar.host_window, function()
                vim.api.nvim_win_set_buf(0, ev.buf) -- FIX ME: we need to close the buffer that was attempted to be opened?
            end)

        end
    end
end

function M.search_curr_cursor_word()
    M.search_bar:search_cursor_word()
end

function M.search_curr_v_selection()
    M.search_bar:search_current_selection()
end

function M.scout_graceful_close(ev)
    local targetWin = ev.file
    if targetWin:find(consts.search.search_name, 1, true) then
        M.search_bar.highlighter:clear_highlights(M.search_bar.highlighter.hl_buf)
        M.search_bar:close()
    end
end

function M.main(keymap_conf)
    vim.api.nvim_create_autocmd({consts.events.WINDOW_RESIZED}, {
        callback = M.move_scout_search_bar
    })
    vim.api.nvim_create_autocmd({consts.events.WINDOW_LEAVE_EVENT}, {
        callback = function(ev)
            if ev.buf == M.search_bar.query_buffer then
                M.search_bar.highlighter:clear_highlights(M.search_bar.highlighter.hl_buf)
            end
            M.search_bar.was_last_focused = ev.buf == M.search_bar.query_buffer
        end
    })
    vim.api.nvim_create_autocmd({consts.events.BUFFER_ENTER}, {
        callback = M.update_scout_context
    })

    vim.api.nvim_create_autocmd({consts.events.BUFFER_ENTER}, {
        callback = M.force_search_window
    })

    vim.api.nvim_create_autocmd({consts.events.QUIT_PRE_HOOK}, {
        callback = M.scout_graceful_close
    })

    vim.api.nvim_create_autocmd({consts.events.TAB_ENTER_EVENT, consts.events.WINDOW_ENTER_EVENT}, {
        callback = function(ev)
            local new_window = vim.api.nvim_get_current_win()
            local config = vim.api.nvim_win_get_config(new_window)
            local buffer_type = vim.api.nvim_get_option_value("buftype", {buf = vim.api.nvim_get_current_buf()})

            if buffer_type == "nofile" or config.relative ~= "" then
                return
            end

            if M.search_bar:is_open() and new_window ~= M.search_bar.win_id and new_window ~= M.search_bar.host_window then
                local contents = M.search_bar:get_window_contents()
                M.search_bar:close()
                if M.search_bar.was_last_focused then -- there's likely a better way to handle this...?
                    M.search_bar:open(false, true) -- do not enter insert mode or DO focus the window
                else
                    M.search_bar:open(false, false) -- do not enter insert mode and do not focus the window
                end
                M.search_bar:set_window_contents(contents)
            end
        end
    })
    vim.keymap.set('n', keymap_conf.toggle_search, M.toggle, {}) -- likely change for obvious reasons later
    vim.keymap.set('n', keymap_conf.toggle_focus, M.toggle_scout_focus, {})
    vim.keymap.set('n', keymap_conf.search_curr_word, M.search_curr_cursor_word, {})
    vim.keymap.set('v', keymap_conf.search_curr_word, M.search_curr_v_selection, {})
end
return M
