local utils = require('spec.spec_utils')
local def_keymaps = require('nvim-scout.lib.config').defaults.keymaps
f_spec_helpers = {}

f_spec_helpers.WINDOW_DIRECTIONS = {
    LEFT = 'h',
    RIGHT = 'l',
    UP='k',
    DOWN='j',
}

function f_spec_helpers:reset_open_buf(buffer)
    utils:emulate_user_keypress(def_keymaps.clear_search)
    utils:keycodes_user_keypress("<C-w>h") -- switch out of window
    utils:open_test_buffer(buffer)
    utils:emulate_user_keypress(def_keymaps.toggle_focus)
end

function f_spec_helpers:close_all_tabs_and_open_buffer(buffer)
    utils:open_test_buffer(buffer)
    vim.cmd('tabonly')
end

function f_spec_helpers:reset_search_bar()
    utils:emulate_user_keypress(def_keymaps.clear_search)
end

function f_spec_helpers:clear_query_and_search(text)
    self:reset_search_bar()
    self:search_for_text(text)
end

function f_spec_helpers:search_for_text(text)
    utils:emulate_user_typing(text)
    utils:emulate_user_keypress(def_keymaps.next_result)
end

function f_spec_helpers:search_multiple_items(searches)
    for _, search in pairs(searches) do
        self:clear_query_and_search(search)
    end
    self:reset_search_bar()
end

function f_spec_helpers:move_windows(direction)
    utils:keycodes_user_keypress("<C-w>" .. direction)
end

function f_spec_helpers:make_new_tab()
    vim.cmd("tabnew")
end

function f_spec_helpers:make_new_tab_and_open_buffer(buffer)
    self:make_new_tab()
    utils:open_test_buffer(buffer)
end

return f_spec_helpers
