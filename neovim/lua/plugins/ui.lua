-- Presentation: statusline, indent guides, keybinding discovery, TODO highlights.
local pack = require("config.pack")
local specs = require("plugins.specs")

-- Statusline (mini.statusline; mini.icons is set up in editing.lua when available)
pack.safely(
	"Statusline setup",
	function()
		vim.pack.add { specs.mini }

		local statusline = require("mini.statusline")
		statusline.setup { use_icons = vim.g.have_nerd_font }

		-- Show cursor location as LINE:COLUMN
		---@diagnostic disable-next-line: duplicate-set-field
		statusline.section_location = function()
			return "%2l:%-2v"
		end
	end
)

-- Indent guides
pack.safely(
	"Indent guides setup",
	function()
		vim.pack.add {
			{ src = "https://github.com/lukas-reineke/indent-blankline.nvim", version = vim.version.range("3.x") }
		}

		require("ibl").setup {
			indent = { char = "▏" },
			scope = { enabled = false }
		}
	end
)

-- Keybinding discovery popup; registers the <leader> namespace group labels.
-- Deferred: only needed once a key sequence is pending.
pack.later(
	"which-key setup",
	function()
		vim.pack.add {
			{ src = "https://github.com/folke/which-key.nvim", version = vim.version.range("3.x") }
		}

		require("which-key").setup {
			delay = 300,
			icons = { mappings = vim.g.have_nerd_font }
		}

		require("which-key").add {
			{ "<leader>f", group = "Find" },
			{ "<leader>b", group = "Buffer" },
			{ "<leader>h", group = "Harpoon" },
			{ "<leader>c", group = "Code" },
			{ "<leader>cw", group = "Workspace" },
			{ "<leader>x", group = "Diagnostics" },
			{ "<leader>s", group = "Spell" },
			{ "<leader>m", group = "Move" }
		}
	end
)

-- Highlight TODO/NOTE/WARN comments. Deferred: on setup it highlights all
-- already-open windows, so buffers opened at startup are covered too.
pack.later(
	"todo-comments setup",
	function()
		vim.pack.add {
			specs.plenary,
			{ src = "https://github.com/folke/todo-comments.nvim", version = vim.version.range("1.x") }
		}

		require("todo-comments").setup { signs = false }
	end
)
