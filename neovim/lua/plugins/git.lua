vim.pack.add {
	{ src = "https://github.com/lewis6991/gitsigns.nvim", version = vim.version.range("2.x") }
}

require("gitsigns").setup {
	-- Raw Git baselines contain ciphertext for git-crypt files, while buffers
	-- contain plaintext. Let Git attributes identify those files in any repo.
	-- After attribute changes, :Gitsigns detach then :Gitsigns attach rechecks.
	on_attach = function(bufnr)
		if require("config.git_attributes").is_git_crypt_file(bufnr) then
			return false
		end
	end,
	signs = {
		add = { text = "│" },
		change = { text = "│" },
		delete = { text = "_" },
		topdelete = { text = "‾" },
		changedelete = { text = "~" },
		untracked = { text = "┆" },
	},
	signcolumn = true,
	numhl = false,
	linehl = false,
	-- Non-default: inline word-level diff highlighting inside changed hunks.
	-- Deliberately on so partial-line edits are visible at a glance; the extra
	-- visual noise is an accepted trade-off.
	word_diff = true,
	watch_gitdir = { follow_files = true },
	auto_attach = true,
	attach_to_untracked = false,
	-- Current-line blame is off by default (kept unobtrusive). The opts/formatter
	-- below are intentionally preserved as a ready-to-enable template — flip
	-- `current_line_blame = true` to turn them on.
	current_line_blame = false,
	sign_priority = 6,
	update_debounce = 100,
	max_file_length = 40000,
	preview_config = {
		border = "single",
		style = "minimal",
		relative = "cursor",
		row = 0,
		col = 1,
	}
}
