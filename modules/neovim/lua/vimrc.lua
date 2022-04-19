local actions = require('telescope.actions')



function Project_Files ()
    local opts = {} -- define here if you want to define something
    local ok = pcall(require"telescope.builtin".git_files, opts)
    if not ok then require"telescope.builtin".find_files(opts) end
end

require('telescope').load_extension('coc')

--require('auto-session').setup {
--auto_session_enable_last_session=true,
--    }

require("todo-comments").setup {
    keywords = {
        FIX = {
            icon = " ", -- icon used for the sign, and in search results
            color = "error", -- can be a hex color, or a named color (see below)
            alt = { "FIXME", "BUG", "FIXIT", "FIX", "ISSUE" }, -- a set of other keywords that all map to this FIX keywords
            -- signs = false, -- configure signs for some keywords individually
        },
        TODO = { icon = " ", color = "info" },
        HACK = { icon = " ", color = "warning" },
        WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
        PERF = { icon = " ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
        NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
    }
}


-- require("trouble").setup {}
