local logger = require('nvim-scout.lib.scout_logger')
local mock = require('luassert.mock')
local match = require('luassert.match')
local consts = require('nvim-scout.lib.consts')
local search_mode = require('nvim-scout.lib.search_mode')
spec_utils = {}

spec_utils.__index = spec_utils
local mock_logger = nil

function spec_utils:emulate_user_typing(string)
    vim.api.nvim_feedkeys('i' .. string, "tx", true)
end
function spec_utils:emulate_user_keypress(key)
    vim.api.nvim_feedkeys(key, "x", true)
end

function spec_utils:highlight_words_in_visual_mode(num_words, direction)
    vim.api.nvim_feedkeys('v', "n", true) -- set up visual mode
    for _ = 1, num_words do
        if direction then
            vim.api.nvim_feedkeys('b', "n", true) -- go backwards
        else
            vim.api.nvim_feedkeys('w', "n", true) -- get next word
        end
    end

    if not direction then
        vim.api.nvim_feedkeys('e', "n", true) -- set up visual mode
    end
end

function spec_utils:async_asserts(delay, async_asserts, ...)
    local co = coroutine.running()
    vim.defer_fn(function ()
        coroutine.resume(co)
    end, delay)
    coroutine.yield()
    async_asserts(...)
end

function spec_utils:test_buffer_to_table(filename)
    local file_path = vim.fn.expand("spec/test_buffers/" .. filename)
    local lines = {}
    local f = assert(io.open(file_path, "r"))
    local line = f:read()
    while line do
        table.insert(lines, line)
        line = f:read()
    end

    f:close()
    return lines
end

function spec_utils:open_test_buffer(filename)
    local file_path = vim.fn.expand("spec/test_buffers/" .. filename)
    local f = assert(io.open(file_path, "r"))
    vim.cmd.edit(file_path)
end

function spec_utils:keycodes_user_keypress(keycode_key, mode)
    if mode then
        vim.api.nvim_feedkeys(mode, "i", false)
    end
    local keycode = vim.api.nvim_replace_termcodes(keycode_key, true, false, true) -- check these params....
    vim.api.nvim_feedkeys(keycode, "x", false)
end

function spec_utils:compare_matches(m1, m2)
    if not (m1.row == m2.row and
            m1.m_start == m2.m_start and
            m1.m_end == m2.m_end) then
        vim.print("Match 1 is " .. vim.inspect(m1))
        vim.print("Match 2 is " .. vim.inspect(m2))
    else
        return true
    end
end

function spec_utils:table_contains(table, check)
   for _, value in pairs(table) do
        if value == check then
            return true
        end
    end
    return false
end

function spec_utils:mock_logger_prints()
    mock_logger = mock(logger, true)
    mock_logger.debug_print.returns()
    mock_logger.info_print.returns()
    mock_logger.warning_print.returns()
    mock_logger.error_print.returns()
end

function spec_utils:lists_are_equal(t1, t2)
    if #t1 ~= #t2 then
        return false
    end
    for index = 1, #t1 do
        if t1[index] ~= t2[index] then
            return false
        end
    end

    return true
end

function spec_utils:tables_are_equal(t1, t2)
    local are_equal = true
    for key, _ in pairs(t1) do
        if type(t1[key]) == 'table' then
            self:tables_are_equal(t1[key], t2[key])
        end
        if t1[key] ~= t2[key] then
            are_equal = false
        end
    end

    for key, _ in pairs(t2) do
        if t2[key] ~= t1[key] then
            are_equal = false
        end
    end

    if not are_equal then
        vim.print("Table 1 is " .. vim.inspect(t1))
        vim.print("Table 2 is " .. vim.inspect(t2))
    end

    return are_equal
end


function spec_utils:scout_print_was_called(level, message, var)
    if mock_logger == nil then
        assert(false)
    end
    local print_fn = nil
    if level == logger.LOG_LEVELS.ERROR then
        print_fn = mock_logger.error_print
    elseif level == logger.LOG_LEVELS.WARNING then
        print_fn = mock_logger.warning_print
    elseif level == logger.LOG_LEVELS.INFO then
        print_fn = mock_logger.info_print
    elseif level == logger.LOG_LEVELS.DEBUG then
        print_fn = mock_logger.debug_print
    else
        return
    end

    if var == nil then
        assert.stub(print_fn).was_called_with(match.is_table(), message)
    else
        if type(var) == 'table' then
            assert.stub(print_fn).was_called_with(match.is_table(), message, match.is_table())
        else
            assert.stub(print_fn).was_called_with(match.is_table(), message, match.is_equal(var))
        end
    end
    print_fn:clear() -- clears the call history

end

function spec_utils:register_global_logger()
    if _G.Scout_Logger == nil then
        _G.Scout_Logger = logger:new({level = logger.LOG_LEVELS.OFF}, vim.print)
    end
end

function spec_utils:revert_logger_prints()
    if mock_logger ~= nil then
        mock_logger.debug_print:revert()
        mock_logger.info_print:revert()
        mock_logger.warning_print:revert()
        mock_logger.error_print:revert()
        mock_logger = nil
    end
end

function spec_utils:get_supported_modes(namespace_id)
    local search_modes = {}
    search_modes[consts.modes.lua_pattern] = search_mode:new("Lua Pattern", "P", namespace_id, consts.modes.pattern_color)
    search_modes[consts.modes.case_sensitive] = search_mode:new("Match Case", "C", namespace_id, consts.modes.case_sensitive_color)
    return search_modes
end

return spec_utils
