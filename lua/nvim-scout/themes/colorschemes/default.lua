
local default_name = "defaults"

local default = {
    search_border_color = { link="FloatBorder", default = true },
    search_title_color = { link="FloatTitle", default = true },
    mode_case_title_color = { link="WarningMsg", default = true },
    mode_case_border_color = { link="FloatBorder", default = true },
    mode_pat_title_color = { link="MoreMsg", default = true },
    mode_pat_border_color = { link="FloatBorder", default = true },
    mode_virt_text_color = { link="FloatTitle", default = true },
    scout_g_search_result = {link="Search", default= true},
    scout_g_selected_result = {link="CurSearch", default= true}
}

Scout_Colorscheme:register_colorscheme(default_name, default)
