-- Plugins added from several modules. Specs must be identical everywhere, otherwise
-- each vim.pack.add() rewrites the lockfile `version` on every startup.
return {
	-- No usable release: v0.1.4 (2023) warns about deprecated APIs on Neovim 0.12.
	plenary = "https://github.com/nvim-lua/plenary.nvim",
	-- The `stable` branch tracks mini.nvim releases (as recommended upstream).
	mini = { src = "https://github.com/nvim-mini/mini.nvim", version = "stable" }
}
