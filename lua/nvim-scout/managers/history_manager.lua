scout_history = {}

scout_history.__index = scout_history
function scout_history:new(max)
    local obj = {
        history_index = 1, -- one for bookmarking
        viewing_index = 0, -- one for retrieving data
        max_entries = max,
        entries = {},
    }
    return setmetatable(obj, self)
end

function scout_history:add_entry(search)
    if #self.entries > 0 and self.entries[#self.entries] == search then
        return
    end
    if search ~= nil and type(search) == 'string' then -- we only add strings to history list
        self.entries[self.history_index] = search
        update_history_index(self) -- handle updating of index
    end
end

function scout_history:is_empty()
    return #self.entries == 0
end

function update_history_index(self)
    if self.history_index == self.max_entries then
        self.history_index = 1
    else
        self.history_index = self.history_index + 1
    end
end

function scout_history:get_next_entry()
    if self.viewing_index == #self.entries then
        self.viewing_index = 1
    else
        self.viewing_index = self.viewing_index + 1
    end

    return self:get_entry(self.viewing_index)
end

function scout_history:get_previous_entry()
    if self.viewing_index <= 1 then
        self.viewing_index = #self.entries  -- set to newest entry in the table
    else
        self.viewing_index = self.viewing_index - 1
    end

    return self:get_entry(self.viewing_index)
end

function scout_history:get_entry(index)
    if index and index <= #self.entries and index > 0 then
        return self.entries[index]
    end
    return nil
end

return scout_history
