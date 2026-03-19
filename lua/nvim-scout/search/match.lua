scout_match = {}

scout_match.__index = scout_match
function scout_match:new(line, word_start, word_end, ext_mark_id)
    local obj = {
        row = line,
        m_start = word_start,
        m_end = word_end,
        extmark_id = ext_mark_id
    }
    return setmetatable(obj, self)
end

function scout_match:get_cursor_row()
    return self.row
end

function scout_match:get_highlight_row()
    return self.row - 1
end

-------------------------------------------------------------
--- match.update_extmark_id: this function is responsible for
--- updating the extmark associated with a match. This is used
--- for bookkeeping and updating the match's highlighting
--- new_id: extmark id that will be associated with the match
---
function scout_match:update_extmark_id(new_id)
    self.extmark_id = new_id
end

return scout_match

