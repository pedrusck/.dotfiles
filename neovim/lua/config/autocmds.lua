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

-- Remove trailing whitespace on save
autocmd("BufWritePre", {
	pattern = "*",
	command = [[%s/\s\+$//e]],
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
