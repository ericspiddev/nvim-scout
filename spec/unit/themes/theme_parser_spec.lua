local utils = require("spec.spec_utils")
utils:register_global_consts()
utils:register_global_logger()
utils:register_global_colorscheme()
local theme_parser = require("nvim-scout.themes.theme_parser")
local theme_config = require("nvim-scout.config.config").defaults.theme
local border_types = require('nvim-scout.config.config_options').border_types

function get_border_ascii(border)
    local ascii = {}
    for _, pieces in pairs(border) do
        table.insert(ascii, pieces[1])
    end
    return ascii
end

function get_border_style(border)
    local style = {}
    for _, pieces in pairs(border) do
        table.insert(style, pieces[2])
    end
    return style
end
describe("Theme Parser", function ()
    it('returns the proper border pieces based on the config', function ()
        local tp = theme_parser:new(theme_config)

        tp.border_type = border_types.ROUNDED
        local pieces = get_border_ascii(tp:get_window_border("searchbar"))
        assert.same(pieces, Scout_Consts.borders.rounded) -- rounded defaults

        tp.border_type = border_types.MINIMAL
        pieces = get_border_ascii(tp:get_window_border("searchbar"))
        assert.same(pieces, Scout_Consts.borders.minimal)

        tp.border_type = border_types.ASCII
        pieces = get_border_ascii(tp:get_window_border("searchbar"))
        assert.same(pieces, Scout_Consts.borders.ascii)

        tp.border_type = border_types.SINGLE_BAR
        pieces = get_border_ascii(tp:get_window_border("searchbar"))
        assert.same(pieces, Scout_Consts.borders.single)

        tp.border_type = border_types.DOUBLE_BAR
        pieces = get_border_ascii(tp:get_window_border("searchbar"))
        assert.same(pieces, Scout_Consts.borders.double)

        tp.border_type = border_types.THICK
        pieces = get_border_ascii(tp:get_window_border("searchbar"))
        assert.same(pieces, Scout_Consts.borders.thick)
    end)

    it('returns the proper hl group based on the window name', function ()
        local tp = theme_parser:new(theme_config)
        local styles = get_border_style(tp:get_window_border("searchbar"))
        for _, hl_group in ipairs(styles) do
            assert.equals(hl_group, Scout_Consts.colorscheme_groups.s_border_c)
        end

        styles = get_border_style(tp:get_window_border("Match Case"))
        for _, hl_group in ipairs(styles) do
            assert.equals(hl_group, Scout_Consts.colorscheme_groups.m_case_border_c)
        end

        styles = get_border_style(tp:get_window_border("Lua Pattern"))
        for _, hl_group in ipairs(styles) do
            assert.equals(hl_group, Scout_Consts.colorscheme_groups.m_pat_border_c)
        end
    end)

    it('registers the correct colorscheme based on the theme if it\'s valid', function ()
        local old_req = require
        local required_module = ""
        local fails = false
        require = function(module)
            if fails and not module:find(Scout_Consts.search.default_scheme) then
                error("Intentional failure!")
            end
            required_module = module
        end
        theme_parser:new(theme_config)
        assert(string.find(required_module, Scout_Consts.search.default_scheme))

        theme_config.colorscheme = "onedark"
        theme_parser:new(theme_config)
        assert(string.find(required_module, "onedark"))

        fails = true
        theme_config.colorscheme = "faketheme" -- fake theme for failure
        theme_parser:new(theme_config)
        assert(not string.find(required_module, "faketheme"))
        assert(string.find(required_module, Scout_Consts.search.default_scheme))
        require = old_req
    end)

    it('returns the proper search text with the highlight group', function ()
        local tp = theme_parser:new(theme_config)
        local sb_title = tp:get_searchbar_title()[1]
        assert(sb_title[1], Scout_Consts.search.search_top_text)
        assert(sb_title[2], Scout_Consts.colorscheme_groups.s_title_c)
    end)
end)
