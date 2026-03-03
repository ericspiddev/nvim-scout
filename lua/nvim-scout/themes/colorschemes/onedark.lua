local onedark_name = "onedark"
local onedark_colors = {
    dark = "#282C34",
    red = "#E06C75",
    green = "#98C379",
    yellow = "#E5C07B",
    blue = "#61AFEF",
    purple = "#C678DD",
    cyan = "#56B6C2",
    light = "#ABB2BF",
}

local onedark = {
    search_border_color = {fg = onedark_colors.blue, bg = onedark_colors.dark},
    search_title_color = {fg = onedark_colors.cyan, bg = onedark_colors.dark},
    mode_case_title_color = {fg = onedark_colors.yellow, italic = true},
    mode_case_border_color = {fg = onedark_colors.purple, bg = onedark_colors.dark},
    mode_pat_title_color = {fg = onedark_colors.green, italic = true},
    mode_pat_border_color = {fg = onedark_colors.purple, bg = onedark_colors.dark},
    mode_virt_text_color = {fg = onedark_colors.purple, bg = onedark_colors.dark},
    scout_g_search_result = {fg = onedark_colors.dark, bg = onedark_colors.light},
    scout_g_selected_result = {fg = onedark_colors.dark, bg = onedark_colors.red},
}

Scout_Colorscheme:register_colorscheme(onedark_name, onedark)
