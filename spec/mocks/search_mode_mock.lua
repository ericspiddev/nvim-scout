mock_search_mode = {}
mock_search_mode.__index = mock_search_mode
function mock_search_mode:new(name, symbol, namespace, text_color, border_hl)
    local obj = {
        name = name,
        symbol = symbol,
        namespace = namespace,
        text_color = text_color,
        border_hl = border_hl,
        active = false,
        display_col = 0
    }
    return setmetatable(obj, self)
end

function mock_search_mode:get_banner_display_width()
    return 5
end

function mock_search_mode:get_extra_padding()
    return 1
end

function mock_search_mode:update_banner_config(border, display_col, search_bar_window)
    return {border, display_col, search_bar_window}
end

return mock_search_mode
