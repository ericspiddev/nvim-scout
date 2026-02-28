local logger = require('nvim-scout.lib.scout_logger')
config_options = {}

config_options.scout_sizes = {
    XS = 0,
    SMALL = 1,
    MED = 2,
    LARGE = 3,
    XL = 4,
    FULL = 5
}

config_options.scout_themes = {
    DEFAULT = 0,
}
config_options.border_types = {
    SINGLE_BAR = 0,
    DOUBLE_BAR = 1,
    ROUNDED = 2,
    THICK = 3,
    ASCII = 4,
    MINIMAL = 5,
}

config_options.scout_log_level = logger.LOG_LEVELS

return config_options
