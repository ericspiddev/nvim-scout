scout_keymaps = {}

scout_keymaps.__index = scout_keymaps

function scout_keymaps:new()
    local obj = {
        keymap_table = {}
    }
    return setmetatable(obj, self)
end

function scout_keymaps:register_keymap(id, keymap)
    keymap.active = false
    self.keymap_table[id] = keymap
end

function scout_keymaps:set_keymap(id, buffer, options)
    local keymap = self.keymap_table[id]
    if keymap then
        local default_options = {
            nowait = true,
            noremap = true
        }

        if buffer and vim.api.nvim_buf_is_valid(buffer) then
            default_options["buffer"] = buffer
        end

        if not options then
            keymap["options"] = default_options
        end
        vim.keymap.set(keymap.mode, keymap.key, keymap.handler, keymap.options)
        keymap.active = true
    end
end

function scout_keymaps:del_keymap(id)
    local keymap = self.keymap_table[id]
    if keymap and keymap.active then
        if keymap.options.buffer then
            vim.keymap.del(keymap.mode, keymap.key, {buffer = keymap.options.buffer})
        else
            vim.keymap.del(keymap.mode, keymap.key)
        end
        keymap.active = false
    end
end

return scout_keymaps
