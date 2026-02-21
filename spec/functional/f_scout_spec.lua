local scout = require('nvim-scout.init')
local default_conf = require('nvim-scout.lib.config').defaults
local consts = require('nvim-scout.lib.consts')
local utils = require('spec.spec_utils')
local func_helpers = require('spec.functional.f_spec_helpers')
local win_direct = func_helpers.WINDOW_DIRECTIONS


local async_host_windows_assert = function (...)
    local search, expected = ...
    if not expected then
        expected = vim.api.nvim_get_current_win()
    end
    assert.equals(search.host_window, expected)
end

local async_search_windows_assert = function (...)
    local search, expected = ...
    if not expected then
        expected = vim.api.nvim_get_current_win()
    end
    assert.equals(search.win_id, expected)
end

local async_width_assert = function (...)
    local search_bar, search_config = ...
    local host_window_width = vim.api.nvim_win_get_width(search_bar.host_window)
    local expected_width = math.floor(host_window_width * search_bar.width_percent)
    assert.equals(search_config.width, expected_width)
    assert.equals(search_config.col, search_bar:get_search_bar_col(search_bar.host_window, expected_width))
end

describe('Functional: Scout ', function ()

    function test_global_keymaps(toggle_key, focus_key, scout)
        utils:emulate_user_keypress(toggle_key)
        assert(scout.search_bar:is_open())

        utils:emulate_user_keypress(toggle_key)
        assert.equals(false, scout.search_bar:is_open())

        utils:emulate_user_keypress(toggle_key)
        assert.equals(vim.api.nvim_get_current_buf(), scout.search_bar.query_buffer)

        func_helpers:move_windows(win_direct.LEFT)
        assert.are_not.equal(vim.api.nvim_get_current_buf(), scout.search_bar.query_buffer)

        utils:emulate_user_keypress(focus_key)
        assert.equals(vim.api.nvim_get_current_buf(), scout.search_bar.query_buffer)

    end


    after_each(function ()
       scout.search_bar:close()
    end)
    it('can be called with an empty setup and have no errors', function ()
        scout.setup({})
    end)


    it('sets up keymaps from default config when no options are passed in', function ()
        local keys = default_conf.keymaps
        scout.setup()
        test_global_keymaps(keys.toggle_search, keys.toggle_focus, scout)
    end)

    it('uses overridden global keymaps when passed in through the config', function ()
        local opts = {
            keymaps = {
                toggle_search = "T",
                toggle_focus = "H",
            }
        }
        scout.setup(opts)
        test_global_keymaps("T", "H", scout)
    end)


    it('can rip the current word and place it in the search bar', function ()
        scout.setup()
        local test_buf = "c_buffer.c"
        func_helpers:reset_open_buf(test_buf)
        local test_line = 26
        local test_col = 0
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})  -- line 26 starts with typedef
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(vim.api.nvim_get_current_buf(), scout.search_bar.query_buffer)
        assert.equals(scout.search_bar:get_window_contents(), "typedef")

        test_line = 125
        test_col = 21
        func_helpers:move_windows(win_direct.LEFT)
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})  -- line 26 starts with typedef
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(scout.search_bar:get_window_contents(), "MAX_ITEMS")
    end)

    it('can rip the highlighted text in visual mode and place it in the search_bar', function ()
        scout.setup()
        local test_buf = "c_buffer.c"
        func_helpers:reset_open_buf(test_buf)
        local test_line = 107
        local test_col = 0
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})
        utils:highlight_words_in_visual_mode(1)
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(vim.api.nvim_get_current_buf(), scout.search_bar.query_buffer)
        assert.equals(scout.search_bar:get_window_contents(), "int compare_ints")

        func_helpers:move_windows(win_direct.LEFT)
        test_line = 55
        test_col = 0
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})
        utils:highlight_words_in_visual_mode(5)
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(scout.search_bar:get_window_contents(), "Node *create_node(int id")

        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
        func_helpers:move_windows(win_direct.LEFT)
        test_line = 94
        test_col = 34
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})
        utils:highlight_words_in_visual_mode(8)
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(scout.search_bar:get_window_contents(), "value=%d, perms=[r:%u w")
    end)

    it('can handle backwards highlights with visual selection', function ()
        local backwards = 1
        scout.setup()
        local test_buf = "lua_buffer.lua"
        func_helpers:reset_open_buf(test_buf)
        local test_line = 90
        local test_col = 28
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})
        utils:highlight_words_in_visual_mode(4, backwards)
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(vim.api.nvim_get_current_buf(), scout.search_bar.query_buffer)
        assert.equals(scout.search_bar:get_window_contents(), "coroutine.yield(i")

        func_helpers:move_windows(win_direct.LEFT)
        test_line = 104
        test_col = 15
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})
        utils:highlight_words_in_visual_mode(2, backwards)
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(vim.api.nvim_get_current_buf(), scout.search_bar.query_buffer)
        assert.equals(scout.search_bar:get_window_contents(), "local function m")
    end)

    it('toggles focus between search and the current window when toggle search is pressed', function ()
        scout.setup()
        local test_buf = "js_buffer.js"
        func_helpers:reset_open_buf(test_buf)
        scout.search_bar:open()
        local scout_window = scout.search_bar.win_id
        local edit_buffer_window = scout.search_bar.host_window
        assert.equals(vim.api.nvim_get_current_win(), scout_window)
        utils:emulate_user_keypress(default_conf.keymaps.toggle_focus)
        assert.equals(vim.api.nvim_get_current_win(), edit_buffer_window)
        utils:emulate_user_keypress(default_conf.keymaps.toggle_focus)
        assert.equals(vim.api.nvim_get_current_win(), scout_window)
        utils:emulate_user_keypress(default_conf.keymaps.toggle_focus)
        assert.equals(vim.api.nvim_get_current_win(), edit_buffer_window)
        utils:emulate_user_keypress(default_conf.keymaps.toggle_focus)
        utils:emulate_user_keypress(default_conf.keymaps.toggle_focus)
        utils:emulate_user_keypress(default_conf.keymaps.toggle_focus)
        utils:emulate_user_keypress(default_conf.keymaps.toggle_focus)
        utils:emulate_user_keypress(default_conf.keymaps.toggle_focus)
        utils:emulate_user_keypress(default_conf.keymaps.toggle_focus)
        utils:emulate_user_keypress(default_conf.keymaps.toggle_focus)
        assert.equals(vim.api.nvim_get_current_win(), scout_window)
    end)

    it('follows the currently selected window when opened', function ()
        scout.setup()
        local search_bar = scout.search_bar
        local test_buf = "c_buffer.c"
        func_helpers:close_all_tabs_and_open_buffer(test_buf)
        search_bar:open()
        utils:emulate_user_keypress(default_conf.keymaps.toggle_focus)
        local first_win = vim.api.nvim_get_current_win()
        assert.equals(search_bar.host_window, first_win)
        vim.cmd('vs')
        func_helpers:move_windows(win_direct.LEFT)
        local second_win = vim.api.nvim_get_current_win()
        assert.are_not.equal(first_win, second_win)
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar, second_win)

        func_helpers:move_windows(win_direct.RIGHT)
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar, first_win)

        -- should not open when switching between windows once closed
        search_bar:close()
        assert.is_not(search_bar:is_open())
        assert.equals(vim.api.nvim_get_current_win(), first_win)
        func_helpers:move_windows(win_direct.LEFT)
        assert.is_not(search_bar:is_open())
        assert.equals(vim.api.nvim_get_current_win(), second_win)
        func_helpers:move_windows(win_direct.RIGHT)
        assert.equals(vim.api.nvim_get_current_win(), first_win)
        assert.is_not(search_bar:is_open())
    end)

    it('keeps the currently focused window when switching tabs', function ()
        scout.setup()
        local search_bar = scout.search_bar
        local test_buf = "lua_buffer.lua"
        func_helpers:reset_open_buf(test_buf)
        search_bar:open()
        utils:async_asserts(consts.test.async_delay, async_search_windows_assert, scout.search_bar)
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_search_windows_assert, scout.search_bar)
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_search_windows_assert, scout.search_bar)
        utils:emulate_user_keypress(keymap_defaults.toggle_focus)
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar)
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar)
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar)
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar)
    end)

    it('follows the user through tab navigation', function ()
        scout.setup()
        local search_bar = scout.search_bar
        local test_buf = "lua_buffer.lua"
        func_helpers:close_all_tabs_and_open_buffer(test_buf)
        search_bar:open()
        utils:emulate_user_keypress(keymap_defaults.toggle_focus)
        local first_win = vim.api.nvim_get_current_win()
        assert.equals(search_bar.host_window, first_win)
        func_helpers:make_new_tab()
        local second_win = vim.api.nvim_get_current_win()
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar, second_win)

        func_helpers:make_new_tab()
        local third_win = vim.api.nvim_get_current_win()
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar, third_win)
        utils:emulate_user_keypress('gt')
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar, first_win)
        utils:emulate_user_keypress('gt')
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar, second_win)
        utils:emulate_user_keypress('gt')
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar, third_win)

        utils:emulate_user_keypress('gT')
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar, second_win)
        utils:emulate_user_keypress('gT')
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar, first_win)
        utils:emulate_user_keypress('gT')
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, scout.search_bar, third_win)
        search_bar:close()

        assert.is_not(search_bar:is_open())
        assert.equals(search_bar.host_window, consts.window.INVALID_WINDOW_ID)
        utils:emulate_user_keypress('gT')
        utils:emulate_user_keypress('gT')
        utils:emulate_user_keypress('gT')
        assert.is_not(search_bar:is_open())
        assert.equals(search_bar.host_window, consts.window.INVALID_WINDOW_ID)

        utils:emulate_user_keypress('gt')
        utils:emulate_user_keypress('gt')
        utils:emulate_user_keypress('gt')
        assert.equals(search_bar.host_window, consts.window.INVALID_WINDOW_ID)
    end)

     it('moves the scout window over if a split view is used', function ()
        scout.setup()
        local search_bar = scout.search_bar
        search_bar:open()
        assert(scout.search_bar:is_open())
        local host_window_width = vim.api.nvim_win_get_width(search_bar.host_window)
        local search_config = scout.search_bar.query_win_config
        assert.equals(search_config.width, host_window_width * search_bar.width_percent)
        local test_buf = "lorem_buf.txt"
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(keymap_defaults.toggle_focus)
        vim.cmd('vs') -- split the buffer views
        host_window_width = vim.api.nvim_win_get_width(search_bar.host_window)
        search_config = scout.search_bar.query_win_config
        utils:async_asserts(consts.test.async_delay, async_width_assert, search_bar, search_config)

        func_helpers:move_windows(win_direct.RIGHT)
        host_window_width = vim.api.nvim_win_get_width(search_bar.host_window)
        search_config = scout.search_bar.query_win_config
        utils:async_asserts(consts.test.async_delay, async_width_assert, search_bar, search_config)

        func_helpers:move_windows(win_direct.LEFT)
        host_window_width = vim.api.nvim_win_get_width(search_bar.host_window)
        search_config = scout.search_bar.query_win_config
        utils:async_asserts(consts.test.async_delay, async_width_assert, search_bar, search_config)
     end)

end)



