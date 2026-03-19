local config_options = require('nvim-scout.config.config_options')
local config = require('nvim-scout.config.config')

scout_config_parser = {}

scout_config_parser.__index = scout_config_parser

function scout_config_parser:new(user_options)
    local config_obj = {
        user_options = user_options,
        defaults = config.new().defaults
    }
     return setmetatable(config_obj, self)
end

function scout_config_parser:parse_config()
    local scout_config = self.defaults
    for section, _ in pairs(scout_config) do
        scout_config[section] = self:parse_config_section(section)
    end
    if scout_config.search then
        scout_config.search = self:convert_search_section(scout_config.search)
    end

    return scout_config
end

function scout_config_parser:parse_config_section(config_section)
    if self.user_options == nil or self.user_options[config_section] == nil then
        return self.defaults[config_section] -- defaults should be a HARD set table that can't change...
    end
    local user_section_opts = self.user_options[config_section]
    local settings = self.defaults[config_section]
    for option, _ in pairs(settings) do
        local user_override = user_section_opts[option]
        if user_override ~= nil then
            settings[option] = user_override
        end
    end

    return settings
end

function scout_config_parser:convert_search_section(search_conf)
    search_conf.size = size_to_percentage(search_conf.size)
    return search_conf
end

function size_to_percentage(size)
    local search_bar_sizes = config_options.scout_sizes

    if size == search_bar_sizes.XS then
        return Scout_Consts.sizes.xs
    elseif size == search_bar_sizes.SMALL then
        return Scout_Consts.sizes.small
    elseif size == search_bar_sizes.MED then
        return Scout_Consts.sizes.medium
    elseif size == search_bar_sizes.LARGE then
        return Scout_Consts.sizes.large
    elseif size == search_bar_sizes.XL then
        return Scout_Consts.sizes.xl
    elseif size == search_bar_sizes.FULL then
        return Scout_Consts.sizes.full
    else
        return Scout_Consts.sizes.medium
    end
end

return scout_config_parser
