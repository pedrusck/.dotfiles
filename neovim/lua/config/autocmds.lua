local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Highlight yanked text
autocmd("TextYankPost", {
	desc = "Highlight when yanking text",
	group = augroup("YankHighlight", { clear = true }),
	callback = function()
		vim.hl.on_yank()
	end,
})

-- Markdown is delegated to rumdl so the editor and `rumdl fmt` cannot disagree,
-- and because two trailing spaces are a hard line break there. Everywhere else
-- only the trailing whitespace span itself is deleted, so that the cursor, the
-- jumplist, the search register, marks and extmarks stay valid.
local RUMDL_TIMEOUT_MS = 2000

--- Reformat a markdown buffer in place with `rumdl fmt`.
local function format_markdown(buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	-- Piped rather than formatted by path: the buffer is not on disk yet, may be
	-- unnamed, and may be written somewhere other than its own name.
	local ok, result = pcall(function()
		return vim.system({ "rumdl", "fmt", "-" }, { stdin = lines, text = true }):wait(RUMDL_TIMEOUT_MS)
	end)

	if not ok or result.code ~= 0 then
		local reason = ok and ("exit code " .. result.code) or tostring(result)
		vim.notify("rumdl could not format this buffer (" .. reason .. ")", vim.log.levels.WARN)
		return
	end

	-- Only the final newline is dropped: `trimempty` would also discard a leading
	-- blank line, which rumdl keeps
	local formatted = vim.split((result.stdout:gsub("\n$", "")), "\n")

	-- Compared first so that an already formatted buffer adds no undo state
	if not vim.deep_equal(formatted, lines) then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, formatted)
	end
end

--- Delete the trailing whitespace of every line of a buffer.
local function trim_trailing_whitespace(buf)
	for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		local trimmed = line:gsub("%s+$", "")
		if trimmed ~= line then
			vim.api.nvim_buf_set_text(buf, i - 1, #trimmed, i - 1, #line, {})
		end
	end
end

autocmd("BufWritePre", {
	desc = "Trim trailing whitespace on save, format markdown with rumdl",
	group = augroup("TrimWhitespace", { clear = true }),
	pattern = "*",
	callback = function(ev)
		if not vim.bo[ev.buf].modifiable then
			return
		end

		if vim.bo[ev.buf].filetype == "markdown" then
			if vim.fn.executable("rumdl") == 1 then
				format_markdown(ev.buf)
			end
		else
			trim_trailing_whitespace(ev.buf)
		end
	end,
})

-- Wrap on diff
autocmd("FilterWritePre", {
	pattern = "*",
	command = "if &diff | setlocal wrap< | endif",
})

-- Markdown settings
autocmd("BufEnter", {
	pattern = "*.md",
	callback = function()
		vim.opt_local.conceallevel = 1
		vim.opt_local.complete:append("kspell")
	end,
})

-- Git commit kspell completion
autocmd("FileType", {
	pattern = "gitcommit",
	callback = function()
		vim.opt_local.complete:append("kspell")
	end,
})

-- Filetype detection
vim.filetype.add({
	pattern = {
		[".*openapi.*%.ya?ml"] = "yaml.openapi",
		[".*openapi.*%.json"] = "json.openapi",
		[".*/git/.*config.*"] = "gitconfig",
	},
})

-- GitLab CI filetype
autocmd({ "BufRead", "BufNewFile" }, {
	pattern = "*.gitlab-ci*.{yml,yaml}*",
	callback = function()
		vim.bo.filetype = "yaml.gitlab"
	end,
})

-- Regenerate spell files on startup
local spell_dir = vim.fn.stdpath("config") .. "/spell"
for _, f in ipairs(vim.fn.glob(spell_dir .. "/*.add", false, true)) do
	if
		vim.fn.filereadable(f) == 1
		and (vim.fn.filereadable(f .. ".spl") == 0 or vim.fn.getftime(f) > vim.fn.getftime(f .. ".spl"))
	then
		vim.cmd("mkspell! " .. vim.fn.fnameescape(f))
	end
end
