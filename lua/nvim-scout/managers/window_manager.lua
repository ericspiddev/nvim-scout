scout_window_manager = {}
scout_window_manager.__index = scout_window_manager


function scout_window_manager:new()
    local obj = {
        windows = {},
    }
    return setmetatable(obj, self)
end

function scout_window_manager:register_window(name, config)
    local new_window = {}
    new_window.name = name
    new_window.open = false
    new_window.config = config
    new_window.buffer = Scout_Consts.buffer.INVALID_BUFFER
    new_window.id = Scout_Consts.window.INVALID_WINDOW_ID
    new_window.extmarks = {}
    table.insert(self.windows, new_window)
end

function scout_window_manager:get_managed_window(name)
    for _, window in ipairs(self.windows) do
        if window.name == name then
            return window
        end
    end
end

function scout_window_manager:perform_window_action(name, action)
    local win = self:get_managed_window(name)
    if win then
        return action(win)
    end
end

function scout_window_manager:open_window_by_name(name, namespace)
    self:perform_window_action(name, function (window)
        if not window.open then
            local win_config = window.config

            self:cleanup_window_resources(window)
            window.buffer = vim.api.nvim_create_buf(win_config.buffer.list_buf, win_config.buffer.scratch_buf)
            if win_config.buffer.name then
                vim.api.nvim_buf_set_name(window.buffer, win_config.buffer.name)
            end
            window.host = vim.api.nvim_get_current_win()
            window.id = vim.api.nvim_open_win(window.buffer, win_config.focus_window, win_config.nvim_open_win_config)

            if vim.api.nvim_win_is_valid(window.id) then
                if namespace then
                    vim.api.nvim_win_set_hl_ns(window.id, namespace)
                    window.namespace = namespace
                end
                window.open = true
            end
        end
    end)
end

function scout_window_manager:toggle_window_focus(name)
    self:perform_window_action(name, function (window)
        if window.open then
            local focus_window_id = 0
            local current_win = vim.api.nvim_get_current_win()
            if current_win == window.id then
                focus_window_id = window.host
            elseif current_win == window.host then
                focus_window_id = window.id
            end
            if vim.api.nvim_win_is_valid(focus_window_id) then
                vim.api.nvim_set_current_win(focus_window_id)
            end
        end
    end)
end

function scout_window_manager:close_window_by_name(name)
    self:perform_window_action(name, function (window)
        if window.open then
            self:cleanup_window_resources(window)
            window.buffer = Scout_Consts.buffer.INVALID_BUFFER
            window.id = Scout_Consts.window.INVALID_WINDOW_ID
            window.open = false
        end
    end)
end

function scout_window_manager:cleanup_window_resources(window)
    if window.id and vim.api.nvim_win_is_valid(window.id) then
        vim.api.nvim_win_close(window.id, false)
    end

    if window.buffer and vim.api.nvim_buf_is_valid(window.buffer) then
        vim.api.nvim_buf_delete(window.buffer, {force = true}) -- buffer must be deleted after window otherwise window_close gives bad id
    end
end

function scout_window_manager:update_nvim_window_config(name, new_config)
    local window_config = self:get_window_field(name, "config")
    if window_config then
        if new_config ~= nil then
            window_config["nvim_open_win_config"] = new_config
        end
    end
end


function scout_window_manager:update_window_config(name, new_config)
    local window = self:get_managed_window(name)
    if window then
        if new_config ~= nil then
            window.config = new_config
        end

        if window.open then
            vim.api.nvim_win_set_config(window.id, window.config.nvim_open_win_config)
        end
    end
end

function scout_window_manager:get_window_field(name, field, validator)
    return self:perform_window_action(name, function (window)
        if validator then
            if window[field] and validator(window[field]) then
                return window[field]
            else
                Scout_Logger:warning_print("Get field failed passed in validator for field: ", field) -- FIXME AUTOCMDS ARE NOT A FAN OF PRINTING
            end
        else
            return window[field]
        end
    end)
end

function scout_window_manager:set_window_field(name, field, value, validator)
    return self:get_window_field(name, "conf")
end

function scout_window_manager:is_window_open(name)
    return self:get_window_field(name, "open")
end

function scout_window_manager:get_window_buffer(name)
    return self:get_window_field(name, "buffer", vim.api.nvim_buf_is_valid)
end

function scout_window_manager:get_window_host(name)
    return self:get_window_field(name, "host", function(host) return host and vim.api.nvim_win_is_valid(host) end)
end

function scout_window_manager:update_window_host(name, new_host)
    return self:set_window_field(name, "host", new_host, vim.api.nvim_win_is_valid)
end

function scout_window_manager:get_window_buf_contents(name)
    local buffer = self:get_window_buffer(name)
    if buffer then
        return vim.api.nvim_buf_get_lines(buffer, Scout_Consts.lines.START, Scout_Consts.lines.END, false) -- let it clamp?
    end
end

function scout_window_manager:get_window_buf_line(name, line)
    local lines = self:get_window_buf_contents(name)
    if lines and #lines >= line then
        return lines[line]
    end
end

function scout_window_manager:set_window_buf_contents(name, new_contents)
    if not new_contents then
        return
    end

    local buffer = self:get_window_buffer(name)
    if buffer then
        vim.api.nvim_buf_set_lines(buffer, Scout_Consts.lines.START, Scout_Consts.lines.END,
                            true, {new_contents})
    end
end

function scout_window_manager:set_window_extmarks(name, line_start, line_end, opts, extmark_id)
    self:perform_window_action(name, function (window)
        if window.buffer and window.namespace then
            window.extmarks[extmark_id] = vim.api.nvim_buf_set_extmark(window.buffer,
                window.namespace,
                line_start,
                line_end,
                opts)
        end
    end)
end

function scout_window_manager:get_window_extmark(name, extmark_id)
    self:perform_window_action(name, function (window)
        return window.extmarks[extmark_id]
    end)
end

function scout_window_manager:clear_window_extmark_by_id(name, extmark_id)
    self:perform_window_action(name, function (window)
        if window.buffer and window.namespace and window.extmarks[extmark_id] then
            vim.api.nvim_buf_del_extmark(window.buffer, window.namespace, window.extmarks[extmark_id])
            window.extmarks[extmark_id] = nil
        end
    end)
end

return scout_window_manager
