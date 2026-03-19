local scout = require('nvim-scout.init')
local default_conf = require('nvim-scout.config.config').defaults
local consts = require('nvim-scout.utils.consts')
local utils = require('spec.spec_utils')
local func_helpers = require('spec.functional.f_spec_helpers')
local win_direct = func_helpers.WINDOW_DIRECTIONS


local async_host_windows_assert = function (...)
    local searchbar, expected = ...
    if not expected then
        expected = vim.api.nvim_get_current_win()
    end
    assert.equals(searchbar.host, expected)
end

local async_search_windows_assert = function (...)
    local search, expected = ...
    if not expected then
        expected = vim.api.nvim_get_current_win()
    end
    assert.equals(search.id, expected)
end

local async_window_resize_assert = function (...)
    local test_scout, searchbar = ...
    local host_window_width = vim.api.nvim_win_get_width(searchbar.host)
    local host_window_col = vim.api.nvim_win_get_position(searchbar.host)[2]
    local search_config = test_scout.searchbar_manager:get_searchbar_config().nvim_open_win_config
    local expected_width = math.floor(host_window_width * test_scout.searchbar_manager.width_percentage)
    assert.equals(search_config.width, expected_width)
    assert.equals(search_config.col, host_window_col + host_window_width - expected_width - 1)
end

local async_new_tab_assert = function (...)
    local searchbar, first_host = ...
    local host_window = searchbar.host
    local win_buf = vim.api.nvim_win_get_buf(host_window)
    local buf_name = vim.api.nvim_buf_get_name(win_buf)
    assert.is_not.equal(first_host, searchbar.host)
    assert.equals(buf_name, "") -- new tabs should be empty name
    assert.equals(vim.api.nvim_get_current_win(), searchbar.id)
end

local async_split_window_assert = function (...)
    local searchbar, old_window, new_buffer = ...
    local host_window = searchbar.host
    local win_buf = vim.api.nvim_win_get_buf(host_window)
    local buf_name = vim.api.nvim_buf_get_name(win_buf)
    assert.is_not.equal(old_window, host_window)
    assert(string.find(buf_name, new_buffer))
    assert.equals(vim.api.nvim_get_current_win(), searchbar.id)
end

local async_new_buffer_on_scout = function (...)
    local searchbar, expected_query_buffer, new_buffer = ...
    local win_buf = vim.api.nvim_win_get_buf(searchbar.host)
    local buf_name = vim.api.nvim_buf_get_name(win_buf)
    assert.equals(searchbar.buffer, expected_query_buffer)
    assert(string.find(buf_name, new_buffer))
    assert.equals(vim.api.nvim_get_current_win(), searchbar.id)
end

