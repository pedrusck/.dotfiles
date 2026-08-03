-- mini.nvim is already added in editing.lua (and mini.icons set up there).
-- Statusline lives here as a presentation concern.
vim.pack.add({
	"https://github.com/lukas-reineke/indent-blankline.nvim",
	"https://github.com/folke/todo-comments.nvim",
	"https://github.com/folke/which-key.nvim",
})

-- Keybinding discovery popup; registers the <leader> namespace group labels.
require("which-key").setup({
	delay = 300,
	icons = { mappings = vim.g.have_nerd_font },
})
require("which-key").add({
	{ "<leader>f", group = "Find" },
	{ "<leader>b", group = "Buffer" },
	{ "<leader>h", group = "Harpoon" },
	{ "<leader>c", group = "Code" },
	{ "<leader>cw", group = "Workspace" },
	{ "<leader>x", group = "Diagnostics" },
	{ "<leader>s", group = "Spell" },
	{ "<leader>m", group = "Move" },
})

-- Statusline (mini.statusline)
local statusline = require("mini.statusline")
statusline.setup({ use_icons = vim.g.have_nerd_font })

-- Show cursor location as LINE:COLUMN
---@diagnostic disable-next-line: duplicate-set-field
statusline.section_location = function()
	return "%2l:%-2v"
end

-- Indent guides
require("ibl").setup({
	indent = { char = "▏" },
	scope = { enabled = false },
})

-- Highlight TODO/NOTE/WARN comments
require("todo-comments").setup({ signs = false })
