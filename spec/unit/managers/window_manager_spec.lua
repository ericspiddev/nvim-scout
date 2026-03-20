local utils = require('spec.spec_utils')
utils:register_global_logger()
utils:register_global_consts()
local window_manager = require('nvim-scout.managers.window_manager')
local stub = require('luassert.stub')
local match = require('luassert.match')
local window_config = {
    focus_window = true,
    buffer = {
        list_buf = true,
        scratch_buf = true,
        name = Scout_Consts.search.search_name,
    },
    nvim_open_win_config = {
        relative='editor',
        row=0,
        col=10,
        width = 25,
        zindex=1,
        focusable=false,
        height=1,
        style="minimal",
        border= Scout_Consts.borders.double,
        title_pos="center",
        title="Test Window"
    }
}

function mock_wm_apis()
    stub(vim.api, "nvim_create_buf").returns(5)
    stub(vim.api, "nvim_get_current_win").returns(1000)
    stub(vim.api, "nvim_open_win").returns(1001)
    stub(vim.api, "nvim_win_is_valid").returns(true)
    stub(vim.api, "nvim_win_set_hl_ns")
    stub(vim.api, "nvim_win_close")
    stub(vim.api, "nvim_buf_is_valid").returns(false)
    stub(vim.api, "nvim_buf_delete")
    stub(vim.api, "nvim_buf_set_name")
end

function revert_wm_mocks()
    vim.api.nvim_create_buf:revert()
    vim.api.nvim_get_current_win:revert()
    vim.api.nvim_open_win:revert()
    vim.api.nvim_win_is_valid:revert()
    vim.api.nvim_win_set_hl_ns:revert()
    vim.api.nvim_win_close:revert()
    vim.api.nvim_buf_is_valid:revert()
    vim.api.nvim_buf_delete:revert()
    vim.api.nvim_buf_set_name:revert()
end

function init_wm(window, config)
    local id = window or "test_window"
    local conf = config or window_config
    local wm = window_manager:new()
    wm:register_window(id, conf)
    return id, wm
end

