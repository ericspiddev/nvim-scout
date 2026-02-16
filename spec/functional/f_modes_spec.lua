local scout = require('nvim-scout.init')
local utils = require('spec.spec_utils')
local consts = require('nvim-scout.lib.consts')
local def_keymaps = require('nvim-scout.lib.config').defaults.keymaps
local func_helpers = require('spec.functional.f_spec_helpers')

local REGEX_MODE = consts.modes.lua_pattern
local MATCH_CASE_MODE = consts.modes.case_sensitive

local async_mode_assert = function (...)
    local mode_mgr, specified_mode, expected_status = ...
    local mode = mode_mgr.modes[specified_mode]
    assert(mode)
    assert.equals(mode_mgr:get_mode_status(specified_mode), expected_status)
    if expected_status then
        assert.is_not.equals(mode.banner_window_id, consts.window.INVALID_WINDOW_ID)
        assert.is_not.equals(mode.banner_buf, consts.window.INVALID_WINDOW_ID)
        assert.is_not.equals(mode.search_bar_win, consts.window.INVALID_WINDOW_ID)

        local banner_reads = vim.api.nvim_buf_get_lines(mode.banner_buf, 0, 1, true)[1]
        assert.equals(banner_reads, ' ' .. mode.name ..' ')
    else
        assert.equals(mode.banner_window_id, consts.window.INVALID_WINDOW_ID)
        assert.equals(mode.banner_buf, consts.window.INVALID_WINDOW_ID)
    end
end

