local telescope = require('telescope')
local actions = require('telescope.actions')

function Project_Files ()
    local opts = {} -- define here if you want to define something
    local ok = pcall(require"telescope.builtin".git_files, opts)
    if not ok then require"telescope.builtin".find_files(opts) end
end

telescope.setup{
    defaults = {
        mappings = {
            i = {
                ["<esc>"] = actions.close
            },
        },
        layout_strategy = "vertical",
        sorting_strategy = "ascending",
        layout_config = {
            horizontal = {
                mirror = false,
            },
            vertical = {
                mirror = true,
            },
        },
    },
    pickers = {
        -- Your special builtin config goes in here
        buffers = {
            sort_lastused = true,
            previewer = false,
            mappings = {
                i = {
                    ["<c-d>"] = actions.delete_buffer,
                },
                n = {
                    ["<c-d>"] = actions.delete_buffer,
                }
            }
        },
        find_files = {
        },
    },
}

require('telescope').load_extension('coc')
require("telescope").load_extension("git_worktree")

-- map("n", ",<Space>", ":nohlsearch<CR>", { silent = true })
-- map("n", "<Leader>", ":<C-u>WhichKey ','<CR>" { silent = true })
-- map("n", "<Leader>?", ":WhichKey ','<CR>")
-- map("n", "<Leader>a", ":cclose<CR>")

