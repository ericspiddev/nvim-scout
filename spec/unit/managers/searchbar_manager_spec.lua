-- import the luassert.mock module
local utils = require('spec.spec_utils')
utils:register_global_logger()
utils:register_global_consts()
local stub = require('luassert.stub')
local default_conf = require('nvim-scout.config.config').defaults
local mock_wm = require('spec.mocks.window_manager_mock')
local mock_theme = require('spec.mocks.theme_parser_mock')
local searchbar_manager = require('nvim-scout.managers.searchbar_manager')


-- test constants
SEARCH_BAR_BUF_ID = 1
SEARCH_BAR_WIN_ID = 1005
SEARCH_BAR_WINDOW_WIDTH = 100

-- hepler functions
function setup_search_tests()
    utils:mock_logger_prints()
    -- STUBS to mock out so we aren't hitting the real API
    stub(vim.api, "nvim_create_buf").returns(SEARCH_BAR_BUF_ID)
    stub(vim.api, "nvim_open_win").returns(SEARCH_BAR_WIN_ID)
    stub(vim.api, "nvim_buf_attach").returns()
    stub(vim.api, "nvim_buf_delete").returns()
    stub(vim.api, "nvim_win_close").returns()
    stub(vim.api, "nvim_buf_get_lines").returns({"first", "second", "third"})
    stub(vim.api, "nvim_win_get_width").returns(SEARCH_BAR_WINDOW_WIDTH)
    stub(vim.api, "nvim_win_set_config").returns()
    stub(vim.api, "nvim_get_current_win").returns(0)
    stub(vim.keymap, "set").returns()
    stub(vim.keymap, "del").returns()
end

function teardown_search_stubs()
    vim.api.nvim_create_buf:revert()
    vim.api.nvim_open_win:revert()
    vim.api.nvim_buf_attach:revert()
    vim.api.nvim_buf_delete:revert()
    vim.api.nvim_win_close:revert()
    vim.api.nvim_buf_get_lines:revert()
    vim.api.nvim_win_get_width:revert()
    vim.api.nvim_win_set_config:revert()
    vim.keymap.set:revert()
    vim.keymap.del:revert()
end

function open_asserts(search)
    assert(search.buffer, SEARCH_BAR_BUF_ID)
    assert(search.id, SEARCH_BAR_WIN_ID)
    assert(search.host)
    assert(search.open)
end

function closed_asserts(search)
    assert.equals(search.buffer, 0)
    assert.equals(search.id, 0)
    assert.equals(search.host, 0)
    assert.equals(search.open, false)
end

describe("Searchbar Manager ", function()

    local id = "Search"
    local ext_id = "search_ext"
    default_conf.search.size = 0.15
    local wm = mock_wm:new()
    local theme = mock_theme
    wm:register_window(id, {})
    local searchbar_mgr = searchbar_manager:new(id,wm, default_conf.search, ext_id, theme)
    setup_search_tests()

    before_each(function()
        searchbar_mgr:close_searchbar()
    end)

    it('can open a search window and assign it a valid ID', function()
        searchbar_mgr:open_searchbar()
        open_asserts(searchbar_mgr:get_searchbar())
    end)

    it('has invalid values when the window is closed', function()
        searchbar_mgr:open_searchbar()
        searchbar_mgr:close_searchbar()
        closed_asserts(searchbar_mgr:get_searchbar())
    end)

    it('properly reports when it is open and closed', function()
        searchbar_mgr:close_searchbar()
        assert.equals(searchbar_mgr:is_searchbar_open(), false)
        searchbar_mgr:open_searchbar()
        assert.equals(searchbar_mgr:is_searchbar_open(), true)
        searchbar_mgr:open_searchbar()
        searchbar_mgr:open_searchbar()
        assert.equals(searchbar_mgr:is_searchbar_open(), true)
        searchbar_mgr:close_searchbar()
        searchbar_mgr:close_searchbar()
        searchbar_mgr:close_searchbar()
        searchbar_mgr:close_searchbar()
        assert.equals(searchbar_mgr:is_searchbar_open(), false)
    end)

    it('can toggle between the host and searchbar window ', function ()
        searchbar_mgr:open_searchbar()
        local searchbar = searchbar_mgr:get_searchbar()
        assert.equals(searchbar.current_win, searchbar.id)
        searchbar_mgr:toggle_window_focus()
        assert.equals(searchbar.current_win, searchbar.host)
        searchbar_mgr:toggle_window_focus()
        assert.equals(searchbar.current_win, searchbar.id)
        searchbar_mgr:toggle_window_focus()
        assert.equals(searchbar.current_win, searchbar.host)
    end)

    it('can set the searchbar windows contents and clear it', function ()
        searchbar_mgr:open_searchbar()
        local content = searchbar_mgr:get_searchbar_contents()
        assert.equals("", content)
        searchbar_mgr:set_searchbar_contents("test string")
        content = searchbar_mgr:get_searchbar_contents()
        assert.equals("test string", content)
        searchbar_mgr:clear_searchbar()
        content = searchbar_mgr:get_searchbar_contents()
        assert.equals("", content)
    end)

end)
