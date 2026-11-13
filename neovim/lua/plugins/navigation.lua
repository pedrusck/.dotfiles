local pack = require("config.pack")
local specs = require("plugins.specs")
local hooks = require("plugins.hooks")

-- Telescope
pack.safely(
	"Telescope setup",
	function()
		vim.pack.add {
			specs.plenary,
			{ src = "https://github.com/nvim-telescope/telescope.nvim", version = vim.version.range("*") },
			-- No releases; built by the PackChanged hook in plugins/hooks.lua
			"https://github.com/nvim-telescope/telescope-fzf-native.nvim"
		}

		require("telescope").setup()

		-- Recover from a missing build (e.g. `make` was unavailable when the plugin was installed)
		local fzf_native = vim.pack.get({ "telescope-fzf-native.nvim" }, { info = false })[1]

		local fzf_built = vim.uv.fs_stat(fzf_native.path .. "/build/libfzf.so") ~= nil or hooks.build_fzf_native(fzf_native.path)
		if fzf_built then
			pack.safely(
				"Loading telescope fzf extension",
				function()
					require("telescope").load_extension("fzf")
				end
			)
		end

		-- Find namespace (<leader>f*): Telescope pickers
		local builtin = require("telescope.builtin")
		vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find: files" })
		vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Find: by grep" })
		vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find: buffers" })
		vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Find: help" })
		vim.keymap.set("n", "<leader>fd", builtin.diagnostics, { desc = "Find: diagnostics" })
		vim.keymap.set("n", "<leader>fr", builtin.resume, { desc = "Find: resume" })
		vim.keymap.set("n", "<leader>fo", builtin.oldfiles, { desc = "Find: recent (old) files" })
		vim.keymap.set("n", "<leader>fw", builtin.grep_string, { desc = "Find: current word" })
		vim.keymap.set("n", "<leader>fk", builtin.keymaps, { desc = "Find: keymaps" })

		vim.keymap.set(
			"n",
			"<leader>fn",
			function()
				builtin.find_files { cwd = vim.fn.stdpath("config") }
			end,
			{ desc = "Find: Neovim config files" }
		)
	end
)

-- Harpoon
-- All maps live under the <leader>h* namespace (Space is the leader). This keeps
-- the entire Ctrl layer free for Neovim/shell defaults and avoids the Ctrl+h =
-- backspace (ASCII 0x08) ambiguity that plagues terminal apps.
--   <leader>ha  add file        <leader>he  toggle quick menu
--   <leader>h1..h4  select 1..4  <leader>hp / hn  previous / next
pack.safely(
	"Harpoon setup",
	function()
		vim.pack.add {
			specs.plenary,
			-- No releases; harpoon2 is a development branch
			{ src = "https://github.com/ThePrimeagen/harpoon", version = "harpoon2" }
		}

		local harpoon = require("harpoon")
		harpoon:setup()

		vim.keymap.set(
			"n",
			"<leader>ha",
			function()
				harpoon:list():add()
			end,
			{ desc = "Harpoon: add file" }
		)

		vim.keymap.set(
			"n",
			"<leader>he",
			function()
				harpoon.ui:toggle_quick_menu(harpoon:list())
			end,
			{ desc = "Harpoon: toggle quick menu" }
		)

		vim.keymap.set(
			"n",
			"<leader>h1",
			function()
				harpoon:list():select(1)
			end,
			{ desc = "Harpoon: select file 1" }
		)

		vim.keymap.set(
			"n",
			"<leader>h2",
			function()
				harpoon:list():select(2)
			end,
			{ desc = "Harpoon: select file 2" }
		)

		vim.keymap.set(
			"n",
			"<leader>h3",
			function()
				harpoon:list():select(3)
			end,
			{ desc = "Harpoon: select file 3" }
		)

		vim.keymap.set(
			"n",
			"<leader>h4",
			function()
				harpoon:list():select(4)
			end,
			{ desc = "Harpoon: select file 4" }
		)

		vim.keymap.set(
			"n",
			"<leader>hp", function()
				harpoon:list():prev()
			end,
			{ desc = "Harpoon: previous" }
		)

		vim.keymap.set(
			"n",
			"<leader>hn", function()
				harpoon:list():next()
			end,
			{ desc = "Harpoon: next" }
		)
	end
)

-- Oil (sole file explorer; its setup() disables netrw, which stays available if oil fails)
pack.safely(
	"Oil setup",
	function()
		vim.pack.add {
			{ src = "https://github.com/stevearc/oil.nvim", version = vim.version.range("2.x") }
		}

		require("oil").setup {
			view_options = {
				show_hidden = true
			}
		}

		vim.keymap.set("n", "-", require("oil").open, { desc = "Open parent directory" })
		vim.keymap.set("n", "<leader>e", "<cmd>Oil<CR>", { desc = "Open file explorer (oil)" })
	end
)

-- Undotree (not needed at startup)
pack.later(
	"Undotree setup", function()
		-- Default branch: latest release (rel_6.1) is from 2019
		vim.pack.add { "https://github.com/mbbill/undotree" }
		vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Undotree: toggle" })
	end
)
