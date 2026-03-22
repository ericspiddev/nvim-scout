local utils = require("spec.spec_utils")
utils:register_global_consts()
utils:register_global_logger()
local colorscheme = require('nvim-scout.themes.colorscheme')
local stub = require('luassert.stub')
local match = require('luassert.match')

function cs_mocks()
    stub(vim.api, "nvim_set_hl")
end

function revert_cs_mocks()
    vim.api.nvim_set_hl:revert()
end

function make_colorscheme(fake_namespace)
    return colorscheme:init(fake_namespace)
end

local example_colors = {
    dark = "#000000",
    red = "#FF0000",
    green = "#00FF00",
    yellow = "#FFFF00",
    blue = "#0000FF",
    purple = "#FF00FF",
    cyan = "#00FFFF",
    light = "#FFFFFF",
}

local example_scheme = {
    search_border_color = {fg = example_colors.blue, bg = example_colors.dark},
    search_title_color = {fg = example_colors.cyan, bg = example_colors.dark},
    mode_case_title_color = {fg = example_colors.yellow, italic = true},
    mode_case_border_color = {fg = example_colors.purple, bg = example_colors.dark},
    mode_pat_title_color = {fg = example_colors.green, italic = true},
    mode_pat_border_color = {fg = example_colors.purple, bg = example_colors.dark},
    mode_virt_text_color = {fg = example_colors.purple, bg = example_colors.dark},
    scout_g_search_result = {fg = example_colors.dark, bg = example_colors.light},
    scout_g_selected_result = {fg = example_colors.dark, bg = example_colors.red},
}
local missing_key = {
    search_border_color = {fg = example_colors.blue, bg = example_colors.dark},
    search_title_color = {fg = example_colors.cyan, bg = example_colors.dark},
    mode_case_title_color = {fg = example_colors.yellow, italic = true},
    mode_pat_title_color = {fg = example_colors.green, italic = true},
    mode_pat_border_color = {fg = example_colors.purple, bg = example_colors.dark},
    mode_virt_text_color = {fg = example_colors.purple, bg = example_colors.dark},
    scout_g_search_result = {fg = example_colors.dark, bg = example_colors.light},
    scout_g_selected_result = {fg = example_colors.dark, bg = example_colors.red},
}

function check_colorscheme_registration(scheme, ns_id)
    local global_mark = "scout_g"
    for hl_group, hl in pairs(scheme) do
        if hl_group:find(global_mark) then
            assert.stub(vim.api.nvim_set_hl).was_called_with(0, hl_group, hl)
        else
            assert.stub(vim.api.nvim_set_hl).was_called_with(ns_id, hl_group, hl)
        end
    end
end

describe('Colorscheme', function ()

    before_each(function ()
       cs_mocks()
    end)

    after_each(function ()
        revert_cs_mocks()
    end)

    it('can register colorschemes', function ()
        local ns_id = 12
        local cs = make_colorscheme(ns_id)
        local name = "example"
        cs:register_colorscheme(name, example_scheme)
        assert.stub(vim.api.nvim_set_hl).was_called(9)
        check_colorscheme_registration(example_scheme, ns_id)
    end)

    it('warns on a missing key for colorschemes', function ()
        local ns_id = 50
        stub(Scout_Logger, "warning_print")
        local cs = make_colorscheme(ns_id)
        local name = "missing_key"
        cs:register_colorscheme(name, missing_key)
        assert.stub(Scout_Logger.warning_print).was_called_with(match.is_table(), "Missing key mode_case_border_color for colorscheme ", name) -- account for self since we can't use table:func in stub
        check_colorscheme_registration(missing_key, ns_id)
        Scout_Logger.warning_print:revert()
    end)

    it('errors out if no namespace is set for colorscheme', function ()
        local ns_id = 12
        stub(Scout_Logger, "error_print")
        local cs = make_colorscheme(ns_id)
        cs.namespace = nil
        local name = "no_ns"
        cs:register_colorscheme(name, missing_key)
        assert.stub(Scout_Logger.error_print).was_called_with(match.is_table(), "Failed to register colorscheme because of nil namespace ", name) -- account for self since we can't use table:func in stub
        assert.stub(vim.api.nvim_set_hl).was_not.called()
        Scout_Logger.error_print:revert()
    end)
end)
