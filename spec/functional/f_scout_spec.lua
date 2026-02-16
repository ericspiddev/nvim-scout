local init = require('nvim-scout.init')
local default_conf = require('nvim-scout.lib.config').defaults
local utils = require('spec.spec_utils')
local func_helpers = require('spec.functional.f_spec_helpers')

describe('Functional: Scout ', function ()

    function test_global_keymaps(toggle_key, focus_key, scout)
        utils:emulate_user_keypress(toggle_key)
        assert(scout.search_bar:is_open())

        utils:emulate_user_keypress(toggle_key)
        assert.equals(false, scout.search_bar:is_open())

        utils:emulate_user_keypress(toggle_key)
        assert.equals(vim.api.nvim_get_current_buf(), scout.search_bar.query_buffer)

        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
        assert.are_not.equal(vim.api.nvim_get_current_buf(), scout.search_bar.query_buffer)

        utils:emulate_user_keypress(focus_key)
        assert.equals(vim.api.nvim_get_current_buf(), scout.search_bar.query_buffer)

        scout.search_bar:close() -- reset for next tests
    end

    it('can be called with an empty setup and have no errors', function ()
        init.setup({})
    end)


    it('sets up keymaps from default config when no options are passed in', function ()
        local scout = init
        local keys = default_conf.keymaps
        scout.setup()
        test_global_keymaps(keys.toggle_search, keys.focus_search, scout)
    end)

    it('uses overridden global keymaps when passed in through the config', function ()
        local scout = init
        local opts = {
            keymaps = {
                toggle_search = "T",
                focus_search = "H",
            }
        }
        scout.setup(opts)
        test_global_keymaps("T", "H", scout)
    end)


    it('can rip the current word and place it in the search bar', function ()
        local scout = init
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
        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})  -- line 26 starts with typedef
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(scout.search_bar:get_window_contents(), "MAX_ITEMS")
        utils:emulate_user_keypress('/')
    end)

    it('can rip the highlighted text in visual mode and place it in the search_bar', function ()
        local scout = init
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

        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
        test_line = 55
        test_col = 0
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})
        utils:highlight_words_in_visual_mode(5)
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(scout.search_bar:get_window_contents(), "Node *create_node(int id")

        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
        test_line = 94
        test_col = 34
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})
        utils:highlight_words_in_visual_mode(8)
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(scout.search_bar:get_window_contents(), "value=%d, perms=[r:%u w")
        scout.search_bar:close() -- reset for next tests
    end)

    it('can handle backwards highlights with visual selection', function ()
        local scout = init
        local backwards = 1
        scout.setup()
        scout.search_bar:close() -- reset for next tests
        local test_buf = "lua_buffer.lua"
        func_helpers:reset_open_buf(test_buf)
        local test_line = 90
        local test_col = 28
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})
        utils:highlight_words_in_visual_mode(4, backwards)
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(vim.api.nvim_get_current_buf(), scout.search_bar.query_buffer)
        assert.equals(scout.search_bar:get_window_contents(), "coroutine.yield(i")

        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
        test_line = 104
        test_col = 15
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})
        utils:highlight_words_in_visual_mode(2, backwards)
        utils:emulate_user_keypress(default_conf.keymaps.search_curr_word)
        assert.equals(vim.api.nvim_get_current_buf(), scout.search_bar.query_buffer)
        assert.equals(scout.search_bar:get_window_contents(), "local function m")
    end)

     -- it('moves the scout window over if a split view is used', function ()
     --    local scout = init
     --    scout.setup()
     --    scout.toggle()
     --    local search_bar = scout.search_bar
     --    assert(scout.search_bar:is_open())
     --    local test_buf = "lorem_buf.txt"
     --    utils:open_test_buffer(test_buf)
     --
     --    vim.print("regular config is " .. vim.inspect(search_bar.query_win_config))
     --    vim.api.nvim_win_set_width(search_bar.host_window, 100)
     --    utils:async_asserts(1000, async_search_col, scout.search_bar)
     --
     -- end)

end)



