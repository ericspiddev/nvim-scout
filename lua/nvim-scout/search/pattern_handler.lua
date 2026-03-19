scout_pattern_handler = {}
scout_pattern_handler.__index = scout_pattern_handler


function scout_pattern_handler:new(escape_chars)
    local obj = {
        escape_chars = escape_chars
    }
    return setmetatable(obj, self)
end

function scout_pattern_handler:escape_pattern_characters(pattern)
    if pattern:sub(1,2) == "%b" then -- handle case of balance modifer which needs to see () to actually match proper
        return pattern
    end
    for _, escape_char in ipairs(self.escape_chars) do
        pattern = string.gsub(pattern,"%" .. escape_char, "%%".. escape_char)
    end

    return pattern
end

return scout_pattern_handler
