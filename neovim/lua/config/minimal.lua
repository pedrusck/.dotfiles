-- OpenCode-only overrides, applied after the shared base configuration.
-- Disabling plugins does not exclude installed queries from runtime lookups.
-- Use bundled resources instead of user-site files blocked by the sandbox.
local site = vim.fn.stdpath("data") .. "/site"
vim.opt.runtimepath:remove { site, site .. "/after" }

vim.opt.showmode = true
vim.cmd.colorscheme("retrobox")

-- Bundled netrw is the exception to disabled automatic plugin loading.
vim.cmd("runtime plugin/netrwPlugin.vim")
vim.keymap.set("n", "-", "<cmd>Explore<CR>", { desc = "Open parent directory" })
