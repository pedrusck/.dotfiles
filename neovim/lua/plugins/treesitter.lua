vim.pack.add {
	-- Branch, not a version range: all release tags belong to the archived `master`
	-- branch, whose API is incompatible with the `main` rewrite used here
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" }
}

local ts_langs = {
	"bash", "c", "diff", "html", "javascript", "json", "kotlin",
	"lua", "markdown", "markdown_inline", "python", "query",
	"regex", "swift", "tsx", "typescript", "vim", "vimdoc", "yaml",
}

-- Install parsers (no-op if already installed)
require("nvim-treesitter").install(ts_langs)

-- Enable treesitter highlighting for all supported filetypes
vim.api.nvim_create_autocmd(
	"FileType",
	{
		callback = function(ev)
			if pcall(vim.treesitter.start, ev.buf) then
				-- Disable for large files (> 100 KB)
				local max_filesize = 100 * 1024
				local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(ev.buf))
				if ok and stats and stats.size > max_filesize then
					vim.treesitter.stop(ev.buf)
				end
			end
		end
	}
)
