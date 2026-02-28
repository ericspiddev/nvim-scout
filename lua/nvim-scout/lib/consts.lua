 local constants = {
     window = {
        INVALID_WINDOW_ID = -1,
        CURRENT_WINDOW = 0,
     },
     test = {
         async_delay = 10,
     },
     events = {
        WINDOW_ENTER_EVENT = "WinEnter",
        WINDOW_LEAVE_EVENT = "WinLeave",
        WINDOW_RESIZED = "WinResized",
        BUFFER_ENTER = "BufEnter",
        WINDOW_CLOSED = "WinClosed",
        QUIT_PRE_HOOK = "QuitPre",
        TAB_ENTER_EVENT = "TabEnter",
        BUFFER_WIN_LEAVE = "BufWinLeave"
     },
     position = {
        ROW_INDEX = 1,
        COL_INDEX = 2,
     },
     buffer = {
        CURRENT_BUFFER = 0,
        INVALID_BUFFER = -1,
        NO_CONTEXT = -1,
        EMPTY_BUFFER = {},
        SCRATCH_BUFFER = true,
        LIST_BUFFER = true,
        VALID_LUA_EVENTS = {"on_lines", "on_bytes", "on_changedtick", "on_detach", "on_reload"}
     },
     highlight = {
         NO_WORD_COUNT_EXTMARK = -1,
         SCOUT_NAMESPACE = "SCOUT",
         MATCH_HIGHLIGHT = "Search",
         CURR_MATCH_HIGHLIGHT = "WildMenu" --CurSearch",
     },
     virt_text = {
         no_matches = "No Matches",
         invalid_pattern = "Invalid Pattern"
     },
     search = {
        FORWARD = 1,
        BACKWARD = -1,
        search_name = "[SCOUT]",
        max_results = 10001,
        virt_text_hl = "Comment",
        search_top_text = "Search",
        default_scheme = "default"
     },
     lines = {
         START = 0,
         END = -1,
     },
     cmds = {
        CENTER_SCREEN = "norm! zz"
     },
     history = {
        MAX_ENTRIES = 100,
     },
     modes = {
         case_sensitive = "CASE_SENSITIVE",
         lua_pattern = "PATTERN",
         escape_chars = {")", "("},
         banner_gap = 2,
         case_sensitive_color = "#F18A85",
         pattern_color = "#007FFF",
         padding_space = 2,
     },
     sizes = {
         xs = 0.15,
         small = 0.20,
         medium = 0.25,
         large = 0.30,
         xl = 0.50,
         full = 1.0
     },
     colorscheme_groups = {
        s_border_c = "search_border_color",
        s_title_c = "search_title_color",
        m_case_title_c = "mode_case_title_color",
        m_case_border_c = "mode_case_border_color",
        m_pat_title_c = "mode_pat_title_color",
        m_pat_border_c = "mode_pat_border_color",
        m_virt_text_c = "mode_virt_text_color",
        search_result = "scout_g_search_result",
        selected_result = "scout_g_selected_result",
     }
 }

 return constants
