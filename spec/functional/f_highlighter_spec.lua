local scout = require('nvim-scout.init')
local utils = require('spec.spec_utils')
local consts = require('nvim-scout.lib.consts')
local def_keymaps = require('nvim-scout.lib.config').defaults.keymaps
local func_helpers = require('spec.functional.f_spec_helpers')
local win_direct = func_helpers.WINDOW_DIRECTIONS

function open_buffer_asserts(hl, buffer)
    utils:open_test_buffer(buffer)
    assert.same(hl.hl_context, utils:test_buffer_to_table(buffer))
end

local async_match_check = function (...)
    local l_hl, expected = ...
    assert.equals(#l_hl.matches, expected)
end

local async_match = function(...)
    local direction, hl, expected_pos = ...
    utils:emulate_user_keypress(direction)
    local actual_pos = vim.api.nvim_win_get_cursor(hl.hl_win)
    assert.same(actual_pos, expected_pos)
end

local async_next_match = function (...)
    async_match(def_keymaps.next_result, ...)
end

local async_previous_match = function (...)
    async_match(def_keymaps.prev_result, ...)
end

local async_extmark_assert = function (...)
    local hl = ...
    local extmarks = vim.api.nvim_buf_get_extmarks(hl.hl_buf, hl.hl_namespace, 0, -1, {details = true} )
    -- Luckily all the extmarks are in order menaing we can use the same indices to test for equality
    -- avoidoing a nested loop
    for index, match in ipairs(hl.matches) do
        local extmark = extmarks[index]
        local row = extmark[2]
        local col = extmark[3]
        local details = extmark[4]
        assert.equals(match:get_highlight_row(), row)
        assert.equals(match.m_start, col)
        assert.equals(match.m_end, details.end_col)
        assert.equals(consts.highlight.MATCH_HIGHLIGHT, details.hl_group)
    end
    -- iterate over matches and
end

local async_check_selected_hl = function(...)
    local hl, selected_match, direction = ...
    utils:emulate_user_keypress(direction)
    local extmarks = vim.api.nvim_buf_get_extmarks(hl.hl_buf, hl.hl_namespace, 0, -1, {details = true} )
    for index, extmark in ipairs(extmarks) do
        local details = extmark[4]
        if index == selected_match then
            assert.equals(consts.highlight.CURR_MATCH_HIGHLIGHT, details.hl_group)
        else
            assert.equals(consts.highlight.MATCH_HIGHLIGHT, details.hl_group)
        end
    end

end

local async_check_extmark_count = function (...)
    local hl, count = ...
    local extmarks = vim.api.nvim_buf_get_extmarks(hl.hl_buf, hl.hl_namespace, 0, -1, {details = true} )
    assert.equals(count, #extmarks)
end

local async_check_virt_text = function (...)
    local hl, buf, match_count, direction = ...
    utils:emulate_user_keypress(direction)
    local wc_extmark = vim.api.nvim_buf_get_extmark_by_id(buf, hl.hl_namespace, hl.hl_wc_ext_id, {details = true} )
    assert(wc_extmark)
    local match_text = wc_extmark[3].virt_text[1][1] -- weird indexing but it works?
    assert.equals(match_count .. "/" .. #hl.matches, match_text)
end

local async_check_no_matches = function (...)
    local hl, buf = ...
    local wc_extmark = vim.api.nvim_buf_get_extmark_by_id(buf, hl.hl_namespace, hl.hl_wc_ext_id, {details = true} )
    assert(wc_extmark)
    local match_text = wc_extmark[3].virt_text[1][1] -- weird indexing but it works?
    assert.equals(consts.virt_text.no_matches, match_text)
end

describe('Functional: Highlighter', function ()
    before_each(function ()
        scout.setup()
        scout.toggle()
        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
    end)

    after_each(function ()
        scout.toggle()
    end)

    it('updates highlight context when opening a new buffer', function ()
        local hl = scout.search_bar.highlighter
        assert.same(hl.hl_context, {""})
        local test_buf = "lorem_buf.txt"
        open_buffer_asserts(hl, test_buf)

        test_buf = "js_buffer.js"
        open_buffer_asserts(hl, test_buf)

        test_buf = "c_buffer.c"
        open_buffer_asserts(hl, test_buf)

        test_buf = "lua_buffer.lua"
        open_buffer_asserts(hl, test_buf)
    end)

    it('can search files for strings and captures the correct number of matches', function ()
        local test_buf = "c_buffer.c"
        local hl = scout.search_bar.highlighter
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)

        utils:emulate_user_typing("n->")
        local expected_matches = 10
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        utils:emulate_user_keypress(def_keymaps.clear_search)

        utils:emulate_user_typing("#include")
        expected_matches = 4
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        utils:emulate_user_keypress(def_keymaps.clear_search)

        utils:emulate_user_typing("aintnowaythisisinthefile")
        expected_matches = 0
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        utils:emulate_user_keypress(def_keymaps.clear_search)

        test_buf = "js_buffer.js"
        func_helpers:reset_open_buf(test_buf)
        utils:emulate_user_typing("node")
        expected_matches = 20
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        test_buf = "lua_buffer.lua"
        func_helpers:reset_open_buf(test_buf)
        utils:emulate_user_typing("luatestapp")
        expected_matches = 1
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
    end)

    it('matches by exact string ignoring case by default', function ()
        local test_buf = "c_buffer.c"
        local hl = scout.search_bar.highlighter
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)

        utils:emulate_user_typing("node")
        local expected_matches = 39
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        utils:emulate_user_keypress(def_keymaps.clear_search)

        utils:emulate_user_typing("NoDE")
        expected_matches = 39
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        utils:emulate_user_keypress(def_keymaps.clear_search)

        utils:emulate_user_typing("(.*)")
        expected_matches = 0
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        utils:emulate_user_keypress(def_keymaps.clear_search)

        utils:emulate_user_typing("[0-9]")
        expected_matches = 0
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        utils:emulate_user_keypress(def_keymaps.clear_search)

        utils:emulate_user_typing("[32]")
        expected_matches = 1
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
    end)

    it('can move the cursor between matches', function ()
        local test_buf = "cursor_test.txt"
        local hl = scout.search_bar.highlighter
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:emulate_user_typing("string")

        utils:async_asserts(consts.test.async_delay, async_next_match, hl, {1,6})
        utils:async_asserts(consts.test.async_delay, async_next_match, hl, {2,7})
        utils:async_asserts(consts.test.async_delay, async_next_match, hl, {3,30})
        utils:async_asserts(consts.test.async_delay, async_next_match, hl, {4,35}) -- last match should loop back to top
        utils:async_asserts(consts.test.async_delay, async_next_match, hl, {1,6}) -- top should go back to bottom
        utils:async_asserts(consts.test.async_delay, async_previous_match, hl, {4,35})
        utils:async_asserts(consts.test.async_delay, async_previous_match, hl, {3,30})
        utils:async_asserts(consts.test.async_delay, async_previous_match, hl, {2,7})
        utils:async_asserts(consts.test.async_delay, async_previous_match, hl, {1,6})

        utils:async_asserts(consts.test.async_delay, async_next_match, hl, {2,7})
        utils:async_asserts(consts.test.async_delay, async_next_match, hl, {3,30})
        utils:async_asserts(consts.test.async_delay, async_previous_match, hl, {2,7})
        utils:async_asserts(consts.test.async_delay, async_previous_match, hl, {1,6})

    end)

    it('moves to the closest match based on window\'s cursor position', function ()
        local test_buf = "cursor_test.txt"
        local hl = scout.search_bar.highlighter
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:emulate_user_typing("cursor")
        vim.api.nvim_win_set_cursor(hl.hl_win, {2, 0})
        utils:async_asserts(consts.test.async_delay, async_next_match, hl, {2,17})
        vim.api.nvim_win_set_cursor(hl.hl_win, {2, 18})
        utils:async_asserts(consts.test.async_delay, async_next_match, hl, {3,8})
        vim.api.nvim_win_set_cursor(hl.hl_win, {3, 15})
        utils:async_asserts(consts.test.async_delay, async_next_match, hl, {4,9})

        vim.api.nvim_win_set_cursor(hl.hl_win, {2, 0})
        utils:async_asserts(consts.test.async_delay, async_previous_match, hl, {1,25})
        vim.api.nvim_win_set_cursor(hl.hl_win, {3, 15})
        utils:async_asserts(consts.test.async_delay, async_previous_match, hl, {3,8})
        vim.api.nvim_win_set_cursor(hl.hl_win, {3, 7})
        utils:async_asserts(consts.test.async_delay, async_previous_match, hl, {2,17})

        -- FIXME/BUG!!!!: these should be reversed in logic....
        vim.api.nvim_win_set_cursor(hl.hl_win, {1, 0})
        utils:async_asserts(consts.test.async_delay, async_previous_match, hl, {1,25})

        -- FIXME/BUG!!!!: these should be reversed in logic....
        vim.api.nvim_win_set_cursor(hl.hl_win, {4, 52})
        utils:async_asserts(consts.test.async_delay, async_next_match, hl, {4,9})
    end)

    it('highlights all the matches with extmarks', function ()
        local test_buf = "c_buffer.c"
        local hl = scout.search_bar.highlighter
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:emulate_user_typing("void")

        utils:async_asserts(consts.test.async_delay, async_extmark_assert, hl)

        test_buf = "js_buffer.js"
        func_helpers:reset_open_buf(test_buf)
        utils:emulate_user_typing("doubled")

        utils:async_asserts(consts.test.async_delay, async_extmark_assert, hl)

        test_buf = "lua_buffer.lua"
        func_helpers:reset_open_buf(test_buf)
        utils:emulate_user_typing("coroutine")
        utils:async_asserts(consts.test.async_delay, async_extmark_assert, hl)
    end)

    it('changes highlight color for selected match', function ()
        local test_buf = "c_buffer.c"
        local hl = scout.search_bar.highlighter
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:emulate_user_typing("void")
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 1, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 2, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 3, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 4, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 3, def_keymaps.prev_result)
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 2, def_keymaps.prev_result)
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 1, def_keymaps.prev_result)
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 12, def_keymaps.prev_result)

        test_buf = "js_buffer.js"
        func_helpers:reset_open_buf(test_buf)
        utils:emulate_user_typing("function")
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 1, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 2, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 3, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 2, def_keymaps.prev_result)
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 1, def_keymaps.prev_result)
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 7, def_keymaps.prev_result)
        utils:async_asserts(consts.test.async_delay, async_check_selected_hl, hl, 1, def_keymaps.next_result)

    end)

    it('tracks the current match index and totals in the search bar virt_text', function ()
        local test_buf = "lua_buffer.lua"
        local hl = scout.search_bar.highlighter
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:emulate_user_typing("cur")

        utils:async_asserts(consts.test.async_delay, async_check_virt_text, hl, scout.search_bar.query_buffer, 1, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_virt_text, hl, scout.search_bar.query_buffer, 2, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_virt_text, hl, scout.search_bar.query_buffer, 3, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_virt_text, hl, scout.search_bar.query_buffer, 4, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_virt_text, hl, scout.search_bar.query_buffer, 5, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_virt_text, hl, scout.search_bar.query_buffer, 6, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_virt_text, hl, scout.search_bar.query_buffer, 7, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_virt_text, hl, scout.search_bar.query_buffer, 8, def_keymaps.next_result)

        utils:async_asserts(consts.test.async_delay, async_check_virt_text, hl, scout.search_bar.query_buffer, 1, def_keymaps.next_result)
        utils:async_asserts(consts.test.async_delay, async_check_virt_text, hl, scout.search_bar.query_buffer, 8, def_keymaps.prev_result)
        utils:async_asserts(consts.test.async_delay, async_check_virt_text, hl, scout.search_bar.query_buffer, 7, def_keymaps.prev_result)
        utils:async_asserts(consts.test.async_delay, async_check_virt_text, hl, scout.search_bar.query_buffer, 6, def_keymaps.prev_result)
        utils:async_asserts(consts.test.async_delay, async_check_virt_text, hl, scout.search_bar.query_buffer, 5, def_keymaps.prev_result)
    end)

    it('displays no matches when a search yields no matches', function ()
        local test_buf = "c_buffer.c"
        local hl = scout.search_bar.highlighter
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:emulate_user_typing("Eric Spidle this cannot be in the file")

        utils:async_asserts(consts.test.async_delay, async_check_no_matches, hl, scout.search_bar.query_buffer)

        test_buf = "js_buffer.js"
        func_helpers:reset_open_buf(test_buf)
        utils:emulate_user_typing("privateId1")
        utils:async_asserts(consts.test.async_delay, async_check_no_matches, hl, scout.search_bar.query_buffer)
    end)

    it('clears the extmarks when leaving the search bar and restores them on refocus', function ()
        local test_buf = "js_buffer.js"
        local hl = scout.search_bar.highlighter
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:emulate_user_typing("node")
        utils:async_asserts(consts.test.async_delay, async_check_extmark_count, hl, 20)
        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
        utils:async_asserts(consts.test.async_delay, async_check_extmark_count, hl, 0)

        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:async_asserts(consts.test.async_delay, async_check_extmark_count, hl, 20)
        func_helpers:reset_search_bar()

        utils:emulate_user_typing("const")
        utils:async_asserts(consts.test.async_delay, async_check_extmark_count, hl, 15)
        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
        utils:async_asserts(consts.test.async_delay, async_check_extmark_count, hl, 0)

        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:async_asserts(consts.test.async_delay, async_check_extmark_count, hl, 15)
    end)

    it('refreshes results if a change is made after switching out of search', function ()
        local test_buf = "c_buffer.c"
        local hl = scout.search_bar.highlighter
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:emulate_user_typing("node")
        utils:async_asserts(consts.test.async_delay, async_check_extmark_count, hl, 39)
        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
        utils:async_asserts(consts.test.async_delay, async_check_extmark_count, hl, 0)
        local test_line = 49
        local test_col = 6
        vim.api.nvim_win_set_cursor(0, {test_line, test_col})
        utils:emulate_user_keypress('ciw')
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:async_asserts(consts.test.async_delay, async_check_extmark_count, hl, 38)

    end)

    it('runs searches across all tabs as scout follows ', function ()
        local test_buf = "c_buffer.c"
        local hl = scout.search_bar.highlighter
        func_helpers:close_all_tabs_and_open_buffer(test_buf)

        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:emulate_user_typing("ty")

        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        local expected_matches = 5
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        expected_matches = 3
        func_helpers:make_new_tab_and_open_buffer("js_buffer.js")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        expected_matches = 1
        func_helpers:make_new_tab_and_open_buffer("lua_buffer.lua")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        utils:emulate_user_keypress('gt')
        expected_matches = 5
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        utils:emulate_user_keypress('gT')
        expected_matches = 1
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        utils:emulate_user_keypress('gt')
        utils:emulate_user_keypress('gt')
        expected_matches = 3
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
    end)

    it('runs searches across windows as scout follows and updates highlight window to split', function ()
        local test_buf = "lua_buffer.lua"
        local hl = scout.search_bar.highlighter
        func_helpers:close_all_tabs_and_open_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:emulate_user_typing("ty")

        -- BUG: currently splitting inside of scout closes the current hl_buf and opens the new one
        -- so for now refocus host window
        utils:emulate_user_keypress(def_keymaps.toggle_focus)

        local expected_matches = 1
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        assert.equals(hl.hl_win, vim.api.nvim_get_current_win())

        expected_matches = 3
        utils:split_test_buffer("js_buffer.js")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        assert.equals(hl.hl_win, vim.api.nvim_get_current_win())

        expected_matches = 5
        utils:split_test_buffer("c_buffer.c")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        assert.equals(hl.hl_win, vim.api.nvim_get_current_win())

        func_helpers:move_windows(win_direct.RIGHT)
        expected_matches = 3
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        assert.equals(hl.hl_win, vim.api.nvim_get_current_win())

        func_helpers:move_windows(win_direct.RIGHT)
        expected_matches = 1
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        assert.equals(hl.hl_win, vim.api.nvim_get_current_win())

        func_helpers:move_windows(win_direct.LEFT)
        func_helpers:move_windows(win_direct.LEFT)
        expected_matches = 5
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        assert.equals(hl.hl_win, vim.api.nvim_get_current_win())
    end)

end)

