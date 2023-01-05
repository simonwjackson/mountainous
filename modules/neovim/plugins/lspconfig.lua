local wk = require("which-key")
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  require "lsp_signature".on_attach({
    debug = false, -- set to true to enable debug logging
    log_path = vim.fn.stdpath("cache") .. "/lsp_signature.log", -- log dir when debug is on
    -- default is  ~/.cache/nvim/lsp_signature.log
    verbose = false, -- show debug line number

    bind = true, -- This is mandatory, otherwise border config won't get registered.
    -- If you want to hook lspsaga or other signature handler, pls set to false
    doc_lines = 10, -- will show two lines of comment/doc(if there are more than two lines in doc, will be truncated);
    -- set to 0 if you DO NOT want any API comments be shown
    -- This setting only take effect in insert mode, it does not affect signature help in normal
    -- mode, 10 by default

    max_height = 12, -- max height of signature floating_window
    max_width = 80, -- max_width of signature floating_window
    noice = false, -- set to true if you using noice to render markdown
    wrap = true, -- allow doc/signature text wrap inside floating_window, useful if your lsp return doc/sig is too long

    floating_window = true, -- show hint in a floating window, set to false for virtual text only mode

    floating_window_above_cur_line = true, -- try to place the floating above the current line when possible Note:
    -- will set to true when fully tested, set to false will use whichever side has more space
    -- this setting will be helpful if you do not want the PUM and floating win overlap

    floating_window_off_x = 1, -- adjust float windows x position.
    floating_window_off_y = 0, -- adjust float windows y position. e.g -2 move window up 2 lines; 2 move down 2 lines
    -- can be either number or function, see examples

    close_timeout = 4000, -- close floating window after ms when laster parameter is entered
    fix_pos = false, -- set to true, the floating window will not auto-close until finish all parameters
    hint_enable = false, -- virtual hint enable
    hint_prefix = "🐼 ", -- Panda for parameter, NOTE: for the terminal not support emoji, might crash
    hint_scheme = "String",
    hi_parameter = "LspSignatureActiveParameter", -- how your parameter will be highlight
    handler_opts = {
      border = "rounded" -- double, rounded, single, shadow, none, or a table of borders
    },

    always_trigger = false, -- sometime show signature on new line or in middle of parameter can be confusing, set it to false for #58

    auto_close_after = nil, -- autoclose signature float win after x sec, disabled if nil.
    extra_trigger_chars = {}, -- Array of extra characters that will trigger signature completion, e.g., {"(", ","}
    zindex = 200, -- by default it will be on top of all floating windows, set to <= 50 send it to bottom

    padding = '', -- character to pad on left and right of signature can be ' ', or '|'  etc

    transparency = nil, -- disabled by default, allow floating win transparent value 1~100
    shadow_blend = 36, -- if you using shadow as border use this set the opacity
    shadow_guibg = 'Black', -- if you using shadow as border use this set the color e.g. 'Green' or '#121315'
    timer_interval = 200, -- default timer check interval set to lower value if you want to reduce latency
    toggle_key = nil, -- toggle signature on and off in insert mode,  e.g. toggle_key = '<M-x>'

    select_signature_key = nil, -- cycle to next signature, e.g. '<M-n>' function overloading
    move_cursor_key = nil, -- imap, use nvim_set_current_win to move cursor between current win and floating
  }, bufnr)

  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = { noremap = true, silent = true, buffer = bufnr }

  wk.register({
    K = { vim.lsp.buf.hover, "Do hover", unpack(bufopts) },
    ["<C>k"] = { vim.lsp.buf.signature_help, "Show signature", unpack(bufopts) },
    g = {
      D = { vim.lsp.buf.type_definition, "Go to type definition", unpack(bufopts) },
      d = { vim.lsp.buf.definition, "Go to definition", unpack(bufopts) },
      i = { vim.lsp.buf.implementation, "Go to implimentation", unpack(bufopts) },
      r = { ":Telescope lsp_references<cr>", "Go to references", unpack(bufopts) },
    },
    ['<leader>'] = {
      rn = { vim.lsp.buf.rename, "Rename symbol", unpack(bufopts) },
      c = {
        a = { vim.lsp.buf.code_action, "code actions", unpack(bufopts) },
        d = { vim.diagnostic.open_float, "code diagnostics", unpack(bufopts) },
      }
    }
  })
end

require 'lspconfig'.bashls.setup({
  on_attach = on_attach,
  capabilities = capabilities,
})

require 'lspconfig'.vimls.setup({
  on_attach = on_attach,
  capabilities = capabilities,
})

require 'lspconfig'.eslint.setup({
  on_attach = on_attach,
  capabilities = capabilities,
})

require 'lspconfig'.jsonnet_ls.setup {
  capabilities = capabilities,
}

require 'lspconfig'.sumneko_lua.setup {
  capabilities = capabilities,
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = { 'vim' },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
    },
  },
}

require 'lspconfig'.tailwindcss.setup({
  on_attach = on_attach,
  capabilities = capabilities,
})

require('lspconfig')['tsserver'].setup {
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = { "typescript", "typescriptreact", "typescript.tsx" },
}

require('lspconfig')['jsonls'].setup {
  on_attach = on_attach,
  capabilities = capabilities,
}

require('lspconfig')['html'].setup {
  on_attach = on_attach,
  capabilities = capabilities,
}

require('lspconfig').nil_ls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = { "nix" },
  settings = {
    ["nil"] = {
      formatting = {
        command = { "nixpkgs-fmt" }
      }
    }
  },
}

local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

vim.diagnostic.config({
  virtual_text = {
    prefix = '●',
  }
})

-- show border around diagnostic popup
vim.diagnostic.config {
  float = { border = "rounded" },
}

-- hide inline errors/warnings
vim.diagnostic.config({ virtual_text = false })

vim.cmd([[
  autocmd CursorHold * lua vim.diagnostic.open_float()
]])

vim.defer_fn(function()
  vim.api.nvim_set_hl(0, 'LspSignatureActiveParameter', { fg = require("dracula").colors().purple, bg = "NONE", })
end, 1000)
