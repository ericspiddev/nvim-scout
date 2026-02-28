local mode_manager = require("nvim-scout.lib.mode_manager")
local search_mode = require("nvim-scout.lib.search_mode")
local utils = require("spec.spec_utils")
local consts = require("nvim-scout.lib.consts")
local stub = require("luassert.stub")
utils:register_global_logger()

function create_mode_manager(extra_modes)
    local m
    local curr_modes = utils:get_supported_modes()
    if extra_modes then
        table.move(extra_modes, 1, #extra_modes, #curr_modes + 1, curr_modes)
    end
    m = mode_manager:new(curr_modes)
    return m
end

function stub_banners()
    stub(search_mode, "hide_banner").returns()
    stub(search_mode, "show_banner").returns()
end

function revert_banners()
    search_mode.hide_banner:revert()
    search_mode.show_banner:revert()
end

function mock_nvim_api_for_banners()
    stub(vim.api, "nvim_win_is_valid").returns(true)
    stub(vim.api, "nvim_create_buf").returns(1)
    stub(vim.api, "nvim_open_win").returns(1000)
    stub(vim.api, "nvim_win_set_hl_ns").returns()
    stub(vim.api, "nvim_buf_set_lines").returns()
    stub(vim.api, "nvim_buf_set_extmark").returns()
    stub(vim.api, "nvim_win_close").returns()
    stub(vim.api, "nvim_buf_delete").returns()
end

function revert_nvim_api_for_banners()
    vim.api.nvim_win_is_valid:revert()
    vim.api.nvim_create_buf:revert()
    vim.api.nvim_open_win:revert()
    vim.api.nvim_win_set_hl_ns:revert()
    vim.api.nvim_buf_set_lines:revert()
    vim.api.nvim_buf_set_extmark:revert()
    vim.api.nvim_win_close:revert()
    vim.api.nvim_buf_delete:revert()
end

local REGEX_MODE = consts.modes.lua_pattern
local MATCH_CASE_MODE = consts.modes.case_sensitive
describe('Mode manager', function ()

    it('can determine if a mode is valid or not', function ()
        local manager = create_mode_manager()
        assert(manager:validate_mode(REGEX_MODE))
        assert(manager:validate_mode(MATCH_CASE_MODE))
        assert.equals(manager:validate_mode("TEST_MODE"), false)
        assert.equals(manager:validate_mode("FAKSE_MODE"), false)
        assert.equals(manager:validate_mode(), false)
        assert.equals(manager:validate_mode({ obj = 1}), false)
        assert.equals(manager:validate_mode(function() end), false)
    end)

    it('can get a mode\'s status', function()
        local manager = create_mode_manager()
        assert.equals(manager:get_mode_status(MATCH_CASE_MODE), false)
        assert.equals(manager:get_mode_status(REGEX_MODE), false)
        manager.modes[MATCH_CASE_MODE].active = true
        manager.modes[REGEX_MODE].active = true
        assert.equals(manager:get_mode_status(MATCH_CASE_MODE), true)
        assert.equals(manager:get_mode_status(REGEX_MODE), true)
    end)

    it('can set a mode\'s status', function ()
        local manager = create_mode_manager()
        assert.equals(manager:get_mode_status(MATCH_CASE_MODE), false)
        assert.equals(manager:get_mode_status(REGEX_MODE), false)
        manager:set_mode(MATCH_CASE_MODE, true)
        manager:set_mode(REGEX_MODE, true)
        assert.equals(manager:get_mode_status(MATCH_CASE_MODE), true)
        assert.equals(manager:get_mode_status(REGEX_MODE), true)

        manager:set_mode(MATCH_CASE_MODE, true)
        manager:set_mode(REGEX_MODE, true)
        assert.equals(manager:get_mode_status(MATCH_CASE_MODE), true)
        assert.equals(manager:get_mode_status(REGEX_MODE), true)

        manager:set_mode(MATCH_CASE_MODE, false)
        assert.equals(manager:get_mode_status(MATCH_CASE_MODE), false)
        assert.equals(manager:get_mode_status(REGEX_MODE), true)
    end)

    it('successfully toggles modes', function ()
        local manager = create_mode_manager()
        stub_banners()

        assert.equals(manager:get_mode_status(MATCH_CASE_MODE), false)
        assert.equals(manager:get_mode_status(REGEX_MODE), false)
        manager:toggle_mode(REGEX_MODE)
        assert.equals(manager:get_mode_status(REGEX_MODE), true)
        assert.equals(manager:get_mode_status(MATCH_CASE_MODE), false)

        manager:toggle_mode(MATCH_CASE_MODE)
        assert.equals(manager:get_mode_status(MATCH_CASE_MODE), true)

        manager:toggle_mode(REGEX_MODE)
        manager:toggle_mode(MATCH_CASE_MODE)
        assert.equals(manager:get_mode_status(REGEX_MODE), false)
        assert.equals(manager:get_mode_status(MATCH_CASE_MODE), false)

        revert_banners()
    end)

    it('updates all modes with the relevant window id when a valid window is presented', function ()
        stub(vim.api, "nvim_win_is_valid").returns(true)
        local manager = create_mode_manager()
        manager:update_relative_window(1010)
        for _, mode in pairs(manager.modes) do
            assert.equals(mode.search_bar_win, 1010)
        end
        manager:update_relative_window(314)
        for _, mode in pairs(manager.modes) do
            assert.equals(mode.search_bar_win, 314)
        end
        vim.api.nvim_win_is_valid:revert()
    end)

    it('sets search_bar_win to an invalid window when it is given one', function ()
        local manager = create_mode_manager()
        manager:update_relative_window(1010)
        for _, mode in pairs(manager.modes) do
            assert.equals(mode.search_bar_win, consts.window.INVALID_WINDOW_ID)
        end
        manager:update_relative_window(314)
        for _, mode in pairs(manager.modes) do
            assert.equals(mode.search_bar_win, consts.window.INVALID_WINDOW_ID)
        end
    end)

    it('closes all modes when it should and resets next display column', function ()
        local manager = create_mode_manager()
        manager:toggle_mode(REGEX_MODE)
        manager:toggle_mode(MATCH_CASE_MODE)
        manager.next_banner_col = 210
        assert(manager:get_mode_status(MATCH_CASE_MODE))
        assert(manager:get_mode_status(REGEX_MODE))
        assert(manager.next_banner_col, 210)
        manager:close_all_modes()
        assert.equals(manager:get_mode_status(MATCH_CASE_MODE), false)
        assert.equals(manager:get_mode_status(REGEX_MODE), false)
        assert.equals(manager.next_banner_col, 0)
    end)

    it('applies regex mode properly', function ()
        -- just a boolean we pass to `string.find` telling it to use pattern matching or not
        local manager = create_mode_manager()
        assert(manager:apply_lua_pattern_mode())
        manager:toggle_mode(REGEX_MODE)
        assert.equals(manager:apply_lua_pattern_mode(), false)
    end)

    it('applies match case mode properly', function ()
        local manager = create_mode_manager()
        manager:set_mode(MATCH_CASE_MODE, false)
        local line, pattern = manager:apply_match_case("SenCnsE2", "SEN")
        assert.equals(line, "sencnse2")
        assert.equals(pattern, "sen")
        manager:toggle_mode(MATCH_CASE_MODE)

        line, pattern = manager:apply_match_case("SenCnsE2", "SEN")
        assert.equals(line, "SenCnsE2")
        assert.equals(pattern, "SEN")
    end)

    it('properly calculates where to place the next mode window', function ()

        mock_nvim_api_for_banners()
        local manager = create_mode_manager()
        assert.equals(manager.next_banner_col, 0)

        manager:update_relative_window(10)
        manager:toggle_mode(REGEX_MODE)
        assert.equals(manager.next_banner_col, manager.modes[REGEX_MODE]:get_banner_display_width() + consts.modes.banner_gap)
        local curr_col = manager.next_banner_col

        manager:toggle_mode(MATCH_CASE_MODE)
        assert.equals(manager.next_banner_col, curr_col + manager.modes[MATCH_CASE_MODE]:get_banner_display_width() + consts.modes.banner_gap)
        curr_col = manager.next_banner_col

        manager:toggle_mode(REGEX_MODE)
        assert.equals(manager.next_banner_col, 0)

        manager:toggle_mode(MATCH_CASE_MODE)
        assert.equals(manager.next_banner_col, 0)

        manager:toggle_mode(MATCH_CASE_MODE)
        manager:toggle_mode(REGEX_MODE)
        assert.equals(manager.next_banner_col, curr_col)

        manager:toggle_mode(REGEX_MODE)
        assert.equals(manager.next_banner_col, manager.modes[MATCH_CASE_MODE]:get_banner_display_width() + consts.modes.banner_gap)
        revert_nvim_api_for_banners()

    end)

    it('only adjusts the next_banner_col when an operation is successful', function ()
        mock_nvim_api_for_banners()
        local manager = create_mode_manager()
        assert.equals(manager.next_banner_col, 0)

        manager:toggle_mode(REGEX_MODE)
        assert.equals(manager.next_banner_col, 0)
        manager:toggle_mode(MATCH_CASE_MODE)
        assert.equals(manager.next_banner_col, 0)
    end)

end)
