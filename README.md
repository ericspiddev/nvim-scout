# :mag: Nvim-Scout
A neovim searchbar with enhanced options for finding text quicker within the same file

## :question: What is Nvim-Scout
Nvim-Scout is a neovim extension that enhances same-file search functionality
within neovim. It adds a UI searchbar that follows you across tabs and windows
while open so you can always have your last search without having to retype it.
If you no longer wish to see it you can simply toggle the bar and it's hidden
until you decide to search again :)

<div align="center">
  <img src="https://raw.githubusercontent.com/ericspiddev/nvim-scout/images/v1/nvim-scout.gif" />
</div>

*The side window that shows how scout can resize is not part of scout but is [neotree](https://github.com/nvim-neo-tree/neo-tree.nvim)*

### Features of Nvim-Scout
- Easily can be opened/closed
- Follows through tab/window transition
- Keeps last buffer focus when swapping between windows
- Search Modes for different searching use cases
- Match indexes to show how many matches the current file holds
- Holds history of up to 100 of your last searches (in a session)
- Can grab highlighted words or sections and search for them
- Finds the closest match to your spot in the file first
- Resizes when the window it's searching in resizes
- Blocks buffer opens and moves to searching window (good for telescope)
- Switchable focus between searchbar and buffer window being searched
- Fully customizable keymappings, config and log settings
- Customizable and extendable themes
- More to come....

## :blue_book: Nvim-Scout Table of Contents
- [Getting Started](#rocket-getting-started)
- [Nvim Scout Default Keymaps](#abcd-nvim-scout-default-keymaps)
- [Nvim Scout Search Modes](#gear-nvim-scout-search-modes)
- [Nvim Scout Colorschemes](#art-nvim-scout-colorschemes)
- [Nvim Scout Full Config](#wrench-nvim-scout-full-config)


## :rocket: Getting Started
Installing this plugin is done via lazy and all testing for this
extension was done on NVIM v0.11.4. It may work for earlier versions
but I cannot guarantee that and have not tested it myself

NOTE: as of right now no packer support is planned as the project has been
deemed deprecated

### TLDR
Use this config and reference the [Default Keymaps](#default-keymaps) for the
quickest setup.

```lua
return {
    "ericspiddev/nvim-scout",
    opts = {}
}
```


### Configuring Nvim-Scout
For customizing your application further then a minimal customization the config
can look something like this. Each section of configuration is represented in the
config below. For examples with all of the enums see the full default config

```lua
return {
    "ericspiddev/nvim-scout",
    opts = function()
        local config_options = require('nvim-scout.config.config_options') -- access to enums
        return {
            logging = {
                level = config_options.scout_log_level.WARNING
            },
            search = {
                size = config_options.scout_sizes.LARGE
            },
            keymaps = {
                toggle_search = "<leader>?",
                next_entry = "<UP>",
            },
            theme = {
                border_type = config_options.border_types.ASCII,
                colorscheme = "onedark"
            }
        }
    end,
}
```

## :abcd: Nvim-Scout Default Keymaps
For those who don't care and just want to get started using it. Copy the minimal
config above and use the default keymappings to get started happy searching!
*(Locality defines where the keypress takes effect Scout refers to when the searchbar
is the current nvim buffer)*
| Keymap | Mode | Config Var | Action | Locality |
| --- | --- |--- | --- |--- |
| / | n | toggle_search | Toggles the searchbar | Global |
| f | n | toggle_focus | Toggles focus between searchbar and buffer | Global |
| # | n | search_curr_word | Grab current word and move it to searchbar | Global |
| # | v | search_curr_word | Grab current selection and move it to searchbar | Global |
| n | n | next_result | Go to the next match of the current search | Scout |
| N | n | prev_result | Go to the previous match of the current search | Scout |
| c | n | clear_search | Clear searchbar contents | Scout |
| \<UP\> | n | prev_history | Move forward through history | Scout |
| \<DOWN\> | n | next_history | Move backward through history | Scout |
| \<leader\>c| n | case_senstive_toggle |Toggle Match Case Mode | Scout |
| \<leader\>r| n | pattern_toggle |Toggle Lua Pattern Mode | Scout |

For changing these mappings see the example config above and the full config.

## :gear: Nvim-Scout Search Modes
A variety of search modes can be toggled on and off while using Scout. The details
of those modes are laid out below

- <ins>*Match Case*:</ins> Only highlight matches that have the exact case specifed in the
contents of the searchbar if this mode is off all searchs are case insensitive

- <ins>*Lua Pattern*:</ins> This mode allows you to search your buffer using Lua's Pattern engine. If you
are not familiar with those I recommend reading this [section](https://www.lua.org/pil/20.2.html)
in the free book *Programming in Lua*. Some quick examples are as follows:


<ins>Lua Pattern Examples</ins>
1. `\[node\]` - highlights any of the letters n, o, d or e at any point in the buffer
2. `test.*` - highlights test and anything after it on the same line
3. `%u` - find all upper case letters in a file

There are many more patterns that can be a lot more useful and they all can be used in
nvim-scout's lua pattern mode! Anything invalid will display Invalid Pattern in the
searchbar text and captures are disabled as their use makes little sense for this purpose


## :art: Nvim-Scout Colorschemes
Scout comes with the option to use either premade colorschemes or create your own
A colorscheme is a table of `vim.api.keyset.highlight` objects that can set various
colors and styles within scout. The resulting table has each key passed in to the
`nvim_set_hl` call so for all supported options see the neovim documentation here.
As an example here is the default colorscheme of scout which just links to default
hl_groups in neovim.

```lua

-- Default neovim colorscheme
local default_name = "defaults"

local default = {
    search_border_color = { link="FloatBorder", default = true },
    search_title_color = { link="FloatTitle", default = true },
    mode_case_title_color = { link="WarningMsg", default = true },
    mode_case_border_color = { link="FloatBorder", default = true },
    mode_pat_title_color = { link="MoreMsg", default = true },
    mode_pat_border_color = { link="FloatBorder", default = true },
    mode_virt_text_color = { link="FloatTitle", default = true },
    scout_g_search_result = {link="Search", default= true},
    scout_g_selected_result = {link="CurSearch", default= true}
}

Scout_Colorscheme:register_colorscheme(default_name, default)
```


For a colorscheme that defines it's own colors checkout out the
[onedark colorscheme](https://github.com/ericspiddev/nvim-scout/blob/master/lua/nvim-scout/themes/colorschemes/onedark.lua)
The location of the colorscheme at the moment is required to be in the same path
that `onedark.lua` and `default.lua` are found (`nvim-scout/lua/nvim-scout/themes/colorschemes/`)

### Colorscheme Variable Mappings

<div align="center">

| Variable | Descripiton |
| --- | ---|
| search_border_color | The border of the searchbar |
|search_title_color | The color of the Search title in the searchbar|
|mode_case_title_color | The "Match Case" text color|
|mode_case_border_color | The color of "Match Case" banner border |
|mode_pat_title_color | The "Lua Pattern" text color|
|mode_pat_border_color | The color of "Lua Pattern" banne border |
|mode_virt_text_color | The "mod" on each modes banner color |
|scout_g_search_result | The highlight color of matches NOT selected|
|scout_g_selected_result | The highlight color the cursor is on |

</div>

## :wrench: Nvim-Scout Full Config
The example configurations above provide a good base for different values you can
configure but they do not show the entire picture of what can be configured this
section aims to do just that. Fully layout all the settings you can tweak for Scout.
If anything is unclear and you'd like to learn more please create an issue. Here is
the full default Scout config
```lua
local config_options = require('nvim-scout.config.config_options')

logging_defaults = {
    level = config_options.scout_log_level.OFF
}

search_bar_defaults = {
   size = config_options.scout_sizes.MED,
}

keymap_defaults = {
    toggle_search = '/',
    toggle_focus = 'f',
    clear_search = 'c',
    search_curr_word = '#',
    prev_result = 'N',
    next_result = 'n',
    prev_history = '<UP>',
    next_history = '<DOWN>',
    case_sensitive_toggle = '<leader>c',
    pattern_toggle = '<leader>r',
}

theme_defaults = {
    border_type = config_options.border_types.ROUNDED,
    colorscheme = "default"
}

local config = {
    defaults = {
        keymaps = keymap_defaults,
        search = search_bar_defaults,
        logging = logging_defaults,
        theme = theme_defaults,
    }
}

```

### Config Tables
As can be seen above there are 4 nested tables that make up the full config
value.
<ins> Config Tables </ins>

- `keymaps`: any keymap's key scout supports is set through here see
the defaults for these are listed above and at [default keymaps](#)
- `search`: currently just used to set the size of the searchbar (may be
merged into themes at a later time)
- `logging`: used to set the log level nvim scout will print at while running I
do not recommend changing this above error unless you need to DEBUG especially
is very spammy.
- `theme`: sets the colorscheme and border type for the searchbar

To adjust any variable for those tables all you need to do is make a nested
table in the `opts` function of your configuration like shown below which
as an examples set's the colorscheme to `onedark` and toggle search key
to `S`.

```lua
... rest of config above
    opts = function()
        return {
            keymaps = {
                toggle_search = "S",
            },
            theme = {
                colorscheme = "onedark"
            }
    end
... rest of config below
```

### Config Options
Below you will find all the associated enum values that different keys in each table can
be set too. NOTE in order to use this you must include the line
`local config_options = require('nvim-scout.config.config_options')` at the top of your
opts function so you can access each entry with a `config_options.<ENUM_NAME>`.

#### Search Enums
*scout_sizes*: applies to the `search.size` variable
*Note that each percentage is in width of the current window size and resizes
dynamically*

<div align="center">

| Enum | Value |
| --- | --- |
| XS | 15% |
| SMALL | 20% |
| MED | 25% |
| LARGE | 30% |
| XL | 50% |
| FULL | 100% |

</div>


#### Theme Enums
*border_types*: applies to the `themes.border` variable

<div align="center">


| Enum | Value |
| --- | --- |
| SINGLE_BAR | {"┌", "─", "┐", "│", "┘", "─", "└", "│" } |
| DOUBLE_BAR | { "╔", "═","╗", "║", "╝", "═", "╚", "║" }|
| ROUNDED | { "╭", "─", "╮", "│", "╯", "─", "╰", "│" } |
| THICK | { "┏", "━", "┓", "┃", "┛", "━", "┗", "┃" } |
| ASCII | { "+", "-", "+", "\|", "+", "-", "+", "\|" } |
| MINIMAL | { " ", "─", " ", " ", " ", "─", " ", " " } |

</div>


#### Logger Enums
*scout_log_level*: applies to the `logging.level` variable


<div align="center">


| Enum | Value |
| --- | --- |
|DEBUG| Print all Scout logging messages |
| INFO | Print all Scout logging messages info or above |
| WARNING | Print all Scout logging messages warning or above |
| ERROR | Print only Scout logging erorr messages |
| OFF | Disable all Scout logging messages|


</div>
