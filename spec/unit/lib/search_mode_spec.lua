local mode = require("nvim-scout.lib.search_mode")
local stub = require("luassert.stub")
local consts = require("nvim-scout.lib.consts")
local utils = require("spec.spec_utils")
local logger = require("nvim-scout.lib.scout_logger")
utils:register_global_logger()
describe('search mode', function ()

    before_each(function ()
        stub(vim.api, "nvim_set_hl").returns(0)
    end)

    after_each(function ()
        vim.api.nvim_set_hl:revert()
    end)

    it('adds the padding space onto it\'s display width', function ()
        local m = mode:new("Eric Mode", "E", 0, "Red")
        assert.equals(m:get_banner_display_width(), #m.name + consts.modes.padding_space)
        m = mode:new("Much longer name of string", "m", 0, "blue")
        assert.equals(m:get_banner_display_width(), #m.name + consts.modes.padding_space)
        m = mode:new("whoknows what this mode is", "w", 0, "green")
        assert.equals(m:get_banner_display_width(), #m.name + consts.modes.padding_space)
    end)

    it('adds a highlight with the passed in color and name and error prints on nil args', function ()
        utils:mock_logger_prints()
        local namespace_id = 0
        local color = "Orange"
        local name = "Eric Mode"
        local m = mode:new(name, "E", namespace_id, color)
        assert.stub(vim.api.nvim_set_hl).was.called_with(namespace_id, m.hl_name, {fg = color, force = true, italic = true})

        namespace_id = nil
        color = "Orange"
        name = "Eric Mode"
        m = mode:new(name, "E", namespace_id, color)
        assert.stub(vim.api.nvim_set_hl).was_not.called_with(namespace_id, m.hl_name, {fg = color, force = true, italic = true})
        utils:scout_print_was_called(logger.LOG_LEVELS.ERROR, "Nil argument passed to create_mode_highlight unable to for mode: ", m.hl_name)

        namespace_id = 0
        color = nil
        name = "Eric Mode"
        m = mode:new(name, "E", namespace_id, color)
        assert.stub(vim.api.nvim_set_hl).was_not.called_with(namespace_id, m.hl_name, {fg = color, force = true})
        utils:scout_print_was_called(logger.LOG_LEVELS.ERROR, "Nil argument passed to create_mode_highlight unable to for mode: ", m.hl_name)

        namespace_id = 0
        color = "orange"
        name = nil
        m = mode:new(name, "E", namespace_id, color)
        assert.stub(vim.api.nvim_set_hl).was_not.called_with(namespace_id, m.hl_name, {fg = color, force = true})
        utils:scout_print_was_called(logger.LOG_LEVELS.ERROR, "Nil argument passed to create_mode_highlight unable to for mode: ", '')

        utils:revert_logger_prints()
    end)

    it('Does not show a banner if the mode variables have invalid IDs', function ()
        local namespace_id = 0
        local color = "Orange"
        local name = "Eric Mode"
        local m = mode:new(name, "E", namespace_id, color)
        assert.equals(m:show_banner(0), false)

        m.banner_window_id = 5 -- emulate an open banner already
        m.search_bar_win = 4
        assert.equals(m:show_banner(0), false)
    end)

    it('Shows a banner if it has a ref window and one is not open', function ()
        local namespace_id = 0
        local color = "Orange"
        local name = "Eric Mode"
        local m = mode:new(name, "E", namespace_id, color)
        m.search_bar_win = 1
        stub(vim.api, "nvim_create_buf").returns(10)
        stub(vim.api, "nvim_open_win").returns(1010)
        stub(vim.api, "nvim_win_set_hl_ns").returns()
        stub(vim.api, "nvim_buf_set_lines").returns()
        stub(vim.api, "nvim_buf_set_extmark").returns()

        assert(m:show_banner(314), true)
        assert.equals(m.display_col, 314)
        assert.equals(m.banner_buf, 10)
        assert.equals(m.banner_window_id, 1010)
    end)

    it('only tries to hide a banner when one is open', function ()
        local namespace_id = 0
        local color = "Orange"
        local name = "Eric Mode"
        local m = mode:new(name, "E", namespace_id, color)
        assert.equals(m:hide_banner(), false)

        m.banner_window_id = 4
        m.banner_buf = 5
        stub(vim.api, "nvim_win_close").returns()
        stub(vim.api, "nvim_buf_delete").returns()

        assert.equals(m:hide_banner(), true)
        assert.equals(m.banner_window_id, consts.window.INVALID_WINDOW_ID)
        assert.equals(m.banner_buf, consts.buffer.INVALID_BUFFER)

        vim.api.nvim_win_close:revert()
        vim.api.nvim_buf_delete:revert()
    end)

end)
