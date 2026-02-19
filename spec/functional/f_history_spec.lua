local scout = require('nvim-scout.init')
local consts = require('nvim-scout.lib.consts')
local default_conf = require('nvim-scout.lib.config').defaults
local utils = require('spec.spec_utils')
local def_keymaps = default_conf.keymaps
local func_helpers = require('spec.functional.f_spec_helpers')

local async_check_added_entry = function (...)
    local history, search, expected_count = ...

    assert.equals(#history.entries, expected_count)
    assert.equals(history:get_entry(expected_count), search)
    if expected_count == history.max_entries then
        assert.equals(history.history_index, 1)
    else
        assert.equals(history.history_index, expected_count + 1)
    end
end

local async_check_navigate_history = function (...)
    local search, expected_index, expected_entry = ...

    assert.equals(search:get_window_contents(), expected_entry)
    assert.equals(search.history.viewing_index, expected_index)
end

local async_check_only_searches = function (...)
    local search, search_string, expected_count = ...

    assert.equals(search:get_window_contents(), search_string)
    assert.equals(#search.history.entries, expected_count)

    if expected_count > 0 then
        assert.equals(search.history:get_entry(expected_count), search_string)
    end
end

local async_check_same_search = function(...)
    local history, unc_entries = ... -- unique non consecutive entries
    assert.equals(#history.entries, unc_entries)
end

describe('Functional: History', function ()

    before_each(function ()
        scout.setup()
        scout.toggle()
        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
    end)

    after_each(function ()
        scout.toggle()
    end)

    it('holds user searches', function ()
        local test_buf = "js_buffer.js"
        local history = scout.search_bar.history
        local search_text = "init"
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        assert.equals(#history.entries, 0)
        func_helpers:search_for_text(search_text)
        utils:async_asserts(consts.test.async_delay, async_check_added_entry, history, search_text, 1)

        search_text = "promise"
        func_helpers:clear_query_and_search(search_text)
        utils:async_asserts(consts.test.async_delay, async_check_added_entry, history, search_text, 2)

        search_text = "Eric Spidle is so cool" -- not in the buffer
        func_helpers:clear_query_and_search(search_text)
        utils:async_asserts(consts.test.async_delay, async_check_added_entry, history, search_text, 3)

        search_text = "const map = new"
        func_helpers:clear_query_and_search(search_text)
        utils:async_asserts(consts.test.async_delay, async_check_added_entry, history, search_text, 4)

        search_text = "abcdefghijklmnopqrstuvwxyz[]*@($@)!---="
        func_helpers:clear_query_and_search(search_text)
        utils:async_asserts(consts.test.async_delay, async_check_added_entry, history, search_text, 5)

        search_text = "                                             "
        func_helpers:clear_query_and_search(search_text)
        utils:async_asserts(consts.test.async_delay, async_check_added_entry, history, search_text, 6)

    end)

    it('can navigate user\'s search history', function ()
        local test_buf = "c_buffer.c"
        local searches = {"define", "->", "int", "const", "node *", "state", "create_"}
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        func_helpers:search_multiple_items(searches)

        utils:keycodes_user_keypress(def_keymaps.next_history)
        utils:async_asserts(consts.test.async_delay, async_check_navigate_history, scout.search_bar, 1, "define")

        utils:keycodes_user_keypress(def_keymaps.next_history)
        utils:async_asserts(consts.test.async_delay, async_check_navigate_history, scout.search_bar, 2, "->")

        utils:keycodes_user_keypress(def_keymaps.next_history)
        utils:async_asserts(consts.test.async_delay, async_check_navigate_history, scout.search_bar, 3, "int")

        utils:keycodes_user_keypress(def_keymaps.next_history)
        utils:async_asserts(consts.test.async_delay, async_check_navigate_history, scout.search_bar, 4, "const")

        utils:keycodes_user_keypress(def_keymaps.next_history)
        utils:async_asserts(consts.test.async_delay, async_check_navigate_history, scout.search_bar, 5, "node *")

        utils:keycodes_user_keypress(def_keymaps.next_history)
        utils:async_asserts(consts.test.async_delay, async_check_navigate_history, scout.search_bar, 6, "state")

        utils:keycodes_user_keypress(def_keymaps.next_history)
        utils:async_asserts(consts.test.async_delay, async_check_navigate_history, scout.search_bar, 7, "create_")

        utils:keycodes_user_keypress(def_keymaps.next_history)
        utils:async_asserts(consts.test.async_delay, async_check_navigate_history, scout.search_bar, 1, "define")

        utils:keycodes_user_keypress(def_keymaps.prev_history)
        utils:async_asserts(consts.test.async_delay, async_check_navigate_history, scout.search_bar, 7, "create_")

        utils:keycodes_user_keypress(def_keymaps.prev_history)
        utils:async_asserts(consts.test.async_delay, async_check_navigate_history, scout.search_bar, 6, "state")

        utils:keycodes_user_keypress(def_keymaps.prev_history)
        utils:async_asserts(consts.test.async_delay, async_check_navigate_history, scout.search_bar, 5, "node *")

        utils:keycodes_user_keypress(def_keymaps.prev_history)
        utils:async_asserts(consts.test.async_delay, async_check_navigate_history, scout.search_bar, 4, "const")

        utils:keycodes_user_keypress(def_keymaps.next_history)
        utils:async_asserts(consts.test.async_delay, async_check_navigate_history, scout.search_bar, 5, "node *")
    end)

    it('only adds entries that are actively searched for', function ()
        local test_buf = "lua_buffer.lua"
        local search_text = "test search"
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        utils:emulate_user_typing(search_text)

        utils:async_asserts(consts.test.async_delay, async_check_only_searches, scout.search_bar, search_text, 0)
        func_helpers:reset_search_bar()
        search_text = "Eric Spidle"
        utils:emulate_user_typing(search_text)
        utils:async_asserts(consts.test.async_delay, async_check_only_searches, scout.search_bar, search_text, 0)

        func_helpers:reset_search_bar()
        search_text = "Should not show up in history"
        utils:emulate_user_typing(search_text)
        utils:async_asserts(consts.test.async_delay, async_check_only_searches, scout.search_bar, search_text, 0)

        func_helpers:reset_search_bar()
        search_text = "Never ever should be in history"
        utils:emulate_user_typing(search_text)
        utils:async_asserts(consts.test.async_delay, async_check_only_searches, scout.search_bar, search_text, 0)

        func_helpers:reset_search_bar()
        search_text = "OK you should show up"
        utils:emulate_user_typing(search_text)
        utils:emulate_user_keypress(def_keymaps.prev_result)
        utils:async_asserts(consts.test.async_delay, async_check_only_searches, scout.search_bar, search_text, 1)
    end)

    it('does not add the same search more then once in a row', function ()
        local test_buf = "js_buffer.js"
        local searches = {"wait it's all javascript???","wait it's all javascript???", "wait it's all javascript???" }
        local history = scout.search_bar.history
        utils:open_test_buffer(test_buf)
        utils:emulate_user_keypress(def_keymaps.toggle_focus)
        func_helpers:search_multiple_items(searches)

        utils:keycodes_user_keypress(def_keymaps.next_history)
        utils:async_asserts(consts.test.async_delay, async_check_same_search, history, 1)

        -- any repeated search WILL be added again so long as it's not a consecutive entry(much like bash history :) )
        searches = {"wait it's all javascript???","sure is", "wait it's all javascript???", "sure is", "sure is", "no wait it's all javascript???","no wait it's all javascript??" }
        func_helpers:search_multiple_items(searches)
        utils:async_asserts(consts.test.async_delay, async_check_same_search, history, 6)
    end)
end)
