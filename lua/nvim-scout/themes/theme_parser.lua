local border_types = require('nvim-scout.config.config_options').border_types
local colorscheme_groups = Scout_Consts.colorscheme_groups
scout_theme_parser = {}
scout_theme_parser.__index = scout_theme_parser

function scout_theme_parser:new(theme_config)
    setup_theme_colorscheme(theme_config.colorscheme)
    local obj = {
        border_type = theme_config.border_type,
    }
    return setmetatable(obj, self)
end

function setup_theme_colorscheme(theme_colorscheme)
    local colorscheme_dir = "nvim-scout.themes.colorschemes"
    local custom_scheme_path = colorscheme_dir .. "." .. theme_colorscheme

    require(colorscheme_dir .. "." .. Scout_Consts.search.default_scheme)

    if theme_colorscheme ~= Scout_Consts.search.default_scheme then
        local success = pcall(require, custom_scheme_path)
        if not success then
            Scout_Logger:error_print("Missing colorscheme named " .. theme_colorscheme .. " will use default")
        end
    end
end

function scout_theme_parser:get_window_border(name)
    local border = nil
    if self.border_type == border_types.DOUBLE_BAR then
        border = Scout_Consts.borders.double
    elseif self.border_type == border_types.SINGLE_BAR then
        border = Scout_Consts.borders.single
    elseif self.border_type == border_types.ROUNDED then
        border = Scout_Consts.borders.rounded
    elseif self.border_type == border_types.THICK then
        border = Scout_Consts.borders.thick
    elseif self.border_type == border_types.ASCII then
        border = Scout_Consts.borders.ascii
    elseif self.border_type == border_types.MINIMAL then
        border = Scout_Consts.borders.minimal
    else
        Scout_Logger:error_print("Invalid border type for scout windows", self.border_type)
        return nil
    end
    return self:apply_colorscheme(border, name)
end

function scout_theme_parser:apply_colorscheme(border, name)
    local border_colors = {}
    for _, piece in ipairs(border) do
        if name == "searchbar" then
            table.insert(border_colors, {piece, colorscheme_groups.s_border_c})
        elseif name == "Match Case" then
            table.insert(border_colors, {piece, colorscheme_groups.m_case_border_c})
        elseif name == "Lua Pattern" then
            table.insert(border_colors, {piece, colorscheme_groups.m_pat_border_c})
        end
    end

    return border_colors
end

function scout_theme_parser:get_searchbar_title()
    return {{Scout_Consts.search.search_top_text, colorscheme_groups.s_title_c}}
end

return scout_theme_parser