describe('Window Manager', function ()
    it('can register and retrieve windows', function ()
        local wm = window_manager:new()
        local id
        assert(not wm:get_managed_window(id))

        id, wm = init_wm()
        assert(wm:get_managed_window(id))
        assert(not wm:get_managed_window("window does not exist"))
    end)

    it('initalizes windows to valid default values', function ()
        local id, wm = init_wm()
        local window = wm:get_managed_window(id)
        assert(window)
        assert.equals(window.name, id)
        assert.equals(window.open, false)
        assert.same(window.config, window_config)
        assert.equals(window.id, Scout_Consts.window.INVALID_WINDOW_ID)
        assert.equals(window.buffer, Scout_Consts.buffer.INVALID_BUFFER)
        assert.same(window.extmarks, {})
    end)

    it('can open and close windows', function ()
        mock_wm_apis()
        local id, wm = init_wm()
        local window = wm:get_managed_window(id)
        local fake_ns = 10
        wm:open_window_by_name(id)
        assert(window.open)
        assert.equals(window.buffer, 5)
        assert.equals(window.host, 1000)
        assert.equals(window.id, 1001)
        assert.equals(window.namespace, nil)

        wm:close_window_by_name(id)
        assert(not window.open)
        assert.equals(window.buffer, Scout_Consts.buffer.INVALID_BUFFER)
        assert.equals(window.host, Scout_Consts.window.INVALID_WINDOW_ID)
        assert.equals(window.id, Scout_Consts.window.INVALID_WINDOW_ID)
        assert.equals(window.namespace, nil)

        wm:open_window_by_name(id, fake_ns)
        assert.equals(window.namespace, fake_ns)
        wm:close_window_by_name(id, fake_ns)
        assert.equals(window.namespace, nil)
        revert_wm_mocks()
    end)

    it('can update the window and neovim window config', function ()
        local id, wm = init_wm()
        local window = wm:get_managed_window(id)
        assert.same(window.config, window_config)
        local update = {
            nvim_open_win_config = {
                col = 21
            },
            buffer = {
                name = "new name"
            },
            focus_window = false
        }

        wm:update_window_config(id, update)
        assert.equals(window.config.buffer.name, "new name")
        assert.equals(window.config.nvim_open_win_config.col, 21)
        assert.equals(window.config.focus_window, false)

        id, wm = init_wm()
        window = wm:get_managed_window(id)
        update = {
            height = 2,
            col = 20,
            focusable= true,
            width=25
        }

        wm:update_nvim_window_config(id, update)
        assert.equals(window.config.nvim_open_win_config.height, 2)
        assert.equals(window.config.nvim_open_win_config.col, 20)
        assert.equals(window.config.nvim_open_win_config.focusable, true)
        assert.equals(window.config.nvim_open_win_config.width, 25)
    end)

    it('properly reports when the window is open', function ()
        mock_wm_apis()

        local id, wm = init_wm()
        assert.is_not(wm:is_window_open(id))
        wm:open_window_by_name(id)
        assert(wm:is_window_open(id))
        wm:close_window_by_name(id)
        assert.is_not(wm:is_window_open(id))

        revert_wm_mocks()
    end)

    it('can cleanup window resources', function ()
        stub(vim.api, "nvim_win_is_valid").returns(true)
        stub(vim.api, "nvim_buf_is_valid").returns(true)
        stub(vim.api, "nvim_buf_delete")
        stub(vim.api, "nvim_win_close")
        local id, wm = init_wm()
        local window = wm:get_managed_window(id)
        window.buffer = 20
        window.id = 1005
        wm:cleanup_window_resources(window)

        assert.stub(vim.api.nvim_win_close).was_called_with(1005, false)
        assert.stub(vim.api.nvim_buf_delete).was_called_with(20, match.is_table())

        stub(vim.api, "nvim_win_is_valid").returns(false)
        stub(vim.api, "nvim_buf_is_valid").returns(false)
        window = wm:get_managed_window(id)
        window.buffer = 1
        window.id = 1020

        wm:cleanup_window_resources(window)
        assert.stub(vim.api.nvim_win_close).was_not.called_with(1020, false)
        assert.stub(vim.api.nvim_buf_delete).was_not.called_with(1, match.is_table())
        vim.api.nvim_win_is_valid:revert()
        vim.api.nvim_buf_is_valid:revert()
        vim.api.nvim_buf_delete:revert()
        vim.api.nvim_win_close:revert()

    end)

    it('succesfully toggles focus between host and created window', function ()
        local id, wm = init_wm()
        local window = wm:get_managed_window(id)
        window.host = 1004
        window.id = 1005
        window.open = true
        stub(vim.api, "nvim_get_current_win").returns(window.id)
        stub(vim.api, "nvim_win_is_valid").returns(true)
        stub(vim.api, "nvim_set_current_win")

        wm:toggle_window_focus(id)
        assert.stub(vim.api.nvim_set_current_win).was_called_with(window.host)
        stub(vim.api, "nvim_get_current_win").returns(window.host)

        wm:toggle_window_focus(id)
        assert.stub(vim.api.nvim_set_current_win).was_called_with(window.id)

        vim.api.nvim_get_current_win:revert()
        vim.api.nvim_win_is_valid:revert()
        vim.api.nvim_set_current_win:revert()
    end)

    it('can get and set a window\'s contents', function ()
        stub(vim.api, "nvim_buf_set_lines")
        local id, wm = init_wm()
        local window = wm:get_managed_window(id)
        local test_content = "Sets window to this string"
        stub(vim.api, "nvim_buf_get_lines").returns(test_content)
        window.buffer = 10
        wm:set_window_buf_contents(id, test_content)
        assert.stub(vim.api.nvim_buf_set_lines).was_called_with(
            match._,
            match._,
            match._,
            match._,
            {test_content})

        assert.equals(wm:get_window_buf_contents(id), test_content)

        test_content = {"first", "second", "third", "fourth"}
        stub(vim.api, "nvim_buf_get_lines").returns(test_content)
        wm:set_window_buf_contents(id, test_content)
        assert.stub(vim.api.nvim_buf_set_lines).was_called_with(
            match._,
            match._,
            match._,
            match._,
            {test_content})

        assert.equals(wm:get_window_buf_line(id, 1), "first")
        assert.equals(wm:get_window_buf_line(id, 2), "second")
        assert.equals(wm:get_window_buf_line(id, 3), "third")
        assert.equals(wm:get_window_buf_line(id, 4), "fourth")

    end)

    it('can get and set extmarks for the window', function ()
        stub(vim.api, "nvim_buf_set_extmark").returns(12)
        local id, wm = init_wm()
        local extmark_id = "test_extmark"
        local window = wm:get_managed_window(id)
        assert.is_not(wm:get_window_extmark(id, extmark_id))

        window.buffer = 5
        window.namespace = 2
        wm:set_window_extmarks(id, 1, 4, {hl_group = "test"}, extmark_id)
        assert.equals(wm:get_window_extmark(id, extmark_id), 12)

        window.buffer = nil
        extmark_id = "nil_buffer_id"
        wm:set_window_extmarks(id, 1, 4, {hl_group = "test"}, extmark_id)
        assert.is_not(wm:get_window_extmark(id, extmark_id))

        window.buffer = 5
        window.namespace = nil
        extmark_id = "nil_namespace_id"
        wm:set_window_extmarks(id, 1, 4, {hl_group = "test"}, extmark_id)
        assert.is_not(wm:get_window_extmark(id, extmark_id))
    end)

    it('can clear and reset the extmark', function ()
        stub(vim.api, "nvim_buf_set_extmark").returns(10)
        stub(vim.api, "nvim_buf_del_extmark").returns(10)
        local id, wm = init_wm()
        local extmark_id = "test_extmark"
        local window = wm:get_managed_window(id)
        window.buffer = 5
        window.namespace = 2
        wm:set_window_extmarks(id, 1, 4, {hl_group = "test"}, extmark_id)
        assert.equals(wm:get_window_extmark(id, extmark_id), 10)

        wm:clear_window_extmark_by_id(id, extmark_id)
        assert.is_not(wm:get_window_extmark(id, extmark_id))

        stub(vim.api, "nvim_buf_set_extmark").returns(30)
        wm:set_window_extmarks(id, 1, 4, {hl_group = "test"}, extmark_id)
        assert.equals(wm:get_window_extmark(id, extmark_id), 30)

        window.buffer = nil
        wm:clear_window_extmark_by_id(id, extmark_id)
        assert.equals(wm:get_window_extmark(id, extmark_id), 30)

        window.buffer = 5
        window.namespace = nil
        wm:clear_window_extmark_by_id(id, extmark_id)
        assert.equals(wm:get_window_extmark(id, extmark_id), 30)

        vim.api.nvim_buf_set_extmark:revert()
        vim.api.nvim_buf_del_extmark:revert()
    end)
end)