local async_match_check = function (...)
    local l_hl, expected = ...
    assert.equals(#l_hl.matches, expected)
end

local async_match_pos_check = function (...)
    local matches = ...
    for _, match in pairs(matches) do
        assert(match.m_start < match.m_end)
    end
end

local async_invalid_check = function (...)
    local search, hl = ...
    local buffer = search.query_buffer
    local hl_ext_mark = hl.hl_wc_ext_id
    local extmark_details = vim.api.nvim_buf_get_extmark_by_id(buffer, hl.hl_namespace, hl_ext_mark, {details = true})[3]
    assert.equals(extmark_details.virt_text[1][1], consts.virt_text.invalid_pattern)

end

describe('Functional: Modes', function ()
    before_each(function ()
        scout.setup()
        scout.toggle()
        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
    end)

    after_each(function ()
        scout.toggle()
    end)

    it('are able to be toggled all with their keymaps', function ()
        local mode_mgr = scout.search_bar.mode_manager
        utils:emulate_user_keypress(def_keymaps.focus_search)
        utils:keycodes_user_keypress(def_keymaps.case_sensitive_toggle)
        utils:async_asserts(consts.test.async_delay, async_mode_assert, mode_mgr, MATCH_CASE_MODE, true)

        utils:keycodes_user_keypress(def_keymaps.pattern_toggle)
        utils:async_asserts(consts.test.async_delay, async_mode_assert, mode_mgr, REGEX_MODE, true)
        utils:async_asserts(consts.test.async_delay, async_mode_assert, mode_mgr, MATCH_CASE_MODE, true)


        utils:keycodes_user_keypress(def_keymaps.case_sensitive_toggle)
        utils:async_asserts(consts.test.async_delay, async_mode_assert, mode_mgr, MATCH_CASE_MODE, false)
        utils:async_asserts(consts.test.async_delay, async_mode_assert, mode_mgr, REGEX_MODE, true)

        utils:keycodes_user_keypress(def_keymaps.pattern_toggle)
        utils:async_asserts(consts.test.async_delay, async_mode_assert, mode_mgr, REGEX_MODE, false)
        utils:async_asserts(consts.test.async_delay, async_mode_assert, mode_mgr, MATCH_CASE_MODE, false)
    end)

    it('properly applies the Match Case mode for both on and off', function ()
        local test_buf = "c_buffer.c"
        local hl = scout.search_bar.highlighter
        local expected_matches = 39
        func_helpers:reset_open_buf(test_buf)
        utils:emulate_user_typing("node")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        func_helpers:reset_search_bar()

        expected_matches = 19
        utils:keycodes_user_keypress(def_keymaps.case_sensitive_toggle)
        utils:emulate_user_typing("node")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        expected_matches = 20
        func_helpers:reset_search_bar()
        utils:emulate_user_typing("Node")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)


        expected_matches = 0
        func_helpers:reset_search_bar()
        utils:emulate_user_typing("NODE")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        utils:keycodes_user_keypress(def_keymaps.case_sensitive_toggle)
        expected_matches = 39
        func_helpers:reset_search_bar()
        utils:emulate_user_typing("NODE")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

    end)

    it('properly applies the lua pattern mode for both on and off', function ()
        local test_buf = "lua_buffer.lua"
        local hl = scout.search_bar.highlighter
        local expected_matches = 1
        func_helpers:reset_open_buf(test_buf)
        utils:emulate_user_typing("[\"app_name\"]")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        utils:keycodes_user_keypress(def_keymaps.pattern_toggle)

        expected_matches = 610 -- pattern mode now catches every single ", a,p,_,n,m or e (610 or 611?)
        func_helpers:reset_search_bar()
        utils:emulate_user_typing("[\"app_name\"]")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        expected_matches = 38
        func_helpers:reset_search_bar()
        utils:emulate_user_typing("(.*)")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        expected_matches = 33
        func_helpers:reset_search_bar()
        utils:emulate_user_typing("%d")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        utils:keycodes_user_keypress(def_keymaps.pattern_toggle)

        expected_matches = 0
        func_helpers:reset_search_bar()
        utils:emulate_user_typing("(.*)")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        expected_matches = 2
        func_helpers:reset_search_bar()
        utils:emulate_user_typing("%d")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
    end)

    it('reports an invalid pattern in the search buffer', function ()
        local test_buf = "c_buffer.c"
        local hl = scout.search_bar.highlighter
        local expected_matches = 0
        func_helpers:reset_search_bar()
        func_helpers:reset_open_buf(test_buf)
        utils:keycodes_user_keypress(def_keymaps.pattern_toggle)
        utils:emulate_user_typing("%")
        utils:async_asserts(consts.test.async_delay, async_invalid_check, scout.search_bar, hl)

        func_helpers:reset_search_bar()
        utils:emulate_user_typing("%%%")
        utils:async_asserts(consts.test.async_delay, async_invalid_check, scout.search_bar, hl)

        func_helpers:reset_search_bar()
        utils:emulate_user_typing("[[[[[[[[")
        utils:async_asserts(consts.test.async_delay, async_invalid_check, scout.search_bar, hl)

        func_helpers:reset_search_bar()
        utils:emulate_user_typing("[][][")
        utils:async_asserts(consts.test.async_delay, async_invalid_check, scout.search_bar, hl)

        func_helpers:reset_search_bar()
        utils:emulate_user_typing("[]")
        utils:async_asserts(consts.test.async_delay, async_invalid_check, scout.search_bar, hl)

        func_helpers:reset_search_bar()
        utils:emulate_user_typing("][")
        utils:async_asserts(consts.test.async_delay, async_invalid_check, scout.search_bar, hl)

        func_helpers:reset_search_bar()
        utils:emulate_user_typing("%ba")
        utils:async_asserts(consts.test.async_delay, async_invalid_check, scout.search_bar, hl)

        func_helpers:reset_search_bar()
        utils:emulate_user_typing("[^]")
        utils:async_asserts(consts.test.async_delay, async_invalid_check, scout.search_bar, hl)

        func_helpers:reset_search_bar()
        utils:emulate_user_typing("%10")
        utils:async_asserts(consts.test.async_delay, async_invalid_check, scout.search_bar, hl)

        expected_matches = 1477
        func_helpers:reset_search_bar()
        utils:emulate_user_typing("[a-z]")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

    end)

    it('can search for patterns that would normally get stuck', function ()
        local test_buf = "c_buffer.c"
        local hl = scout.search_bar.highlighter
        local expected_matches = 124
        func_helpers:reset_search_bar()
        func_helpers:reset_open_buf(test_buf)
        utils:keycodes_user_keypress(def_keymaps.pattern_toggle)
        utils:emulate_user_typing(".*") -- search for non empty lines
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        func_helpers:reset_search_bar()
        expected_matches = 0
        utils:emulate_user_typing("$")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        func_helpers:reset_search_bar()
        expected_matches = 2995
        utils:emulate_user_typing(".?")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        func_helpers:reset_search_bar()
        expected_matches = 2995
        utils:emulate_user_typing("--")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
    end)


    it('ignores empty lines when searching', function ()
        local test_buf = "lua_buffer.lua" -- The file has 165 lines
        local hl = scout.search_bar.highlighter
        local expected_matches = 138 -- Only 138 of them have some sort of content
        func_helpers:reset_search_bar()
        func_helpers:reset_open_buf(test_buf)
        utils:keycodes_user_keypress(def_keymaps.pattern_toggle)
        utils:emulate_user_typing(".*") -- should search for all lines
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        utils:async_asserts(consts.test.async_delay, async_match_pos_check, hl.matches)

        expected_matches = 3063 -- Only 138 of them have some sort of content
        func_helpers:reset_open_buf(test_buf)
        utils:emulate_user_typing(".") -- should search for all lines
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
        utils:async_asserts(consts.test.async_delay, async_match_pos_check, hl.matches)
    end)

    it('adjusts search results when a mode toggles on and off', function ()
        local test_buf = "c_buffer.c"
        local hl = scout.search_bar.highlighter
        local expected_matches = 5
        func_helpers:reset_search_bar()
        func_helpers:reset_open_buf(test_buf)
        utils:emulate_user_typing("compare")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        utils:keycodes_user_keypress(def_keymaps.case_sensitive_toggle)
        expected_matches = 3
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        expected_matches = 5
        utils:keycodes_user_keypress(def_keymaps.case_sensitive_toggle)
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        func_helpers:reset_search_bar()
        utils:emulate_user_typing("Compare")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        utils:keycodes_user_keypress(def_keymaps.case_sensitive_toggle)
        expected_matches = 2
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        test_buf = "lua_buffer.lua"
        expected_matches = 1
        func_helpers:reset_search_bar()
        func_helpers:reset_open_buf(test_buf)
        utils:emulate_user_typing("[\"app_name\"]")
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        utils:keycodes_user_keypress(def_keymaps.pattern_toggle)
        expected_matches = 610
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)

        utils:keycodes_user_keypress(def_keymaps.pattern_toggle)
        expected_matches = 1
        utils:async_asserts(consts.test.async_delay, async_match_check, hl, expected_matches)
    end)
end)
