vim.loader.enable()

-- Set leader keys before plugins so mappings are correct
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

-- [[ Core config ]]
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- OpenCode uses the shared base with plugin-free overrides.
if vim.env.OPENCODE == "1" or vim.env.OPENCODE_TERMINAL == "1" then
	vim.opt.loadplugins = false
	require("config.minimal")
	return
end

local pack = require("config.pack")

-- [[ vim.pack build hooks ]]
-- Created before any vim.pack.add() calls (in lua/plugins/*) so they fire on install too
pack.setup_hooks(require("plugins.hooks").callbacks)
pack.setup_commands()

-- [[ Plugins (explicit load order) ]]
-- Each module lists its own hard dependencies; a failing module is reported as a
-- warning and the remaining ones still load. oil (navigation) disables netrw itself.
local modules = {
	"plugins.treesitter",
	-- completion before lsp so blink.cmp's capabilities apply to servers
	"plugins.completion",
	"plugins.lsp",

	-- Language-specific
	"plugins.lang.latex",
	"plugins.lang.haskell",
	"plugins.lang.swift",

	-- editing sets up mini.icons before icon consumers (navigation, ui)
	"plugins.editing",
	"plugins.navigation",
	"plugins.git",
	"plugins.ui",
	"plugins.markdown"
}

if not pack.load("plugins.colorscheme") then
	vim.cmd.colorscheme("retrobox")
end

for _, mod in ipairs(modules) do
	pack.load(mod)
end
