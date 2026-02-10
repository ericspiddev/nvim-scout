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

function M.toggle()
    M.search_bar:toggle()
end

function M.refocus_search()
    if M.search_bar:is_open() and vim.api.nvim_win_is_valid(M.search_bar.win_id) then
        vim.api.nvim_set_current_win(M.search_bar.win_id)
    end
end

function M.resize_scout_window(ev)
    if vim.api.nvim_win_is_valid(M.search_bar.host_window) then
        local width = vim.api.nvim_win_get_width(M.search_bar.host_window)
        vim.api.nvim_win_call(M.search_bar.host_window, function()
            M.search_bar:move_window(width)
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

function M.main(keymap_conf)
    vim.api.nvim_create_autocmd({consts.events.WINDOW_RESIZED}, {
        callback = M.resize_scout_window
    })
    vim.api.nvim_create_autocmd({consts.events.WINDOW_LEAVE_EVENT}, {
        callback = function(ev)
            if ev.buf == M.search_bar.query_buffer then
                M.search_bar.highlighter:clear_highlights(M.search_bar.highlighter.hl_buf)
            end
        end
    })
    vim.api.nvim_create_autocmd({consts.events.BUFFER_ENTER}, {
        callback = M.update_scout_context
    })

    vim.keymap.set('n', keymap_conf.toggle_search, M.toggle, {}) -- likely change for obvious reasons later
    vim.keymap.set('n', keymap_conf.focus_search, M.refocus_search, {})
end
return M
