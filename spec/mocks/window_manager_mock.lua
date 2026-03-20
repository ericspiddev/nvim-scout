mock_window_manager = {}
mock_window_manager.__index = mock_window_manager
function mock_window_manager:new()
    local obj = {
        windows = {},
        buffer_ids = 1,
        window_ids = 1000,
        extmark_ids = 500,
    }
    return setmetatable(obj, self)
end

function mock_window_manager:register_window(name, config)
    local new_window = {}
    new_window.name = name
    new_window.open = false
    new_window.config = config
    new_window.extmarks = {}
    new_window.buffer = 0
    new_window.id = 0
    new_window.host = 0
    new_window.contents = ''
    table.insert(self.windows, new_window)
end

function mock_window_manager:get_managed_window(name)
    for _, window in ipairs(self.windows) do
        if window.name == name then
            return window
        end
    end
end

function mock_window_manager:perform_window_action(name, action)
    local win = self:get_managed_window(name)
    if win then
        return action(win)
    end
end

function mock_window_manager:open_window_by_name(name, namespace)
    self:perform_window_action(name, function (window)
        if not window.open then
            local win_config = window.config
            self:cleanup_window_resources(window)
            window.buffer = self.buffer_ids
            self.buffer_ids = self.buffer_ids + 1
            if win_config.buffer.name then
                window.buffer_name = win_config.buffer_name
            end
            window.host = self.window_ids
            window.id = self.window_ids + 1
            self.window_ids = self.window_ids + 2
            if namespace then
                window.namespace = namespace
            end
            window.open = true
            window.current_win = window.id
        end
    end)
end

function mock_window_manager:toggle_window_focus(name)
    self:perform_window_action(name, function (window)
        if window.open then
            if window.current_win == window.id then
                window.current_win = window.host
            elseif window.current_win == window.host then
                window.current_win = window.id
            end
        end
    end)
end

function mock_window_manager:close_window_by_name(name)
    self:perform_window_action(name, function (window)
        if window.open then
            self:cleanup_window_resources(window)
            window.buffer = 0
            window.id = 0
            window.open = false
            window.host = 0
        end
    end)
end

function mock_window_manager:cleanup_window_resources(window)
    if window.id then
        window.id = 0
    end

    if window.buffer then
        window.buffer = 0
    end
end

function mock_window_manager:update_nvim_window_config(name, new_config)
    local window_config = self:get_window_field(name, "config")
    if window_config then
        if new_config ~= nil then
            window_config["nvim_open_win_config"] = new_config
        end
    end
end


function mock_window_manager:update_window_config(name, new_config)
    local window = self:get_managed_window(name)
    if window then
        if new_config ~= nil then
            window.config = new_config
        end
    end
end

function mock_window_manager:get_window_field(name, field, validator)
    return self:perform_window_action(name, function (window)
        if validator then
            if window[field] and validator(window[field]) then
                return window[field]
            end
        else
            return window[field]
        end
    end)
end

function mock_window_manager:is_window_open(name)
    return self:get_window_field(name, "open")
end

function mock_window_manager:get_window_buffer(name)
    return self:get_window_field(name, "buffer", vim.api.nvim_buf_is_valid)
end

function mock_window_manager:get_window_buf_contents(name)
    return self:perform_window_action(name, function (window)
        return window.contents
    end)
end

function mock_window_manager:get_window_buf_line(name, line)
    local contents = self:get_window_buf_contents(name)
    if contents then
        return contents
    end
end

function mock_window_manager:set_window_buf_contents(name, new_contents)
    if not new_contents then
        return
    end

    self:perform_window_action(name, function (window)
        window.contents = new_contents
    end)

end

function mock_window_manager:set_window_extmarks(name, line_start, line_end, opts, extmark_id)
    self:perform_window_action(name, function (window)
        window.extmarks[extmark_id] = self.extmark_ids
        self.extmark_ids = self.extmark_ids + 1
    end)
end

function mock_window_manager:get_window_extmark(name, extmark_id)
    self:perform_window_action(name, function (window)
        return window.extmarks[extmark_id]
    end)
end

function mock_window_manager:clear_window_extmark_by_id(name, extmark_id)
    self:perform_window_action(name, function (window)
        if window.buffer and window.namespace and window.extmarks[extmark_id] then
            vim.api.nvim_buf_del_extmark(window.buffer, window.namespace, window.extmarks[extmark_id])
            window.extmarks[extmark_id] = nil
        end
    end)
end

return mock_window_manager
