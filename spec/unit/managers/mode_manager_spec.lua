local utils = require("spec.spec_utils")
utils:register_global_logger()
utils:register_global_consts()
local mode_manager = require("nvim-scout.managers.mode_manager")
local mock_search_mode = require("spec.mocks.search_mode_mock")
local mock_window_manager = require("spec.mocks.window_manager_mock")
local mock_theme_parser = require("spec.mocks.theme_parser_mock")
local consts = require("nvim-scout.utils.consts")
local stub = require("luassert.stub")


function create_mode_manager()
    local curr_modes = utils:get_supported_modes()
    local search_id = "search"
    local window_manager = mock_window_manager:new()
    window_manager:register_window(search_id, {})
    local m = mode_manager:new(0, window_manager, mock_theme_parser, search_id, mock_search_mode)
    for _, mode in pairs(curr_modes) do
        m:register_search_mode(mode)
    end
    return m
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
        --stub_banners()

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

        local manager = create_mode_manager()
        assert.equals(manager.next_banner_col, 0)

        manager:update_relative_window(10)
        manager:toggle_mode(REGEX_MODE)
        local mode = manager.modes[REGEX_MODE]
        assert.equals(manager.next_banner_col, mode:get_banner_display_width() + mode:get_extra_padding())
        local curr_col = manager.next_banner_col

        manager:toggle_mode(MATCH_CASE_MODE)
        mode = manager.modes[MATCH_CASE_MODE]
        assert.equals(manager.next_banner_col, curr_col + mode:get_banner_display_width() + mode:get_extra_padding())
        curr_col = manager.next_banner_col

        manager:toggle_mode(REGEX_MODE)
        assert.equals(manager.next_banner_col, 0)

        manager:toggle_mode(MATCH_CASE_MODE)
        assert.equals(manager.next_banner_col, 0)

        manager:toggle_mode(MATCH_CASE_MODE)
        manager:toggle_mode(REGEX_MODE)
        assert.equals(manager.next_banner_col, curr_col)

        manager:toggle_mode(REGEX_MODE)
        mode = manager.modes[REGEX_MODE]
        assert.equals(manager.next_banner_col, 0)

    end)

    it('only adjusts the next_banner_col when an operation is successful', function ()
        local manager = create_mode_manager()
        assert.equals(manager.next_banner_col, 0)

        manager:toggle_mode("Does not exist")
        assert.equals(manager.next_banner_col, 0)
        manager:toggle_mode("Fake mode")
        assert.equals(manager.next_banner_col, 0)
    end)

end)
