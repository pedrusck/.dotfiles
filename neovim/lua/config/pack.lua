-- Helpers for vim.pack: error isolation, deferred loading, hook dispatch and :PackUpdate.
-- Deliberately plugin-free so it keeps working when any plugin fails to install or load.
-- Plugin-specific specs and hooks live in plugins/specs.lua and plugins/hooks.lua.
local M = {}

--- Run `f`, reporting errors as warnings instead of propagating them, so that one
--- broken plugin does not prevent the rest of the config from loading.
---@param what string
---@param f fun()
---@return boolean ok
function M.safely(what, f)
	local ok, err = pcall(f)
	if not ok then
		vim.notify(("%s failed:\n%s"):format(what, err), vim.log.levels.WARN)
	end
	return ok
end

---@param mod string
---@return boolean ok
function M.load(mod)
	return M.safely(
		"Loading " .. mod,
		function()
			require(mod)
		end
	)
end

--- Run `f` after startup (after VimEnter and the first redraw), with error isolation.
---@param what string
---@param f fun()
function M.later(what, f)
	vim.schedule(
		function()
			M.safely(what, f)
		end
	)
end

--- Run plugin hooks on PackChanged events. `hooks` maps plugin names to callbacks
--- receiving the event data (`kind`, `path`, `active`, `spec`).
--- Must run before the very first vim.pack.add() so hooks also fire for plugins
--- installed while bootstrapping from the lockfile.
---@param hooks table<string, fun(data: table)>
function M.setup_hooks(hooks)
	vim.api.nvim_create_autocmd(
		"PackChanged",
		{
			group = vim.api.nvim_create_augroup("PackHooks", { clear = true }),
			desc = "Run plugin hooks after vim.pack changes them",
			callback = function(ev)
				local name = ev.data.spec.name
				local hook = hooks[name]
				if not hook then
					return
				end
				-- An erroring install hook makes vim.pack treat the install as failed and delete the plugin
				M.safely(
					"PackChanged hook for " .. name,
					function()
						hook(ev.data)
					end
				)
			end
		}
	)
end

---@return string[]
local function installed_names()
	local names = vim.tbl_map(
		function(p)
			return p.spec.name
		end,
		vim.pack.get(nil, { info = false })
	)
	table.sort(names)
	return names
end

--- Update plugins via vim.pack's review buffer (`:w` applies, `:q` cancels).
--- Updates all plugins when `names` is empty.
---@param names string[]
function M.update(names)
	if #names > 0 then
		local installed = installed_names()
		local unknown = vim.tbl_filter(
			function(name)
				return not vim.tbl_contains(installed, name)
			end,
			names
		)
		if #unknown > 0 then
			vim.notify("PackUpdate: unknown plugin(s): " .. table.concat(unknown, ", "), vim.log.levels.ERROR)
			return
		end
	end
	M.safely(
		"PackUpdate",
		function()
			vim.pack.update(#names > 0 and names or nil)
		end
	)
end

function M.setup_commands()
	vim.api.nvim_create_user_command(
		"PackUpdate",
		function(opts)
			M.update(opts.fargs)
		end,
		{
			nargs = "*",
			desc = "Update vim.pack plugins (all, or the given names)",
			complete = function(arg_lead)
				return vim.tbl_filter(
					function(name)
						return vim.startswith(name, arg_lead)
					end,
					installed_names()
				)
			end,
			force = true
		}
	)
end

return M
