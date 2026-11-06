return {
	on_attach = function()
		require("ltex_extra").setup({
			load_langs = { "ca-Es", "de-DE", "en-US", "es" },
			path = ".ltex",
		})
	end,
	settings = {
		ltex = {
			checkFrequency = "save",
			enabled = { "markdown", "plaintex", "rst", "tex", "latex" },
			language = "en-US",
		},
	},
}
