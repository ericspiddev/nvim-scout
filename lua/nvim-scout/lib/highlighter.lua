scout_highlighter = {}
scout_highlighter.__index = scout_highlighter
local consts = require("nvim-scout.lib.consts")
local match_obj = require("nvim-scout.lib.match")
local pattern_handler = require("nvim-scout.lib.pattern_handler"):new(consts.modes.escape_chars)

function scout_highlighter:new(hl_namespace, mode_mgr)
    local obj = {
        hl_buf = -1, -- vim.api.nvim_win_get_buf(editor_window),
        hl_win = -1,-- editor_window,
        hl_context = consts.buffer.NO_CONTEXT,
        hl_namespace = hl_namespace,
        hl_wc_ext_id = consts.highlight.NO_WORD_COUNT_EXTMARK,
        matches = {},
        match_index = 1,
        invalid_pattern = false,
        mode_mgr = mode_mgr
    }
    return setmetatable(obj, self)
end

-------------------------------------------------------------
--- highlight.update_hl_context: clears the search
--- result numbers in the search_bar and then reads the buffer
--- id into hl_context field
--- @hl_buf: the buffer that will have it's contents loaded into hl_context
--- @scout_buf: search bar buffer this is used to clear search numbers
--- (rename to query_buffer or use buf directly?)
--- @return: whether or not the context was updated
---
function scout_highlighter:update_hl_context(hl_buf, scout_buf, hl_win)
    self.match_buf = scout_buf
    return self:populate_hl_context(hl_buf, hl_win)
end

-------------------------------------------------------------
--- highlighter.populate_hl_context: loads the content of the
--- buffer into the 'hl_context' field. This field is used
--- when seraching for the pattern in the query buffer
--- @buf_id: the buffer to load into highlight context field
--- @return: whether or not the context was populated
---
function scout_highlighter:populate_hl_context(buf_id, hl_win)
    if not vim.api.nvim_buf_is_valid(buf_id) then
        Scout_Logger.warning_print("Attempting to populate context with invalid buffer id")
        self.hl_context = consts.buffer.NO_CONTEXT
        self.hl_buf = consts.buffer.INVALID_BUFFER
        return false
    end
    local total_lines = vim.api.nvim_buf_line_count(buf_id)
    if total_lines > 0 then
        self.hl_buf = buf_id
        self.hl_win = hl_win

        Scout_Logger:debug_print("Populating context with " .. total_lines .. " total lines")

        Scout_Logger:debug_print("Populating context with " .. total_lines .. " total lines")
        self.hl_context = vim.api.nvim_buf_get_lines(buf_id, consts.lines.START, total_lines, false)
        Scout_Logger:debug_print("HL context set too " .. vim.inspect(self.hl_context))
        return true
    else
        Scout_Logger:warning_print("No valid lines found to populate highlight context")
        self.hl_context = consts.buffer.NO_CONTEXT
        self.hl_buf = consts.buffer.INVALID_BUFFER
        return false
    end
end

