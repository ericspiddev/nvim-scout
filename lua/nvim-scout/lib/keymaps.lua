scout_keymaps = {}
local consts = require("nvim-scout.lib.consts")

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

-------------------------------------------------------------
--- keymaps.setup_search_keymaps: this function handles setting
--- up keymaps for the search_bar when it's open this should be
--- called when the search bar is opened so all keybinds work
--- while in the search buffer
---
function scout_keymaps:setup_search_keymaps()
    vim.keymap.set('n', self.keymaps.prev_result, function() self.search_bar:previous_match() end, {
        buffer = self.search_bar.query_buffer,
        nowait = true,
        noremap = true})
    vim.keymap.set('n', self.keymaps.next_result, function() self.search_bar:next_match() end, {
        buffer = self.search_bar.query_buffer,
        nowait = true,
        noremap = true})
    vim.keymap.set('n', self.keymaps.clear_search, function() self.search_bar:clear_search() end, {
        buffer = self.search_bar.query_buffer,
        nowait= true,
        noremap = true})

    -- disable ENTER in buffer
    vim.keymap.set('i', "<Enter>", function () end, {buffer = self.search_bar.query_buffer})
end

function scout_keymaps:setup_history_keymaps()
    vim.keymap.set('n', self.keymaps.next_history, function() self.search_bar:next_history_entry() end, {
        buffer = self.search_bar.query_buffer,
        nowait = true,
        noremap = true})

    vim.keymap.set('n', self.keymaps.prev_history, function() self.search_bar:previous_history_entry() end, {
        buffer = self.search_bar.query_buffer,
        nowait = true,
        noremap = true})
end

function scout_keymaps:setup_mode_keymaps()
    vim.keymap.set('n', self.keymaps.case_sensitive_toggle, function()
        self.search_bar.mode_manager:toggle_mode(Scout_Consts.modes.case_sensitive)
        self.search_bar:run_search()
    end, {
        buffer = self.search_bar.query_buffer,
        nowait = true,
        noremap = true})
    vim.keymap.set('n', self.keymaps.pattern_toggle, function()
        self.search_bar.mode_manager:toggle_mode(Scout_Consts.modes.lua_pattern)
        self.search_bar:run_search()
     end, {
        buffer = self.search_bar.query_buffer,
        nowait = true,
        noremap = true})
end

-------------------------------------------------------------
--- keymaps.teardown_search_keymaps: this function handles
--- deleting all of the keymaps that get setup for the search
--- window. It's important that
---
function scout_keymaps:teardown_search_keymaps()
    vim.keymap.del('n', self.keymaps.next_result, {buffer = self.search_bar.query_buffer })
    vim.keymap.del('n', self.keymaps.prev_result, {buffer = self.search_bar.query_buffer})
    vim.keymap.del('n', self.keymaps.clear_search, {buffer = self.search_bar.query_buffer})
end

function scout_keymaps:teardown_history_keymaps()
    vim.keymap.del('n', self.keymaps.prev_history, {buffer = self.search_bar.query_buffer })
    vim.keymap.del('n', self.keymaps.next_history, {buffer = self.search_bar.query_buffer})
end

function scout_keymaps:teardown_mode_keymaps()
    vim.keymap.del('n', self.keymaps.case_sensitive_toggle, {buffer = self.search_bar.query_buffer})
    vim.keymap.del('n', self.keymaps.pattern_toggle, {buffer = self.search_bar.query_buffer})
end

function scout_keymaps:setup_scout_keymaps()
    self:setup_search_keymaps()
    self:setup_history_keymaps()
    self:setup_mode_keymaps()
end

function scout_keymaps:teardown_scout_keymaps()
    self:teardown_search_keymaps()
    self:teardown_history_keymaps()
    self:teardown_mode_keymaps()
end

return scout_keymaps
