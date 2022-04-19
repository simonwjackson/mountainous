local actions = require('telescope.actions')

require('telescope').setup{
    defaults = {
        mappings = {
            i = {
                ["<esc>"] = actions.close
            },
        },
        layout_strategy = "horizontal",
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
                    ["<c-d>"] = require("telescope.actions").delete_buffer,
                },
                n = {
                    ["<c-d>"] = require("telescope.actions").delete_buffer,
                }
            }
        },
        find_files = {
        },
    },
}