-------------------------------------------------------------
--- highlight.highlight_file_by_pattern: highlights the current
--- hl_context if it matches the pattern. It also updates the
--- search_results virtual text in the search buffer
--- @win_buf: the buffer to update the search results ex (3/5) in
--- @pattern: the pattern to highlight within the hl_context
---
function scout_highlighter:highlight_file_by_pattern(pattern)

    if pattern == nil or pattern == "" then
        Scout_Logger:warning_print("Nil or empty pattern cancelling search")
        return
    end
    if self.hl_context == consts.buffer.NO_CONTEXT then
        Scout_Logger:warning_print("No context to search through")
        return
    end

    local exact_match = self.mode_mgr:apply_lua_pattern_mode()
    local pattern_match = not exact_match

    if pattern_match then
        pattern = pattern_handler:escape_pattern_characters(pattern)
    end

    local start_time = os.clock()
    for line_number, line in ipairs(self.hl_context) do
        local search_index = 1
        line, pattern = self.mode_mgr:apply_modes_to_search_text(line, pattern)

        local run_time = os.clock() - start_time
        local success, pattern_start, pattern_end = self:protected_search(line, pattern, 1, exact_match)

        if not success then
            return
        end
         while pattern_start ~= nil do
             -- highlight with start index and end index
            self:highlight_pattern_in_line(line_number - 1, pattern_start - 1, pattern_end)
            search_index = pattern_end + 1
            success, pattern_start, pattern_end = self:protected_search(line, pattern, search_index, exact_match)

            if not success then
                return
            end

            if pattern_start and pattern_end then
                if pattern_start > #line then
                    break
                end
                -- dangerous patterns can get stuck on an index reset us here to finish out the search
                if pattern_end < pattern_start then
                    pattern_end = pattern_start
                end
            end

            if run_time >= 1 then
                Scout_Logger:error_print("Current search exceeded max search time of 1 second pattern: ", pattern)
                Scout_Logger:error_print("You should make your pattern searches as specific as possible as they can lead to quadratic time searches")
                self:clear_highlights()
                return
            end
            run_time = os.clock() - start_time
         end
    end


end

function scout_highlighter:protected_search(line, pattern, start_index, exact_match)
    local success, err_or_start, pattern_end = pcall(string.find, line, pattern, start_index, exact_match)
    if not success then
        local error = err_or_start
        if error:find("malformed pattern") or error:find("unbalanced pattern") or error:find("invalid capture index") then
            self.invalid_pattern = true
        else
            Scout_Logger:error_print("Error while searching ", error)
        end
    else
        self.invalid_pattern = false
    end

    return success, err_or_start, pattern_end
end

--------------------------------------------------------------
--- highlighter.update_match_count: responsible for updating
--- the virt text with the current match index e.x(3/5) that shows
--- in the search bar buffer
--- @buffer: the buffer where the search count is located (query_buffer)
---
function scout_highlighter:get_current_match_text()
    local match = self.match_index
    local match_list = self.matches

    if self.invalid_pattern then
        return consts.virt_text.invalid_pattern
    end

    if #match_list == 0 then
        return consts.virt_text.no_matches
    end

    if match ~= nil and match > -1
    and match_list ~= nil and #match_list > 0
    and match <= #match_list then
        local match_str = match .. "/" .. #match_list
        return match_str
    end
end

--------------------------------------------------------------
--- highlighter.highlight_pattern_in_line: using the line number
--- and start/end of the word this highlights the word on that
--- line and then creates a new match object and inserts it
--- into the self.matches table for bookkeeping of all matches
--- @line_number: the line number (row) that the word is located on
--- @word_start: start index (col) of the word on the line
--- @word_end: end index (col) of the word on the line
---
function scout_highlighter:highlight_pattern_in_line(line_number, word_start, word_end)

    if word_start < word_end then
        local extmark_id = vim.api.nvim_buf_set_extmark(self.hl_buf, self.hl_namespace, line_number, word_start,
            { end_col = word_end, hl_group = consts.colorscheme_groups.search_result })
        table.insert(self.matches, match_obj:new(line_number + 1, word_start, word_end, extmark_id))
    end
end

-------------------------------------------------------------
--- highligher.move_cursor: moves the user's cursor along matched
--- patterns throughout the hl_context it also updates the current
--- search result to be highlighted differently to show it's selected
--- @direction: which way to iterate through matches (forward or backward)
---
function scout_highlighter:move_cursor(index, host_window)
    if not index then
        Scout_Logger:error_print("Nil index!")
        return
    end
    if index <= 0 or index > #self.matches then
        Scout_Logger:error_print("Invalid index: ", index)
        return
    end

    if self.hl_win == consts.window.INVALID_WINDOW_ID then
        Scout_Logger:error_print("Invalid window id to move cursor through" )
        return
    end

    if not host_window then
        Scout_Logger:error_print("Attempted to move cursor for nil host window")
        return
    end

    if self.hl_win ~= host_window then
        Scout_Logger:warning_print("Window id holding buffer and stored highlight window mismatch!")
        Scout_Logger:warning_print("Actually moving through ", self.hl_win)
    end

    self:set_match_highlighting(self.matches[self.match_index], consts.colorscheme_groups.search_result)
    self.match_index = index

    local match = self.matches[self.match_index]

    vim.api.nvim_buf_del_extmark(self.hl_buf, self.hl_namespace, match.extmark_id)
    vim.api.nvim_win_set_cursor(self.hl_win, {match:get_cursor_row(), match.m_start})
    self:set_match_highlighting(match, consts.colorscheme_groups.selected_result)
    vim.api.nvim_buf_call(self.hl_buf, function () vim.cmd(consts.cmds.CENTER_SCREEN) end)
    return true
