local init = require('nvim-scout.init')
local default_conf = require('nvim-scout.lib.config').defaults
local utils = require('spec.spec_utils')

describe('Functional: Search bar', function()
        local scout = init
        scout.setup()

        before_each(function()
            utils:emulate_user_keypress(default_conf.keymaps.toggle_search)
        end)

        after_each(function()
            utils:emulate_user_keypress(default_conf.keymaps.toggle_search)
        end)
    it('takes in user input into the search bar', function()

        utils:emulate_user_typing("Eric Spidle is so cool!")

        local search_str = vim.api.nvim_buf_get_lines(scout.search_bar.query_buffer, 0, 1, true)[1]
        assert.equals(search_str, "Eric Spidle is so cool!")

    end)

    it('can clear a user\'s search with the keymapping', function()

        utils:emulate_user_typing("New string to enter!")

        local search_str = vim.api.nvim_buf_get_lines(scout.search_bar.query_buffer, 0, 1, true)[1]
        assert.equals(search_str, "New string to enter!")
        utils:emulate_user_keypress(default_conf.keymaps.clear_search)

        search_str = vim.api.nvim_buf_get_lines(scout.search_bar.query_buffer, 0, 1, true)[1]
        assert.equals(search_str, "")
    end)

    it('can grab what is in the search bar', function()

        utils:emulate_user_typing("First string to enter!")
        assert.equals(scout.search_bar:get_window_contents(), "First string to enter!")
        utils:emulate_user_keypress(default_conf.keymaps.clear_search)

        utils:emulate_user_typing("Second string")

        assert.equals(scout.search_bar:get_window_contents(), "Second string")
        utils:emulate_user_keypress(default_conf.keymaps.clear_search)
    end)

    it('only ignores enters in insert mode', function()
        utils:emulate_user_typing("Top line string ")
        utils:keycodes_user_keypress('<CR>', 'i')
        utils:emulate_user_typing(" bottom line string")

        -- FIXME: the emulated typing is doing some odd stuff for this case still this proves the enter doesn't work
        assert.equals(scout.search_bar:get_window_contents(), "Top line strin bottom line stringg ")
    end)

    it('does not clear the string if you unfocus the search bar and then come back', function()
        utils:emulate_user_typing("Sticky string")
        assert.equals(scout.search_bar:get_window_contents(), "Sticky string")

        utils:keycodes_user_keypress("<C-w>h") -- switch out of window
        assert.equals(scout.search_bar:get_window_contents(), "Sticky string")

        utils:emulate_user_keypress(default_conf.keymaps.focus_search)
        assert.equals(scout.search_bar:get_window_contents(), "Sticky string")
    end)

    it('does clear the search bar if it\'s closed and reopened', function()
        utils:emulate_user_typing("Won't be here soon")
        assert.equals(scout.search_bar:get_window_contents(), "Won't be here soon")

        utils:emulate_user_keypress(default_conf.keymaps.toggle_search) -- close
        utils:emulate_user_keypress(default_conf.keymaps.toggle_search) -- open
        assert.equals(scout.search_bar:get_window_contents(), "")
    end)

end)
