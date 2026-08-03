-- haskell-tools.nvim configures itself via vim.g.haskell_tools; no setup() call.
vim.pack.add({
	{ src = "https://github.com/mrcjkb/haskell-tools.nvim", version = vim.version.range("4.x") },
})
