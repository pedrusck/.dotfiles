return {
	on_attach = function()
		-- Optional: installed by plugins/lsp.lua, which may have failed to load it
		local ok, ltex_extra = pcall(require, "ltex_extra")
		if not ok then
			return
		end
		ltex_extra.setup {
			load_langs = { "ca-Es", "de-DE", "en-US", "es" },
			path = ".ltex"
		}
	end,
	settings = {
		ltex = {
			checkFrequency = "save",
			enabled = { "markdown", "plaintex", "rst", "tex", "latex" },
			language = "en-US"
		}
	}
}
