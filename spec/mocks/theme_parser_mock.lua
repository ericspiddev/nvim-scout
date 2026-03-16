mock_theme_parser = {}
mock_theme_parser.__index = mock_theme_parser

function mock_theme_parser:get_window_border(banner_window_id)
    return {"new border"}
end


function mock_theme_parser:get_searchbar_title(banner_window_id)
    return "Scout"
end

return mock_theme_parser
