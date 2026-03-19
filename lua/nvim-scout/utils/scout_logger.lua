scout_logger = {}
scout_logger.__index = scout_logger

function scout_logger:new(log_conf, log_function, error_log_function)
    obj = { log_level = log_conf.level, log_function = log_function, error_log = error_log_function}
    return setmetatable(obj, self)
end
scout_logger.LOG_LEVELS = {DEBUG = 0, INFO = 1, WARNING = 2, ERROR = 3, OFF = 4}

-------------------------------------------------------------
--- scout.scout.print: prints the message and optional variable
--- if the config scout.level is set to DEBUG
--- @msg: the message to print
--- @variable: optional variable to print
---
function scout_logger:debug_print(msg, variable)
    self:scout_print(self.LOG_LEVELS.DEBUG, "[SCOUT DBG]: ", msg, variable)
end

-------------------------------------------------------------
--- scout.info_print: prints the message and optional variable
--- only if the config scout.level is set to INFO
--- or less
--- @msg: the message to print
--- @variable: optional variable to print
---
function scout_logger:info_print(msg, variable)
    self:scout_print(self.LOG_LEVELS.INFO, "[SCOUT INFO]: ", msg, variable)
end

-------------------------------------------------------------
--- scout.warning_print: prints the message and optional variable
--- only if the config scout.level is set to WARNING
--- or less
--- @msg: the message to print
--- @variable: optional variable to print
---
function scout_logger:warning_print(msg, variable)
    self:scout_print(self.LOG_LEVELS.WARNING, "[SCOUT WARN]: ", msg, variable)
end

-------------------------------------------------------------
--- scout.error_print: prints the message and optional variable
--- always as it's meant to be used to notify an error to the
--- user
--- or less
--- @msg: the message to print
--- @variable: optional variable to print
---
function scout_logger:error_print(msg, variable)
    self:scout_print(self.LOG_LEVELS.ERROR, "[SCOUT ERR]: ", msg, variable)
end

-------------------------------------------------------------
--- scout.scout_print: prints the scout.message with a prefix
--- after checking if the current scout.level should print
--- if the level is greater then the message will print. The
--- passed in variable may be a table and will be inspected
--- before printing automatically
--- @level: the scout.level of the print message
--- @prefix: prefix appended to the message before printing
--- @msg: the message to print
--- @variable: the variable to print
---
function scout_logger:scout_print(level, prefix, msg, variable)
    variable = variable or {}
    local dbg_msg = prefix .. msg
    if self:check_logger_level(level) then
        if type(variable) == 'table' then
            if next(variable) ~= nil then
                dbg_msg = dbg_msg .. vim.inspect(variable)
            end

        elseif type(variable) == 'function' then
                dbg_msg = dbg_msg .. vim.inspect(variable)
        else
            dbg_msg = dbg_msg .. variable
        end
        if self.log_function == nil then
            vim.print("Unable to print, nil log function")
        elseif type(self.log_function) ~= 'function' then
            vim.print("Unable to print, internal log function is not a function type " .. type(self.log_function))
        else
            if level ~= self.LOG_LEVELS.ERROR then
                self.log_function(dbg_msg)
            else
                self.error_log(dbg_msg, vim.log.levels.ERROR) -- vim.notify
            end
        end
    end
end

-------------------------------------------------------------
--- scout.check_scout.level: checks whether or not the debug
--- message should print based on the passed in scout.level
--- if the level is greater then the message will print
--- @level: level of scout.to comapre against our set level
---
function scout_logger:check_logger_level(level)
    if level == nil then
        vim.print("Nil level ignoring")
        return false
    elseif type(level) ~= "number" then
        vim.print("Type is not number cannot compare")
        return false
    else
        return level >= self.log_level
    end
end

return scout_logger
