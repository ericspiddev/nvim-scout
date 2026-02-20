local highlight = require('nvim-scout.lib.highlighter')
local stub = require('luassert.stub')
local utils = require('spec.spec_utils')
local consts = require('nvim-scout.lib.consts')
local mode_manager = require('nvim-scout.lib.mode_manager')
local match_object = require('nvim-scout.lib.match')
local assert_match = require('luassert.match')
utils:register_global_logger()

function create_fake_buffer(contents)
    stub(vim.api, "nvim_buf_line_count").returns(#contents)
    stub(vim.api, "nvim_buf_get_lines").returns(contents)
end

function mock_out_highlights()
    stub(vim.api, "nvim_buf_del_extmark").returns()
    stub(vim.api, "nvim_buf_set_extmark").returns()
end

function revert_highlights()
    vim.api.nvim_buf_set_extmark:clear()
    vim.api.nvim_buf_del_extmark:clear()
    vim.api.nvim_buf_set_extmark:revert()
    vim.api.nvim_buf_del_extmark:revert()
end

function string_to_matches(line, pattern, row, ignore_case, regex)
    matches = {}
    if ignore_case then
        line = string.lower(line)
        pattern = string.lower(pattern)
    end

    local pattern_start, pattern_end = string.find(line, pattern, 1, not regex) -- find the pattern here...
    while pattern_start ~= nil do
            -- highlight with start index and end index
            table.insert(matches, match_object:new(row, pattern_start - 1, pattern_end, 0)) -- don't care about extmark_id
            search_index = pattern_end + 1

            pattern_start, pattern_end = string.find(line, pattern, search_index, not regex)
        end

    return matches
end

function create_new_highlighter(window_id, result_style, selected_style, ns_id, mode_mgr)
    window_id = window_id or 0
    result_style = result_style or "matched_style"
    selected_style = selected_style or "selected_style"
    ns_id = ns_id or 0
    mode_mgr = mode_mgr or mode_manager:new(utils:get_supported_modes(ns_id))

    return highlight:new(window_id, result_style, selected_style, ns_id, mode_mgr)
end

function move_cursor_asserts(hl, prev_match, curr_match, result_style, selected_style)
    assert.stub(vim.api.nvim_win_set_cursor).was.called_with(hl.hl_win, {curr_match.row, curr_match.m_start})
    assert.stub(highlight.set_match_highlighting).was.called_with(assert_match.is_table(), prev_match, result_style) -- revert previous match to result style
    assert.stub(vim.api.nvim_buf_del_extmark).was.called_with(hl.hl_buf, hl.hl_namespace, curr_match.extmark_id) -- remove current match style from new selection
    assert.stub(highlight.set_match_highlighting).was.called_with(assert_match.is_table(), curr_match, selected_style) -- new match should now have selected style

    -- reset call chain for new calls
    vim.api.nvim_win_set_cursor:clear()
    highlight.set_match_highlighting:clear()
    vim.api.nvim_buf_del_extmark:clear()
end

describe('highlighter', function ()

    before_each(function ()
        utils:mock_logger_prints()
        mock_out_highlights()
    end)

    after_each(function ()
        utils:revert_logger_prints()
        revert_highlights()
    end)

    it('can populate highlight context', function ()
        local buf_id = 21
        local host_window = 1100
        local buf_content = {
            "test this content out it",
            "the lazy fox jumps over the brown log",
            "idk what else to say do you?",
        }
        stub(vim.api, "nvim_buf_is_valid").returns(true)
        local hl = highlight:new(0, "style1", "style2")

        create_fake_buffer(buf_content)
        assert(hl:populate_hl_context(buf_id, host_window))
        assert.equals(hl.hl_context, buf_content)
        assert.equals(hl.hl_buf, buf_id)

        create_fake_buffer("")
        assert(not hl:populate_hl_context(buf_id, host_window))
        assert.equals(hl.hl_context, consts.buffer.NO_CONTEXT)
        assert.equals(hl.hl_buf, consts.buffer.INVALID_BUFFER)

        buf_id = 12
        create_fake_buffer(buf_content)
        assert(hl:populate_hl_context(buf_id, host_window))
        assert.equals(hl.hl_context, buf_content)
        assert(hl:populate_hl_context(buf_id, host_window))

        stub(vim.api, "nvim_buf_is_valid").returns(false)
        assert(not hl:populate_hl_context(buf_id, host_window))
        assert.equals(hl.hl_context, consts.buffer.NO_CONTEXT)
        assert.equals(hl.hl_buf, consts.buffer.INVALID_BUFFER)
    end)


    it('updates the buf_id and win_id when populating the context', function ()
        local buf_id = 21
        local buf_content = {
            "test this content out it",
            "the lazy fox jumps over the brown log",
            "idk what else to say do you?",
        }
        stub(vim.api, "nvim_buf_is_valid").returns(true)
        local hl = highlight:new(0, "style1", "style2")
        local new_window = 1010
        hl.hl_win = -1
        hl.hl_buf = -1

        create_fake_buffer(buf_content)
        assert(hl:populate_hl_context(buf_id, new_window))
        assert.equals(hl.hl_buf, buf_id)
        assert.equals(hl.hl_win, new_window)

        vim.api.nvim_buf_is_valid:revert()
    end)

    it('returns the current buffers highlights', function ()
        local window_id = 0
        local hl = highlight:new(window_id, "matched_style", "selected_style")
        local buffer = 8
        local ret = 0
        ret = hl:get_buffer_current_hls()
        assert.equals(ret, nil)

        stub(vim.api, "nvim_buf_is_valid").returns(false)
        ret = hl:get_buffer_current_hls(buffer)
        assert.equals(ret, nil)

        hl.matches = {
            match_object:new(0, 1, 2, 3), -- line, start, end, extmark_id
            match_object:new(4, 5, 6, 7),
            match_object:new(11, 2, 3, 12),
        }

        stub(vim.api, "nvim_buf_is_valid").returns(true)
        ret = hl:get_buffer_current_hls(buffer)
        assert(utils:lists_are_equal(ret, {3, 7, 12}))

        hl.matches = {}
        ret = hl:get_buffer_current_hls(buffer)
        assert(utils:lists_are_equal(ret, {}))

        hl.matches = nil
        ret = hl:get_buffer_current_hls(buffer)
        assert(utils:lists_are_equal(ret, {}))

    end)

    it('can clear all highlights', function ()

        stub(vim.api, "nvim_buf_is_valid").returns(true)
        stub(vim.api, "nvim_buf_del_extmark").returns()
        local hl = highlight:new(0, "style1", "style2")
        hl.matches = {
            match_object:new(0, 1, 2, 3), -- line, start, end, extmark_id
            match_object:new(0, 1, 2, 12), -- line, start, end, extmark_id
            match_object:new(0, 1, 2, 5), -- line, start, end, extmark_id
        }
        local hl_buf = 1
        local win_buf = 2
        hl:clear_highlights(hl_buf, win_buf)
        assert.stub(vim.api.nvim_buf_del_extmark).was.called_with(hl_buf, hl.hl_namespace, 3)
        assert.stub(vim.api.nvim_buf_del_extmark).was.called_with(hl_buf, hl.hl_namespace, 12)
        assert.stub(vim.api.nvim_buf_del_extmark).was.called_with(hl_buf, hl.hl_namespace, 5)

        vim.api.nvim_buf_del_extmark:clear()
        vim.api.nvim_buf_del_extmark:revert()
        vim.api.nvim_buf_is_valid:revert()
    end)

    it('can set match highlighting and update it\'s extmark id', function ()
        local new_extmark = 12
        stub(vim.api, "nvim_buf_set_extmark").returns(new_extmark)
        local hl = highlight:new(0, "style1", "style2")
        local test_match = match_object:new(0, 11, 2, 3) -- line, start, end, extmark_id
        local hl_opts = { id = test_match.extmark_id, end_col = test_match.m_end, hl_group = "style2" }
        hl:set_match_highlighting(test_match, "style2")
        assert.stub(vim.api.nvim_buf_set_extmark).was.called_with(hl.hl_buf, hl.hl_namespace, test_match.row - 1, test_match.m_start, hl_opts)
        assert.equals(test_match.extmark_id, new_extmark)

        local old_extmark = 12
        new_extmark = 11
        stub(vim.api, "nvim_buf_set_extmark").returns(new_extmark)
        hl = highlight:new(0, "style1", "style2")
        hl_opts = { id = test_match.extmark_id, end_col = test_match.m_end, hl_group = "new style" }
        hl:set_match_highlighting(nil, "new style")
        assert.stub(vim.api.nvim_buf_set_extmark).was_not.called_with(hl.hl_buf, hl.hl_namespace, test_match.row - 1, test_match.m_start, hl_opts)
        assert.equals(test_match.extmark_id, old_extmark)

        new_extmark = 13

        stub(vim.api, "nvim_buf_set_extmark").returns(new_extmark)
        hl = highlight:new(0, "style1", "style2")
        hl_opts = { id = test_match.extmark_id, end_col = test_match.m_end, hl_group = "new style" }
        hl:set_match_highlighting(test_match, "new style")
        assert.stub(vim.api.nvim_buf_set_extmark).was.called_with(hl.hl_buf, hl.hl_namespace, test_match.row - 1, test_match.m_start, hl_opts)
        assert.equals(test_match.extmark_id, new_extmark)

        vim.api.nvim_buf_set_extmark:clear()
        vim.api.nvim_buf_set_extmark:revert()

    end)

    it('can clear the match count', function ()
        local test_buf = 15
        stub(vim.api, "nvim_buf_is_valid").returns(false)
        local hl = highlight:new(0, "style1", "style2")
        hl:clear_match_count(nil)
        assert.stub(vim.api.nvim_buf_del_extmark).was_not.called_with(nil, hl.hl_namespace, hl.hl_wc_ext_id)

        hl.hl_wc_ext_id = consts.highlight.NO_WORD_COUNT_EXTMARK
        hl:clear_match_count(test_buf)
        assert.stub(vim.api.nvim_buf_del_extmark).was_not.called_with(nil, hl.hl_namespace, hl.hl_wc_ext_id)

        hl.hl_wc_ext_id = 12
        hl:clear_match_count(test_buf)
        assert.stub(vim.api.nvim_buf_del_extmark).was_not.called_with(test_buf, hl.hl_namespace, hl.hl_wc_ext_id)

        stub(vim.api, "nvim_buf_is_valid").returns(true)
        hl = highlight:new(0, "style1", "style2")
        hl.hl_wc_ext_id = 12
        hl:clear_match_count(test_buf)
        assert.stub(vim.api.nvim_buf_del_extmark).was.called_with(test_buf, hl.hl_namespace, 12)
        assert.equals(consts.highlight.NO_WORD_COUNT_EXTMARK, hl.hl_wc_ext_id)
    end)

    it('properly updates match count virt text', function ()
        local test_buf = 51
        local ext_mark_id = 101
        stub(vim.api, "nvim_buf_set_extmark").returns(ext_mark_id)
        local hl = highlight:new(0, "style1", "style2")
        hl.matches = nil
        hl:update_match_count(test_buf)
        assert.stub(vim.api.nvim_buf_set_extmark).was_not.called()

        hl.matches = {}
        hl:update_match_count(test_buf)
        assert.stub(vim.api.nvim_buf_set_extmark).was_not.called()

        hl.matches = {match_object:new(0, 1, 2, 3)}
        hl.match_index = -1
        hl:update_match_count(test_buf)
        assert.stub(vim.api.nvim_buf_set_extmark).was_not.called()

        hl.matches = {
            match_object:new(0, 1, 2, 3),
        }
        hl.match_index = 12
        hl:update_match_count(test_buf)
        assert.stub(vim.api.nvim_buf_set_extmark).was_not.called()

        hl.matches = {
            match_object:new(0, 1, 2, 3),
            match_object:new(0, 1, 2, 3),
            match_object:new(0, 1, 2, 3),
            match_object:new(0, 1, 2, 3),
            match_object:new(0, 1, 2, 3),
        }
        hl.match_index = 3
        local ret = hl:update_match_count(test_buf)
        assert.stub(vim.api.nvim_buf_set_extmark).was.called()
        assert.equals(ret, "3/5")
        assert.equals(hl.hl_wc_ext_id, ext_mark_id)

        hl.matches = {
            match_object:new(0, 1, 2, 3),
            match_object:new(0, 1, 2, 3),
        }
        hl.match_index = 0
        local ret = hl:update_match_count(test_buf)
        assert.stub(vim.api.nvim_buf_set_extmark).was.called()
        assert.equals(ret, "0/2")

        hl.matches = {
            match_object:new(0, 1, 2, 3),
            match_object:new(0, 1, 2, 3),
        }
        hl.match_index = 2
        local ret = hl:update_match_count(test_buf)
        assert.stub(vim.api.nvim_buf_set_extmark).was.called()
        assert.equals(ret, "2/2")

    end)

    it('properly moves the match index to the correct number', function ()
        local window_id = 0
        stub(vim.api, "nvim_buf_is_valid").returns(false)
        stub(vim.api, "nvim_win_set_cursor").returns()
        stub(vim, "cmd").returns()
        local hl = highlight:new(window_id, "matched_style", "selected_style")
        hl.matches = {
            match_object:new(0, 1, 2, 3), -- line, start, end, extmark_id
            match_object:new(4, 5, 6, 7),
            match_object:new(11, 2, 3, 12),
            match_object:new(11, 2, 3, 12),
            match_object:new(11, 2, 3, 12),
            match_object:new(11, 2, 3, 12),
            match_object:new(11, 2, 3, 12),
        }

        hl.match_index = 1
        assert.equals(hl.match_index, 1)
        hl:move_cursor(2)
        assert.equals(hl.match_index, 2)
        hl:move_cursor(3)
        assert.equals(hl.match_index, 3)
        hl:move_cursor(5)
        assert.equals(hl.match_index, 5)
        hl:move_cursor(3)
        assert.equals(hl.match_index, 3)
        hl:move_cursor(3)
        hl:move_cursor(4)
        assert.equals(hl.match_index, 4)

        hl.match_index = 5 -- it does not update with invalid indices
        hl:move_cursor(-1)
        assert.equals(hl.match_index, 5)

        hl:move_cursor(-20)
        assert.equals(hl.match_index, 5)

        hl:move_cursor(8)
        assert.equals(hl.match_index, 5)

        hl:move_cursor(100)
        assert.equals(hl.match_index, 5)

        hl:move_cursor()
        assert.equals(hl.match_index, 5)

        vim.cmd:revert()
        vim.api.nvim_buf_is_valid:revert()
        vim.api.nvim_win_set_cursor:revert()

    end)

    it('moves the cursor and highlighting correctly given the index', function ()
        local window_id = 0
        local result_style = "matched_style"
        local selected_style = "selected_style"
        stub(vim.api, "nvim_buf_is_valid").returns(false)
        stub(vim.api, "nvim_win_set_cursor").returns()
        stub(highlight, "set_match_highlighting").returns()
        local hl = highlight:new(window_id, result_style, selected_style)
         hl.matches = {
            match_object:new(0, 1, 2, 3), -- line, start, end, extmark_id
            match_object:new(4, 5, 6, 7),
            match_object:new(11, 2, 3, 12),
         }
        -- move forward
        hl:move_cursor(2)
        local prev_match = hl.matches[1] -- starts at 1
        local curr_match = hl.matches[2]
        move_cursor_asserts(hl, prev_match, curr_match, result_style, selected_style )

        --move backward
        hl:move_cursor(1)
        prev_match = hl.matches[2]
        curr_match = hl.matches[1]
        move_cursor_asserts(hl, prev_match, curr_match, result_style, selected_style )

        --move multiple spots forward
        hl:move_cursor(3)
        prev_match = hl.matches[1]
        curr_match = hl.matches[3]
        move_cursor_asserts(hl, prev_match, curr_match, result_style, selected_style )

        --move multiple spots backward
        hl:move_cursor(1)
        prev_match = hl.matches[3]
        curr_match = hl.matches[1]
        move_cursor_asserts(hl, prev_match, curr_match, result_style, selected_style)


        hl.set_match_highlighting:revert()
        vim.api.nvim_win_set_cursor:revert()

    end)

    it('ignores invalid indices in move cursor', function ()
        local hl = create_new_highlighter()
        assert.equals(hl:move_cursor(), nil)
        assert.equals(hl:move_cursor(1), nil)
        assert.equals(hl:move_cursor(-10), nil)
        assert.equals(hl:move_cursor(0), nil)

        hl.matches = {
            match_object:new(0, 1, 2, 3), -- line, start, end, extmark_id
            match_object:new(4, 5, 6, 7),
            match_object:new(11, 2, 3, 12),
        }

        assert.equals(hl:move_cursor(4), nil)
        assert.equals(hl:move_cursor(5), nil)
        assert.equals(hl:move_cursor(10), nil)

        hl.hl_win = consts.window.INVALID_WINDOW_ID
        assert.equals(hl:move_cursor(1), nil)
        assert.equals(hl:move_cursor(2), nil)
        assert.equals(hl:move_cursor(3), nil)
    end)
    it('can find the closest match index going forward', function ()
        local hl = create_new_highlighter()

        assert.equals(hl:get_closest_match(consts.search.FORWARD), nil)
        hl.matches = {
            match_object:new(0, 1, 2, 3), -- line, start, end, extmark_id
            match_object:new(4, 5, 6, 7),
            match_object:new(7, 5, 6, 7),
            match_object:new(11, 2, 5, 12),
            match_object:new(11, 8, 14, 12),
            match_object:new(11, 17, 25, 12),
            match_object:new(11, 28, 35, 12),
            match_object:new(12, 2, 3, 12),
            match_object:new(13, 2, 3, 12),
        }

        -- moves forward when cycling
        stub(vim.api, 'nvim_win_get_cursor').returns({5, 12})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 3)

        stub(vim.api, 'nvim_win_get_cursor').returns({7, 5})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 4)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 2})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 5)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 8})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 6)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 17})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 7)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 28})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 8)

        stub(vim.api, 'nvim_win_get_cursor').returns({12, 2})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 9)

        stub(vim.api, 'nvim_win_get_cursor').returns({13, 2})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 1)

        -- anything past the last index should return last index (perhaps change to go to 1?)
        stub(vim.api, 'nvim_win_get_cursor').returns({15, 18})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 9)

        stub(vim.api, 'nvim_win_get_cursor').returns({150, 90})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 9)

        -- cursor on the same line
        stub(vim.api, 'nvim_win_get_cursor').returns({11, 7})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 5)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 8})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 6)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 16})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 6)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 18})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 7)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 27})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 7)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 29})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 8)

    end)

    it('can find the closest match index going backward', function ()
        local hl = create_new_highlighter()

        assert.equals(hl:get_closest_match(consts.search.BACKWARD), nil)
        hl.matches = {
            match_object:new(3, 1, 2, 3), -- line, start, end, extmark_id
            match_object:new(4, 5, 6, 7), --2
            match_object:new(7, 5, 6, 7), -- 3
            match_object:new(11, 2, 5, 12), -- 4
            match_object:new(11, 8, 14, 12), -- 5
            match_object:new(11, 17, 25, 12), -- 6
            match_object:new(11, 28, 35, 12), --7
            match_object:new(12, 2, 3, 12), -- 8
            match_object:new(13, 2, 3, 12), -- 9
        }

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 29})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 7)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 28})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 6)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 17})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 5)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 8})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 4)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 2})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 3)

        stub(vim.api, 'nvim_win_get_cursor').returns({7, 5})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 2)

        stub(vim.api, 'nvim_win_get_cursor').returns({4, 5})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 1)

        stub(vim.api, 'nvim_win_get_cursor').returns({3, 1})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 9)

        -- anything before the first match goes to first match (maybe switch this to go to last?)
        stub(vim.api, 'nvim_win_get_cursor').returns({2, 10})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 1)

        stub(vim.api, 'nvim_win_get_cursor').returns({2, 12})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 1)

        stub(vim.api, 'nvim_win_get_cursor').returns({1, 8})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 1)

        -- cursor on the same line
        stub(vim.api, 'nvim_win_get_cursor').returns({11, 1})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 3)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 3})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 4)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 7})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 4)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 9})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 5)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 16})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 5)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 18})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 6)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 27})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 6)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 29})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 7)
    end)

    it('wraps around matches array when finding closest match', function ()
        local hl = create_new_highlighter()

        hl.matches = {
            match_object:new(3, 1, 2, 3), -- line, start, end, extmark_id
            match_object:new(4, 5, 6, 7), --2
            match_object:new(7, 5, 6, 7), -- 3
            match_object:new(11, 2, 5, 12), -- 4
        }

        stub(vim.api, 'nvim_win_get_cursor').returns({2, 2})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 1)

        stub(vim.api, 'nvim_win_get_cursor').returns({3, 1})
        assert.equals(hl:get_closest_match(consts.search.BACKWARD), 4)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 2})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 1)


        stub(vim.api, 'nvim_win_get_cursor').returns({12, 3})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 4)

        stub(vim.api, 'nvim_win_get_cursor').returns({11, 2})
        assert.equals(hl:get_closest_match(consts.search.FORWARD), 1)
    end)

    it('adds new matches to the highlighter match table', function()
        local hl = create_new_highlighter()
        hl:highlight_pattern_in_line(1, 24, 32)
        assert(utils:compare_matches(hl.matches[1], match_object:new(2, 24, 32, 0))) -- adds 1 to line for matches

        hl:highlight_pattern_in_line(12, 20, 26)
        assert(utils:compare_matches(hl.matches[2], match_object:new(13, 20, 26, 0))) -- adds 1 to line for matches

        hl:highlight_pattern_in_line(102, 27, 3268)
        assert(utils:compare_matches(hl.matches[3], match_object:new(103, 27, 3268, 0))) -- adds 1 to line for matches
    end)

    it('handles searches with no context or nil patterns', function ()
        local hl = create_new_highlighter()
        hl:highlight_file_by_pattern(0, "test text")
        assert.equals(#hl.matches, 0)
        hl.hl_context = "test text"
        hl:highlight_file_by_pattern(0, nil)
        assert.equals(#hl.matches, 0)

        hl:highlight_file_by_pattern(0, "")
        assert.equals(#hl.matches, 0)

    end)

    it('can search for patterns in it\'s context', function ()
        local hl = create_new_highlighter()

        hl.hl_context = {
            "This is a test string we'll use to search",
            "hopefully string only shows up",
            "three times string",
        }

        local check_index = 1
        local pattern = "string"
        local cmp_match = nil
        hl:highlight_file_by_pattern(0, pattern)
        assert.equals(3, #hl.matches)
        cmp_match = string_to_matches(hl.hl_context[check_index], pattern, check_index)[1]
        assert(utils:compare_matches(hl.matches[check_index], cmp_match))

        check_index = 2
        cmp_match = string_to_matches(hl.hl_context[check_index], pattern, check_index)[1]
        assert(utils:compare_matches(hl.matches[check_index], cmp_match))

        check_index = 3
        cmp_match = string_to_matches(hl.hl_context[check_index], pattern, check_index)[1]
        assert(utils:compare_matches(hl.matches[check_index], cmp_match))

    end)

    it('properly ignores and honors case based on the setting', function ()
        local hl = create_new_highlighter()

        hl.hl_context = {
            "ErIc spidle wrote this string and ",
            "eRIc is so cool and he is",
            "eric",
            "also EriC",
        }

        local check_index = 1
        local pattern = "ERIC"
        local cmp_match = nil
        hl:highlight_file_by_pattern(0, pattern)
        hl.mode_mgr.modes[consts.modes.case_sensitive].active = false
        assert.equals(4, #hl.matches)

        cmp_match = string_to_matches(hl.hl_context[check_index], pattern, check_index, true)[1]
        assert(utils:compare_matches(hl.matches[check_index], cmp_match))

        check_index = 2
        cmp_match = string_to_matches(hl.hl_context[check_index], pattern, check_index, true)[1]
        assert(utils:compare_matches(hl.matches[check_index], cmp_match))

        check_index = 3
        cmp_match = string_to_matches(hl.hl_context[check_index], pattern, check_index, true)[1]
        assert(utils:compare_matches(hl.matches[check_index], cmp_match))

        check_index = 4
        cmp_match = string_to_matches(hl.hl_context[check_index], pattern, check_index, true)[1]
        assert(utils:compare_matches(hl.matches[check_index], cmp_match))

        hl.mode_mgr.modes[consts.modes.case_sensitive].active = true
        pattern = "eric"
        hl.matches = {}
        hl:highlight_file_by_pattern(0, pattern)
        assert.equals(1, #hl.matches)
        check_index = 1
        local match_line = 3

        cmp_match = string_to_matches(hl.hl_context[match_line], pattern, match_line)[1]
        assert(utils:compare_matches(hl.matches[check_index], cmp_match))

    end)

    it('properly searches using regexes when enabled', function ()
        local hl = create_new_highlighter()

        hl.hl_context = {
            "Test string one who knows what this will be",
            "another string to test against I wonder",
            "what exactly is it that we're looking",
            "for it could be anything really",
        }

        local check_index = 1
        local pattern = "string.*"
        local cmp_match = nil
        hl.mode_mgr.modes[consts.modes.lua_pattern].active = false
        hl:highlight_file_by_pattern(0, pattern)
        assert.equals(0, #hl.matches)


        hl.mode_mgr.modes[consts.modes.lua_pattern].active = true
        hl:highlight_file_by_pattern(0, pattern)
        assert.equals(2, #hl.matches)
        cmp_match = string_to_matches(hl.hl_context[check_index], pattern, check_index, true, true)[1]
        assert(utils:compare_matches(hl.matches[check_index], cmp_match))

        check_index = 2
        cmp_match = string_to_matches(hl.hl_context[check_index], pattern, check_index, true, true)[1]
        assert(utils:compare_matches(hl.matches[check_index], cmp_match))
    end)

    it('can handle multiple pattern matches in the same line', function ()
        -- TBD
        local hl = create_new_highlighter()

        hl.hl_context = {
            "var my_variable = old_variable;",
            "if(my_var == old_variable) then",
            "print(\"var is old var\")",
        }
        local row = 1
        local check_index = 1
        local pattern = "var"

        hl:highlight_file_by_pattern(0, pattern)
        assert.equals(#hl.matches, 7)
        local cmp_matches = string_to_matches(hl.hl_context[row], pattern, row)

        assert(utils:compare_matches(hl.matches[check_index], cmp_matches[check_index]))

        -- extmark indexing is 0 based and end inclusive so we need to add 1 to the start to what we store in the match array
        assert.equals(string.sub(hl.hl_context[row], cmp_matches[check_index].m_start + 1, cmp_matches[check_index].m_end), pattern)

        check_index = 2
        assert(utils:compare_matches(hl.matches[check_index], cmp_matches[check_index]))
        assert.equals(string.sub(hl.hl_context[row], cmp_matches[check_index].m_start + 1, cmp_matches[check_index].m_end), pattern)

        check_index = 3
        assert(utils:compare_matches(hl.matches[check_index], cmp_matches[check_index]))
        assert.equals(string.sub(hl.hl_context[row], cmp_matches[check_index].m_start + 1, cmp_matches[check_index].m_end), pattern)

        row = 2
        cmp_matches = string_to_matches(hl.hl_context[row], pattern, row)

        check_index = 1
        assert(utils:compare_matches(hl.matches[4], cmp_matches[check_index]))
        assert.equals(string.sub(hl.hl_context[row], cmp_matches[check_index].m_start + 1, cmp_matches[check_index].m_end), pattern)

        check_index = 2
        assert(utils:compare_matches(hl.matches[5], cmp_matches[check_index]))
        assert.equals(string.sub(hl.hl_context[row], cmp_matches[check_index].m_start + 1, cmp_matches[check_index].m_end), pattern)

    end)

end)