end

-------------------------------------------------------------
--- highligher.set_match_highlighting:
--- patterns throughout the hl_context it also updates the current
--- search result to be highlighted differently to show it's selected
--- @match: which way to iterate through matches (forward or backward)
--- @hl: the style to highlight the passed in match
--- (move me to match class??? weird spot with this one)
function scout_highlighter:set_match_highlighting(match, hl)
    if match ~= nil then
        local ext_id = vim.api.nvim_buf_set_extmark(self.hl_buf, self.hl_namespace, match:get_highlight_row(), match.m_start,
        { id = match.extmark_id, end_col = match.m_end, hl_group = hl })
        match:update_extmark_id(ext_id)
    end
end

-------------------------------------------------------------
--- highlighter.get_buffer_current_hls: gets all of the current
--- highlighted text extmarks and loads them into a table this
--- only effects extmarks this class sets because of the namespace
--- @buffer: the buffer with the highlight extmarks to retrieve
---
function scout_highlighter:get_buffer_current_hls(buffer)
    local ids = {}
    if buffer == nil or not vim.api.nvim_buf_is_valid(buffer) then
        Scout_Logger:warning_print("Invalid buffer to serach", buffer)
        return nil
    end
    if self.matches ~= nil then
        for _, match in ipairs(self.matches) do
            table.insert(ids, match.extmark_id)
        end
    end
    return ids
end

function scout_highlighter:get_closest_match(search_direction)
    if #self.matches == 0 then
        return nil
    end

    local cursor_pos = vim.api.nvim_win_get_cursor(self.hl_win)
    local line = cursor_pos[1]
    local w_start = cursor_pos[2]
    local index
    local curr_match

    if search_direction == consts.search.FORWARD then
        if self.matches[#self.matches].row == line and self.matches[#self.matches].m_start == w_start then
            return 1
        end
        index = 1
        curr_match = self.matches[index]
        while(curr_match.row < line and index < #self.matches) do
            index = index + 1
            curr_match = self.matches[index]
        end

        while(curr_match.row == line
            and curr_match.m_start <= w_start
            and index < #self.matches) do
                index = index + 1
                curr_match = self.matches[index]
        end
    elseif search_direction == consts.search.BACKWARD then
        if self.matches[1].row == line and self.matches[1].m_start == w_start then
            return #self.matches
        end

        index = #self.matches
        curr_match = self.matches[index]
        while(curr_match.row > line and index > 1) do
            index = index - 1
            curr_match = self.matches[index]
        end

        while(curr_match.row == line
            and curr_match.m_start >= w_start
            and index > 1) do
                index = index - 1
                curr_match = self.matches[index]
        end
    end

    return index
end

-------------------------------------------------------------
--- highlighter.clear_highlights: clears all of the currently
--- highlighted text in a buffer. Also clears the match_count
--- in the search window
--- @hl_buf: buffer that is currently being searched (likely shown in current window)
--- @win_buf: query buffer that holds the match count e.x. (3/5)
---
function scout_highlighter:clear_highlights()
    local hls = self:get_buffer_current_hls(self.hl_buf)
    if hls then
        for _, match_id in ipairs(hls) do
            vim.api.nvim_buf_del_extmark(self.hl_buf, self.hl_namespace, match_id)
        end
    end
    self.match_index = 1
    self.matches = {}
end

return scout_highlighter
