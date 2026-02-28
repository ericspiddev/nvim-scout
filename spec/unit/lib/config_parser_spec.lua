local consts = require('nvim-scout.lib.consts')
local config = require('nvim-scout.lib.config').new()
local parser = require('nvim-scout.lib.config_parser')
local utils = require('spec.spec_utils')
local config_options = require('nvim-scout.lib.config_options')
utils:register_global_logger()

sizes = config_options.scout_sizes
log_levels = config_options.scout_log_level

function width_to_size(width)
    if width == consts.sizes.xs then
        return sizes.XS
    elseif width == consts.sizes.small then
        return sizes.SMALL
    elseif width == consts.sizes.medium then
        return sizes.MED
    elseif width == consts.sizes.large then
        return sizes.LARGE
    elseif width == consts.sizes.xl then
        return sizes.XL
    elseif width == consts.sizes.full then
        return sizes.FULL
    end
end

describe('Config Parser', function ()

    it('creates a new instance with the config defaults', function ()
        local p = scout_config_parser:new({})
        assert.same(p.defaults, config.defaults)
    end)

    it('uses a new default config instance for each parser', function ()
        local opts = {
            search = {
                size = sizes.XL
            },
        }
        local p = scout_config_parser:new(opts)
        local conf = p:parse_config()
        assert.equals(conf.search.size, consts.sizes.xl)
        assert.equals(conf.logging.level, log_levels.OFF)

        opts = {
            logging = {
                level = log_levels.INFO
            }
        }
        p = scout_config_parser:new(opts)
        conf = p:parse_config()
        assert.equals(conf.search.size, consts.sizes.medium)
        assert.equals(conf.logging.level, log_levels.INFO)

        p = scout_config_parser:new()
        conf = p:parse_config()
        conf.search.size = width_to_size(conf.search.size) -- parse config translates enum to width % so we convert back here
        assert.same(conf, config.defaults)
    end)

    it('returns all defaults when no config is provided',function ()
        local p = parser:new()
        local conf = p:parse_config()
        conf.search.size = width_to_size(conf.search.size) -- parse config translates enum to width % so we convert back here
        assert.same(conf, config.defaults)
    end )

    it('layers user options over defaults', function ()
        local opts = {
            keymaps = {
                toggle_search = '<leader>/',
                case_sensitive_toggle = 'M',
                next_result = 'r',
            },
            search = {
                size = 3
            },
            logging = {
                level = log_levels.INFO
            }
        }

        local p = parser:new(opts)
        local conf = p:parse_config()
        local defaults = config.defaults
        assert.equals(conf.keymaps.toggle_search, '<leader>/')
        assert.equals(conf.keymaps.case_sensitive_toggle, 'M')
        assert.equals(conf.keymaps.toggle_focus, defaults.keymaps.toggle_focus)
        assert.equals(conf.keymaps.clear_search, defaults.keymaps.clear_search)
        assert.equals(conf.keymaps.prev_result, defaults.keymaps.prev_result)
        assert.equals(conf.keymaps.next_result, 'r')
        assert.equals(conf.keymaps.prev_history, defaults.keymaps.prev_history)
        assert.equals(conf.keymaps.next_history, defaults.keymaps.next_history)
        assert.equals(conf.keymaps.pattern_toggle, defaults.keymaps.pattern_toggle)
        assert.equals(conf.search.size, consts.sizes.large)
        assert.equals(conf.search.theme, defaults.search.theme)
        assert.equals(conf.logging.level, log_levels.INFO)
    end)

    it('only converts search size leaving everything else untouched', function ()
        local p = parser:new()
        local search = {
            name = "test",
            size = sizes.FULL,
            whoknows = 2.0
        }
        search = p:convert_search_section(search)
        assert.equals(search.size, consts.sizes.full)
        assert.equals(search.name, "test")
        assert.equals(search.whoknows, 2.0)

        search = {
            name = "test2",
            size = sizes.XL,
            whoknows = {}
        }
        search = p:convert_search_section(search)
        assert.equals(search.size, consts.sizes.xl)
        assert.equals(search.name, "test2")
        assert.same(search.whoknows, {})

        search = {
            size = sizes.LARGE,
        }
        search = p:convert_search_section(search)
        assert.equals(search.size, consts.sizes.large)

        search = {
            size = sizes.MED,
        }
        search = p:convert_search_section(search)
        assert.equals(search.size, consts.sizes.medium)

        search = {
            size = sizes.SMALL,
        }
        search = p:convert_search_section(search)
        assert.equals(search.size, consts.sizes.small)

        search = {
            size = sizes.XS,
        }
        search = p:convert_search_section(search)
        assert.equals(search.size, consts.sizes.xs)

    end)

    it('can handle a full override', function ()
        logging_or = {
            level = log_levels.DEBUG
        }

        search_bar_or = {
           size = sizes.FULL,
        }
        local tog_or = "a"
        local foc_or = "b"
        local clr_or = "d"
        local prev_or = "c"
        local next_or = "e"
        local prev_h_or = "f"
        local next_h_or = "g"
        local cs_or = "h"
        local pat_or = "i"
        local curr_word_search_or = "9"

        local keymap_or = {
            toggle_search = tog_or,
            toggle_focus = foc_or,
            clear_search = clr_or,
            prev_result = prev_or,
            next_result = next_or,
            prev_history = prev_h_or,
            next_history = next_h_or,
            search_curr_word = curr_word_search_or,
            case_sensitive_toggle = cs_or,
            pattern_toggle = pat_or,
        }

        theme_or = {
            border_type = 4,
            colorscheme = "onedark"
        }
        options = {
            keymaps = keymap_or,
            search = search_bar_or,
            logging = logging_or,
            theme = theme_or
        }


        local p = parser:new(options)
        local conf = p:parse_config()
        conf.search.size = width_to_size(conf.search.size)
        assert.same(options, conf)
    end)

     it('parse_config properly calls convert_to_search_section', function ()
         local p = parser:new({search = {size = sizes.XS}})
         local parsed_conf = p:parse_config()
         assert.equals(parsed_conf.search.size, consts.sizes.xs)

         p = parser:new({search = {size = sizes.SMALL}})
         parsed_conf = p:parse_config()
         assert.equals(parsed_conf.search.size, consts.sizes.small)

         p = parser:new({search = {size = sizes.MED}})
         parsed_conf = p:parse_config()
         assert.equals(parsed_conf.search.size, consts.sizes.medium)

         p = parser:new({search = {size = sizes.LARGE}})
         parsed_conf = p:parse_config()
         assert.equals(parsed_conf.search.size, consts.sizes.large)

         p = parser:new({search = {size = sizes.XL}})
         parsed_conf = p:parse_config()
         assert.equals(parsed_conf.search.size, consts.sizes.xl)

         p = parser:new({search = {size = sizes.FULL}})
         parsed_conf = p:parse_config()
         assert.equals(parsed_conf.search.size, consts.sizes.full)

         p = parser:new({search = {size = 1002}}) --undefined should result in medium
         parsed_conf = p:parse_config()
         assert.equals(parsed_conf.search.size, consts.sizes.medium)

        p = parser:new() -- handles parsing no search section
        p.defaults = {
            keymaps = {
                toggle_search = '<leader>/',
                case_sensitive_toggle = 'M',
                next_result = 'r',
            },
            logging = {
                level = log_levels.INFO
            }
        }
        parsed_conf = p:parse_config()
        assert.same(parsed_conf.search, nil)
     end)
end)
