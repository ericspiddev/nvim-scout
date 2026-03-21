local keymaps = require("nvim-scout.events.keymaps")
local stub = require('luassert.stub')
describe('Scout Keymaps', function ()

    function create_keymap_table(mode, key, handler)
        return {mode = mode, key = key, handler = handler}
    end

    it('can register keymaps', function ()
        local km = keymaps:new()
        local test_id = "test_keymap"
        local handler = function () end
        local handlerTwo = function() end
        local handlerThree = function() end
        local keymap1 = create_keymap_table('n', 'h', handler)
        local keymap2 = create_keymap_table('v', '#', handlerTwo)
        local keymap3 = create_keymap_table('i', 'k', handlerThree)
        km:register_keymap(test_id, keymap1)
        assert(km.keymap_table[test_id])
        assert.is_equal(km.keymap_table[test_id].mode, 'n')
        assert.is_equal(km.keymap_table[test_id].key, 'h')
        assert.is_same(km.keymap_table[test_id].handler, handler)
        assert.is_not(km.keymap_table[test_id].active)

        test_id = "keymap_two"
        km:register_keymap(test_id, keymap2)
        assert(km.keymap_table[test_id])
        assert.is_equal(km.keymap_table[test_id].mode, 'v')
        assert.is_equal(km.keymap_table[test_id].key, '#')
        assert.is_equal(km.keymap_table[test_id].handler, handlerTwo)
        assert.is_not(km.keymap_table[test_id].active)

        test_id = "test_keymap"
        km:register_keymap(test_id, keymap3)
        assert(km.keymap_table[test_id])
        assert.is_equal(km.keymap_table[test_id].mode, 'i')
        assert.is_equal(km.keymap_table[test_id].key, 'k')
        assert.is_equal(km.keymap_table[test_id].handler, handlerThree)
        assert.is_not(km.keymap_table[test_id].active)

    end)

    it('can setup keymaps with/without buffer and custom options', function()
        stub(vim.keymap, "set")
        stub(vim.api, "nvim_buf_is_valid").returns(true)
        local default_options = {
            nowait = true,
            noremap = true
        }
        local km = keymaps:new()
        local test_id = "test_keymap"
        local handler = function () end
        local keymap1 = create_keymap_table('n', 'h', handler)

        km:set_keymap("does_not_exist")
        assert.stub(vim.keymap.set).was_not.called()

        km:register_keymap(test_id, keymap1)
        km:set_keymap(test_id)
        assert(km.keymap_table[test_id].active)
        assert.stub(vim.keymap.set).was_called_with(keymap1.mode, keymap1.key, handler, default_options)

        test_id = "test_two"
        local keymap2 = create_keymap_table('v', 'k', handler)
        local buffer = 20
        km:register_keymap(test_id, keymap2)
        km:set_keymap(test_id, buffer)
        local options = default_options
        options["buffer"] = 20
        assert(km.keymap_table[test_id].active)
        assert.stub(vim.keymap.set).was_called_with(keymap2.mode, keymap2.key, handler, options )

        test_id = "newone"
        local keymap3 = create_keymap_table('i', 'a', handler)
        local custom_opts = {eric = true, choice = "fake_options"}
        km:register_keymap(test_id, keymap3)
        km:set_keymap(test_id, nil, custom_opts)
        assert(km.keymap_table[test_id].active)
        assert.stub(vim.keymap.set).was_called_with(keymap3.mode, keymap3.key, handler, custom_opts)

        vim.keymap.set:revert()
        vim.api.nvim_buf_is_valid:revert()
    end)

    it('can teardown keymaps with or without a buffer', function ()
        stub(vim.keymap, "del")
        stub(vim.keymap, "set")
        stub(vim.api, "nvim_buf_is_valid").returns(true)
        local km = keymaps:new()
        local test_id = "test_keymap"
        local handler = function () end
        local keymap = create_keymap_table('n', 'h', handler)

        km:del_keymap("does_not_exist")
        assert.stub(vim.keymap.del).was_not.called()

        km:register_keymap(test_id, keymap)
        km:del_keymap(test_id)
        assert.stub(vim.keymap.del).was_not.called()

        km:set_keymap(test_id)
        km:del_keymap(test_id)
        assert.stub(vim.keymap.del).was_called_with(keymap.mode, keymap.key)
        assert.is_not(km.keymap_table[test_id].active)

        test_id = "custom_keymap"
        keymap = create_keymap_table('r', 'P', handler)
        local buffer = 4
        km:register_keymap(test_id, keymap)
        km:set_keymap(test_id, buffer)
        km:del_keymap(test_id)
        assert.stub(vim.keymap.del).was_called_with(keymap.mode, keymap.key, {buffer = buffer})
        assert.is_not(km.keymap_table[test_id].active)

        vim.keymap.set:revert()
        vim.keymap.del:revert()
        vim.api.nvim_buf_is_valid:revert()
    end)
end)
