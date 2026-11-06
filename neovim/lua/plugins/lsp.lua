vim.pack.add({
	"https://github.com/mason-org/mason.nvim",
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/barreiroleo/ltex-extra.nvim",
})

require("mason").setup()

-- Mason installs executables; nvim-lspconfig supplies the server definitions.
-- Installation is asynchronous: on a fresh machine, reopen the buffer or restart
-- Neovim after installation finishes. Uses Mason's registry API directly
-- (no mason-lspconfig / mason-tool-installer dependency). SourceKit ships with
-- Xcode and is invoked via `xcrun`, so it is intentionally excluded.
local ensure_installed = {
	"lua-language-server", -- lua_ls
	"taplo", -- taplo (TOML)
	"ruby-lsp", -- ruby_lsp
	"ltex-ls-plus", -- ltex_plus
	"vacuum", -- vacuum (OpenAPI)
	"gitlab-ci-ls", -- gitlab_ci_ls
	"kotlin-lsp", -- kotlin_lsp
}

-- Install any missing packages once mason's registry has refreshed.
local registry = require("mason-registry")
registry.refresh(function(success)
	if not success then
		return
	end
	for _, name in ipairs(ensure_installed) do
		local ok, pkg = pcall(registry.get_package, name)
		if ok and not pkg:is_installed() then
			pkg:install()
		end
	end
end)

-- Diagnostic config with custom sign icons
vim.diagnostic.config({
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "",
			[vim.diagnostic.severity.WARN] = "",
			[vim.diagnostic.severity.INFO] = "",
			[vim.diagnostic.severity.HINT] = "󰠠",
		},
		linehl = {
			[vim.diagnostic.severity.ERROR] = "Error",
			[vim.diagnostic.severity.WARN] = "Warn",
			[vim.diagnostic.severity.INFO] = "Info",
			[vim.diagnostic.severity.HINT] = "Hint",
		},
	},
})

-- LspAttach: only custom keymaps not built-in in 0.11+
-- (gd, gD, gi, K, [d, ]d, grn, gra are all built-in now)
vim.api.nvim_create_autocmd("LspAttach", {
	desc = "LSP Actions",
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(ev)
		local function opts(desc)
			return { buffer = ev.buf, desc = desc }
		end
		-- Code namespace (<leader>c*)
		vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, opts("Code: format"))
		vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts("Code: action"))
		vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, opts("Code: rename"))
		vim.keymap.set("n", "<leader>cwa", vim.lsp.buf.add_workspace_folder, opts("Code: add workspace folder"))
		vim.keymap.set("n", "<leader>cwr", vim.lsp.buf.remove_workspace_folder, opts("Code: remove workspace folder"))
		vim.keymap.set("n", "<leader>cwl", function()
			print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
		end, opts("Code: list workspace folders"))
	end,
})

-- Diagnostics namespace (<leader>x*)
vim.keymap.set("n", "<leader>xd", vim.diagnostic.open_float, { desc = "Diagnostics: float" })
vim.keymap.set("n", "<leader>xq", vim.diagnostic.setqflist, { desc = "Diagnostics: quickfix list" })
vim.keymap.set("n", "<leader>xl", vim.diagnostic.setloclist, { desc = "Diagnostics: location list" })

-- Native discovery merges nvim-lspconfig's lsp/ definitions with our after/lsp/
-- overrides before enabling servers.
vim.lsp.enable({
	"kotlin_lsp",
	"lua_ls",
	"ltex_plus",
	"vacuum",
	"ruby_lsp",
	"taplo",
	"gitlab_ci_ls",
	"sourcekit",
})
