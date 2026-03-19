scout_events = {}

scout_events.__index = scout_events
function scout_events:new(valid_events)
    local obj = {
        valid_events = valid_events,
        event_table = {},
        event_buffer_id = Scout_Consts.buffer.INVALID_BUFFER,
    }
    return setmetatable(obj, self)
end

-------------------------------------------------------------
--- events.add_event: adds an event_handler to the passed in
--- event on the instance table if that event is supported
--- @event_name: name of the event that wants to be registered
--- @instance: instance of object we're adding an event handler to
--- @event_handler: the handler of that will be invoked on each event
---
function scout_events:add_event(event_name, instance, event_handler)

    if not self:is_valid_event(event_name) or event_handler == nil or instance == nil then
        Scout_Logger:error_print("Failed to register event ", event_name)
        if event_handler == nil then
            Scout_Logger:error_print("Nil event handler for event ", event_name)
        elseif instance == nil then
            Scout_Logger:error_print("Nil object instance")
        else
            Scout_Logger:error_print("Unsupported event supported events are ", self.valid_events)
        end
        return false
    end

    if instance[event_handler] == nil then
        Scout_Logger:error_print("Instance is missing function handler with the name ", event_handler)
        return false
    end

    self.event_table[event_name] = function(...)
        instance[event_handler](instance,...)
    end
    Scout_Logger:info_print("Registered event handler for event ", event_name)
    return true
end

function scout_events:attach_buffer_events(buffer)
    if not vim.api.nvim_buf_is_valid(buffer) then
        Scout_Logger:error_print("Cannot attach to invalid nvim buffer ", buffer)
        return false
    elseif self.event_table == nil or next(self.event_table) == nil then
        Scout_Logger:error_print("Failed to attach buffer events empty or nil event table!")
        return false
    else
        -- shockingly there is no cleanup function to this as it's handled in the clenaup
        -- of the buffer so for now no detach though that may change
        local rc = vim.api.nvim_buf_attach(buffer, true, self.event_table)
        if not rc then
            Scout_Logger:error_print("Failed to attach events to buffer ", buffer)
            return false
        end

        self.event_table = {} -- clear
        self.event_buffer_id = buffer
        Scout_Logger:info_print("Successfully attached buffer events")
        return true
    end
end

-------------------------------------------------------------
--- events.is_valid_event: determines whether the event that
--- is attempting to be registered is a supported event
--- @event_name: name of the event that wants to be registered
---
function scout_events:is_valid_event(event_name)
    if self.valid_events == nil then
        Scout_Logger:error_print("Nil valid events table no events will be allowed")
        return false
    end
    for _, name in pairs(self.valid_events) do
        if event_name == name then
            return true
        end
    end
    Scout_Logger:error_print("Unsupported event ", event_name)
    return false
end

return scout_events
