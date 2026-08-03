vim.loader.enable()

-- Set leader keys before plugins so mappings are correct
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

-- Disable netrw (oil replaces it) -- must be set before plugins load
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- [[ vim.pack build hooks ]]
-- Created before any vim.pack.add() calls (in lua/plugins/*) so they fire on install too
vim.api.nvim_create_autocmd("PackChanged", {
	callback = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		local plugin_dir = vim.fn.stdpath("data") .. "/site/pack/core/opt/" .. name

		if name == "nvim-treesitter" and (kind == "install" or kind == "update") then
			if not ev.data.active then
				vim.cmd.packadd("nvim-treesitter")
			end
			vim.cmd("TSUpdate")
		end

		if name == "telescope-fzf-native.nvim" and (kind == "install" or kind == "update") then
			vim.system({ "make" }, { cwd = plugin_dir }):wait()
		end
	end,
})

-- [[ Core config ]]
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- [[ Plugins (explicit load order) ]]
require("plugins.colorscheme")
require("plugins.treesitter")
require("plugins.completion")
require("plugins.lsp")

-- Language-specific
require("plugins.lang.latex")
require("plugins.lang.haskell")
require("plugins.lang.swift")

-- editing sets up mini.nvim + mini.icons before icon consumers (navigation, ui)
require("plugins.editing")
require("plugins.navigation")
require("plugins.git")
require("plugins.ui")
require("plugins.markdown")
