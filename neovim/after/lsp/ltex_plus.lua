return {
	on_attach = function()
		-- Optional: installed by plugins/lsp.lua, which may have failed to load it
		local ok, ltex_extra = pcall(require, "ltex_extra")
		if not ok then
			return
		end
		ltex_extra.setup({
			load_langs = { "ca-ES", "de-DE", "en-US", "es-ES" },
			path = ".ltex",
		})
		require("config.ltex").canonical_files()
	end,
	settings = {
		ltex = {
			checkFrequency = "save",
			-- nvim-lspconfig maps plaintex -> tex, tex -> latex, rst -> restructuredtext.
			enabled = { "markdown", "plaintex", "rst", "tex", "latex", "restructuredtext" },
			language = "en-US",
		},
	},
}
