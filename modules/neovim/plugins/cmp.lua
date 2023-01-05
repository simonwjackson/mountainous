local cmp = require 'cmp'
local border = cmp.config.window.bordered({
  -- INFO: https://github.com/hrsh7th/nvim-cmp/issues/671#issuecomment-1189019119
  winhighlight = "Normal:Normal,FloatBorder:BorderBG,CursorLine:PmenuSel,Search:None",
  col_offset = -3,
  side_padding = 0,
})

cmp.setup({
  snippet = {
    -- REQUIRED - you must specify a snippet engine
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  window = {
    completion = border,
    documentation = border,
  },
  formatting = {
    fields = { "kind", "abbr", "menu" },
    format = function(entry, vim_item)
      local kind = require("lspkind").cmp_format({ mode = "symbol_text", maxwidth = 50 })(entry, vim_item)
      local strings = vim.split(kind.kind, "%s", { trimempty = true })
      kind.kind = " " .. (strings[1] or "") .. " "
      kind.menu = "    (" .. (strings[2] or "") .. ")"

      return kind
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'nvim_lua' },
    { name = 'zsh' },
    {
      name = 'tmux',
      option = {
        -- Source from all panes in session instead of adjacent panes
        all_panes = false,

        -- Completion popup label
        label = '[tmux]',

        -- Trigger character
        trigger_characters = { '.' },

        -- Specify trigger characters for filetype(s)
        -- { filetype = { '.' } }
        trigger_characters_ft = {},

        -- Keyword patch mattern
        keyword_pattern = [[\w\+]],
      }
    },
    { name = 'emoji' },
    { name = "copilot", group_index = 2 },
    {
      name = 'spell',
      option = {
        keep_all_entries = false,
        enable_in_context = function()
          return true
        end,
      },
    },
  }, {
    { name = 'buffer' },
  })
})

-- Set configuration for specific filetype.
cmp.setup.filetype('gitcommit', {
  sources = cmp.config.sources({
    { name = 'cmp_git' },
  }, {
    { name = 'buffer' },
  })
})

-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline({ '/', '?' }, {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = 'buffer' }
  }
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = 'path' },
    --{ name = 'cmdline_history' },
  }, {
    { name = 'cmdline' }
  })
})

for _, cmd_type in ipairs({ '/', '?', '@' }) do
  cmp.setup.cmdline(cmd_type, {
    sources = {
      { name = 'cmdline_history' },
    },
  })
end

-- TODO: zsh needs zmodload zsh/zpty
-- require 'cmp_zsh'.setup {
--   zshrc = true, -- Source the zshrc (adding all custom completions). default: false
--   filetypes = { "deoledit", "zsh" } -- Filetypes to enable cmp_zsh source. default: {"*"}
-- }

-- vim.opt.spell = true
vim.opt.spelllang = { 'en_us' }

-- INFO: https://github.com/hrsh7th/nvim-cmp/issues/671#issuecomment-1189019119
vim.defer_fn(function()
  vim.api.nvim_set_hl(0, 'BorderBG', {
    -- WARN: Color will be incorrect if theme switches
    fg = require("dracula").colors().comment,
    bg = "NONE",
  })
end, 1000)
