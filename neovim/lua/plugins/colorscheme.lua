vim.pack.add {
	"https://github.com/ellisonleao/gruvbox.nvim"
}

-- Only the deviations from gruvbox.nvim's defaults are set here; everything else
-- (italics, undercurl, terminal_colors, transparency, …) is left at the plugin
-- default intentionally.
require("gruvbox").setup {
	contrast = "hard"
}

vim.cmd.colorscheme("gruvbox")
