local wk = require("which-key")
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

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

require('lspconfig')['vim'].setup({
  on_attach = on_attach,
  capabilities = capabilities,
})

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

require('lspconfig')['tsserver'].setup {
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = { "typescript", "typescriptreact", "typescript.tsx" },
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
