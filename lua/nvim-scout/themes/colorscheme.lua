local consts = require("nvim-scout.lib.consts")
local scout_colorscheme = {}
scout_colorscheme.__index = scout_colorscheme

function scout_colorscheme:init(namespace)
    if not namespace then
        Scout_Logger:error_print("Nil namespace for colorscheme using defaults")
        return
    end
    local obj = {
        namespace = namespace
    }
    return setmetatable(obj, self)
end

function scout_colorscheme:register_colorscheme(name, colorscheme)
    local new_scheme = {}
    if not self.namespace then
        Scout_Logger:error_print("Failed to register colorscheme because of nil namespace ", name)
        return
    end
    for _, key in pairs(consts.colorscheme_groups) do
        if colorscheme[key] == nil then
            Scout_Logger:warning_print("Missing key " .. key .. "for colorsheme ", colorscheme)
        elseif key:find("scout_g") then
            vim.api.nvim_set_hl(0, key, colorscheme[key]) -- make available for global use
        else
            vim.api.nvim_set_hl(self.namespace, key, colorscheme[key])
            new_scheme[key] = colorscheme[key]
        end
    end
    return new_scheme
end


return scout_colorscheme
