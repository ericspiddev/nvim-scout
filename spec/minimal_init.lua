local logger = require('lua.nvim-scout.lib.scout_logger')
_G.Scout_Consts = require("lua.nvim-scout.lib.consts")

if _G.Scout_Logger == nil then
    _G.Scout_Logger = logger:new({level = logger.LOG_LEVELS.OFF}, vim.print)
end

