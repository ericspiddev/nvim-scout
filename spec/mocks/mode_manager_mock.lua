mock_mode_manager = {}
mock_mode_manager.__index = mock_mode_manager
function mock_mode_manager:new()
    local obj = {
        match_case = false,
        lua_pattern =false,
    }

    return setmetatable(obj, self)
end


function mock_mode_manager:apply_lua_pattern_mode()
    return not self.lua_pattern
end

function mock_mode_manager:apply_modes_to_search_text(line, pattern)
    if not self.match_case then
        line = string.lower(line)
        pattern = string.lower(pattern)
    end
    return line, pattern
end

return mock_mode_manager