describe('Functional: Scout ', function ()

    function test_global_keymaps(toggle_key, focus_key, test_scout)
        utils:emulate_user_keypress(toggle_key)
        assert(test_scout.searchbar_manager:is_searchbar_open())

        utils:emulate_user_keypress(toggle_key)
        assert.equals(false, test_scout.searchbar_manager:is_searchbar_open())

        utils:emulate_user_keypress(toggle_key)
        assert.equals(vim.api.nvim_get_current_buf(), scout.query_buffer)

        func_helpers:move_windows(win_direct.LEFT)
        assert.are_not.equal(vim.api.nvim_get_current_buf(), scout.query_buffer)

        utils:emulate_user_keypress(focus_key)
        assert.equals(vim.api.nvim_get_current_buf(), scout.query_buffer)

    end

    after_each(function ()
        scout.close_search()
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
        assert.equals(vim.api.nvim_get_current_buf(), scout.query_buffer)
        assert.equals(scout.searchbar_manager:get_searchbar_contents(), "typedef")

        test_line = 125
        test_col = 21
        func_helpers:move_windows(win_direct.LEFT)
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})  -- line 26 starts with typedef
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(scout.searchbar_manager:get_searchbar_contents(), "MAX_ITEMS")
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
        assert.equals(vim.api.nvim_get_current_buf(), scout.query_buffer)
        assert.equals(scout.searchbar_manager:get_searchbar_contents(), "int compare_ints")

        func_helpers:move_windows(win_direct.LEFT)
        test_line = 55
        test_col = 0
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})
        utils:highlight_words_in_visual_mode(5)
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(scout.searchbar_manager:get_searchbar_contents(), "Node *create_node(int id")

        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
        func_helpers:move_windows(win_direct.LEFT)
        test_line = 94
        test_col = 34
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})
        utils:highlight_words_in_visual_mode(8)
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(scout.searchbar_manager:get_searchbar_contents(), "value=%d, perms=[r:%u w")
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
        assert.equals(vim.api.nvim_get_current_buf(), scout.query_buffer)
        assert.equals(scout.searchbar_manager:get_searchbar_contents(), "coroutine.yield(i")

        func_helpers:move_windows(win_direct.LEFT)
        test_line = 104
        test_col = 15
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})
        utils:highlight_words_in_visual_mode(2, backwards)
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(vim.api.nvim_get_current_buf(), scout.query_buffer)
        assert.equals(scout.searchbar_manager:get_searchbar_contents(), "local function m")
    end)

    it('toggles focus between search and the current window when toggle search is pressed', function ()
        scout.setup()
        local test_buf = "js_buffer.js"
        func_helpers:reset_open_buf(test_buf)
        scout.open_search()
        local searchbar = scout.searchbar_manager:get_searchbar()
        local scout_window = searchbar.id
        local edit_buffer_window = searchbar.host
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
        local test_buf = "c_buffer.c"
        local searchbar = scout.searchbar_manager:get_searchbar()
        func_helpers:close_all_tabs_and_open_buffer(test_buf)
        scout.open_search()
        utils:emulate_user_keypress(default_conf.keymaps.toggle_focus)
        local first_win = vim.api.nvim_get_current_win()
        assert.equals(searchbar.host, first_win)
        vim.cmd('vs')
        func_helpers:move_windows(win_direct.LEFT)
        local second_win = vim.api.nvim_get_current_win()
        assert.are_not.equal(first_win, second_win)
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, searchbar, second_win)

        func_helpers:move_windows(win_direct.RIGHT)
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, searchbar, first_win)

        -- should not open when switching between windows once closed
        scout:close_search()
        assert.is_not(scout.searchbar_manager:is_searchbar_open())
        assert.equals(vim.api.nvim_get_current_win(), first_win)
        func_helpers:move_windows(win_direct.LEFT)
        assert.is_not(scout.searchbar_manager:is_searchbar_open())
        assert.equals(vim.api.nvim_get_current_win(), second_win)
        func_helpers:move_windows(win_direct.RIGHT)
        assert.equals(vim.api.nvim_get_current_win(), first_win)
        assert.is_not(scout.searchbar_manager:is_searchbar_open())
    end)

    it('keeps the currently focused window when switching tabs', function ()
        scout.setup()
        local test_buf = "lua_buffer.lua"
        local searchbar = scout.searchbar_manager:get_searchbar()
        func_helpers:reset_open_buf(test_buf)
        scout.open_search()
        utils:async_asserts(consts.test.async_delay, async_search_windows_assert, searchbar)
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_search_windows_assert, searchbar)
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_search_windows_assert, searchbar)
        utils:emulate_user_keypress(keymap_defaults.toggle_focus)
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, searchbar)
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, searchbar)
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, searchbar)
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, searchbar)
    end)

    it('follows the user through tab navigation', function ()
        scout.setup()
        local search_bar = scout.searchbar_manager:get_searchbar()
        local test_buf = "lua_buffer.lua"
        func_helpers:close_all_tabs_and_open_buffer(test_buf)
        scout.open_search()
        utils:emulate_user_keypress(keymap_defaults.toggle_focus)
        local first_win = vim.api.nvim_get_current_win()
        assert.equals(search_bar.host, first_win)
        func_helpers:make_new_tab()
        local second_win = vim.api.nvim_get_current_win()
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, search_bar, second_win)

        func_helpers:make_new_tab()
        local third_win = vim.api.nvim_get_current_win()
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, search_bar, third_win)
        utils:emulate_user_keypress('gt')
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, search_bar, first_win)
        utils:emulate_user_keypress('gt')
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, search_bar, second_win)
        utils:emulate_user_keypress('gt')
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, search_bar, third_win)

        utils:emulate_user_keypress('gT')
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, search_bar, second_win)
        utils:emulate_user_keypress('gT')
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, search_bar, first_win)
        utils:emulate_user_keypress('gT')
        utils:async_asserts(consts.test.async_delay, async_host_windows_assert, search_bar, third_win)
        scout.close_search()

        assert.is_not(scout.searchbar_manager:is_searchbar_open())
        utils:emulate_user_keypress('gT')
        utils:emulate_user_keypress('gT')
        utils:emulate_user_keypress('gT')
        assert.is_not(scout.searchbar_manager:is_searchbar_open())

        utils:emulate_user_keypress('gt')
        utils:emulate_user_keypress('gt')
        utils:emulate_user_keypress('gt')
    end)

     it('adjusts scout\'s position if a new window is opened', function ()
        scout.setup()
        scout.open_search()
        local searchbar = scout.searchbar_manager:get_searchbar()
        assert(scout.searchbar_manager:is_searchbar_open())
        local host_window_width = vim.api.nvim_win_get_width(searchbar.host)
        local search_config = scout.searchbar_manager:get_searchbar_config()
        assert.equals(search_config.nvim_open_win_config.width,
            host_window_width * scout.searchbar_manager.width_percentage)
        local test_buf = "lorem_buf.txt"
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(keymap_defaults.toggle_focus)
        vim.cmd('vs') -- split the buffer views
        utils:async_asserts(consts.test.async_delay, async_window_resize_assert, scout, searchbar)

        func_helpers:move_windows(win_direct.RIGHT)
        utils:async_asserts(consts.test.async_delay, async_window_resize_assert, scout, searchbar)

        func_helpers:move_windows(win_direct.LEFT)
        utils:async_asserts(consts.test.async_delay, async_window_resize_assert, scout, searchbar)
        vim.cmd('vs') -- split the buffer views
        utils:async_asserts(consts.test.async_delay, async_window_resize_assert, scout, searchbar)
     end)

    it('attaches to the new tab when scout is focused', function ()
        scout.setup()
        scout.open_search()
        local searchbar = scout.searchbar_manager:get_searchbar()
        local current_host = searchbar.host
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_new_tab_assert, searchbar, current_host)

        current_host = searchbar.host
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_new_tab_assert, searchbar, current_host)

        current_host = searchbar.host
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_new_tab_assert, searchbar, current_host)

        current_host = searchbar.host
        func_helpers:make_new_tab()
        utils:async_asserts(consts.test.async_delay, async_new_tab_assert, searchbar, current_host)
    end)

    it('attaches to the new split window when scout is focused', function ()
        local test_buf = "c_buffer.c"
        func_helpers:close_all_tabs_and_open_buffer(test_buf)
        scout.setup()
        local searchbar = scout.searchbar_manager:get_searchbar()
        local host_window = scout.host
        scout.open_search()
        test_buf = "lua_buffer.lua"
        spec_utils:split_test_buffer(test_buf)
        utils:async_asserts(consts.test.async_delay, async_split_window_assert, searchbar, host_window, test_buf)

        host_window = scout.host
        test_buf = "js_buffer.js"
        spec_utils:split_test_buffer(test_buf)
        utils:async_asserts(consts.test.async_delay, async_split_window_assert, searchbar, host_window, test_buf)

        host_window = scout.host
        test_buf = "c_buffer.c"
        spec_utils:split_test_buffer(test_buf)
        utils:async_asserts(consts.test.async_delay, async_split_window_assert,searchbar, host_window, test_buf)
    end)

    it('opens a new buffer in the host window when scout is focused and a buffer change is attempted', function ()
        scout.setup()
        local searchbar = scout.searchbar_manager:get_searchbar()
        local test_buf = "c_buffer.c"
        utils:open_test_buffer(test_buf)
        scout.open_search()
        local query_buf = scout.query_buffer -- assert this doesn't change

        test_buf = "js_buffer.js"
        utils:open_test_buffer(test_buf)
        utils:async_asserts(consts.test.async_delay, async_new_buffer_on_scout, searchbar, query_buf, test_buf)

        test_buf = "lua_buffer.lua"
        utils:open_test_buffer(test_buf)
        utils:async_asserts(consts.test.async_delay, async_new_buffer_on_scout, searchbar, query_buf, test_buf)

        test_buf = "lorem_buf.txt"
        utils:open_test_buffer(test_buf)
        utils:async_asserts(consts.test.async_delay, async_new_buffer_on_scout, searchbar, query_buf, test_buf)
    end)

end)



