-- Plugin build/update hooks, run by config/pack.lua on PackChanged events.
-- Only defines functions: it must not add or load plugins, because it is required
-- before the first vim.pack.add() (which may install everything from the lockfile).
local M = {}

--- Compile telescope-fzf-native's C library.
---@param path string Plugin directory
---@return boolean ok
function M.build_fzf_native(path)
	if vim.fn.executable("make") == 0 then
		vim.notify("telescope-fzf-native: `make` not found; using telescope's Lua sorter", vim.log.levels.WARN)
		return false
	end
	local result = vim.system({ "make" }, { cwd = path, text = true }):wait()
	if result.code ~= 0 then
		vim.notify("telescope-fzf-native: build failed:\n" .. result.stderr, vim.log.levels.ERROR)
		return false
	end
	return true
end

--- Callbacks by plugin name, receiving PackChanged event data (`kind`, `path`, `active`, `spec`).
M.callbacks = {
	-- Parsers are installed by treesitter.lua on first install; only refresh them on update
	["nvim-treesitter"] = function(data)
		if data.kind ~= "update" then
			return
		end
		if not data.active then
			vim.cmd.packadd("nvim-treesitter")
		end
		vim.cmd("TSUpdate")
	end,

	["telescope-fzf-native.nvim"] = function(data)
		if data.kind == "install" or data.kind == "update" then
			M.build_fzf_native(data.path)
		end
	end
}

return M
