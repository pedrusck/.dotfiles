local M = {}

local CHECK_TIMEOUT_MS = 250

local function is_git_crypt_driver(value)
	return value == "git-crypt" or value:match("^git%-crypt%-.+") ~= nil
end

--- Check effective Git attributes, including nested and local overrides.
--- Unknown attributes and failed checks allow Gitsigns to attach normally.
---@param bufnr integer
---@return boolean
function M.is_git_crypt_file(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
		return false
	end

	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		return false
	end

	-- Match Gitsigns' resolution of symlinked configuration files.
	path = vim.uv.fs_realpath(path) or path
	local filename = vim.fs.basename(path)
	local ok, result = pcall(
		function()
			return vim.system(
				{ "git", "check-attr", "-z", "filter", "diff", "--", filename },
				{ cwd = vim.fs.dirname(path), timeout = CHECK_TIMEOUT_MS }
			):wait(CHECK_TIMEOUT_MS)
		end
	)
	if not ok or result.code ~= 0 then
		return false
	end

	-- Expected: path\0filter\0value\0path\0diff\0value\0
	local fields = vim.split(result.stdout or "", "\0", { plain = true })
	if
		#fields ~= 7
		or fields[1] ~= filename
		or fields[2] ~= "filter"
		or fields[4] ~= filename
		or fields[5] ~= "diff"
		or fields[7] ~= ""
	then
		return false
	end

	return is_git_crypt_driver(fields[3]) or is_git_crypt_driver(fields[6])
end

return M
