vim.pack.add({
	-- Shared dependencies (used by telescope, harpoon, oil)
	"https://github.com/nvim-lua/plenary.nvim",
	-- Telescope
	{ src = "https://github.com/nvim-telescope/telescope.nvim", version = "master" },
	"https://github.com/nvim-telescope/telescope-fzf-native.nvim",
	-- Harpoon
	{ src = "https://github.com/ThePrimeagen/harpoon", version = "harpoon2" },
	-- Oil
	"https://github.com/stevearc/oil.nvim",
	-- Undotree
	"https://github.com/mbbill/undotree",
})

-- Telescope
require("telescope").setup({})
pcall(require("telescope").load_extension, "fzf")

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
vim.keymap.set("n", "<leader>fn", function()
	builtin.find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Find: Neovim config files" })

-- Harpoon
-- All maps live under the <leader>h* namespace (Space is the leader). This keeps
-- the entire Ctrl layer free for Neovim/shell defaults and avoids the Ctrl+h =
-- backspace (ASCII 0x08) ambiguity that plagues terminal apps.
--   <leader>ha  add file        <leader>he  toggle quick menu
--   <leader>h1..h4  select 1..4  <leader>hp / hn  previous / next
local harpoon = require("harpoon")
harpoon:setup()

vim.keymap.set("n", "<leader>ha", function()
	harpoon:list():add()
end, { desc = "Harpoon: add file" })
vim.keymap.set("n", "<leader>he", function()
	harpoon.ui:toggle_quick_menu(harpoon:list())
end, { desc = "Harpoon: toggle quick menu" })
vim.keymap.set("n", "<leader>h1", function()
	harpoon:list():select(1)
end, { desc = "Harpoon: select file 1" })
vim.keymap.set("n", "<leader>h2", function()
	harpoon:list():select(2)
end, { desc = "Harpoon: select file 2" })
vim.keymap.set("n", "<leader>h3", function()
	harpoon:list():select(3)
end, { desc = "Harpoon: select file 3" })
vim.keymap.set("n", "<leader>h4", function()
	harpoon:list():select(4)
end, { desc = "Harpoon: select file 4" })
vim.keymap.set("n", "<leader>hp", function()
	harpoon:list():prev()
end, { desc = "Harpoon: previous" })
vim.keymap.set("n", "<leader>hn", function()
	harpoon:list():next()
end, { desc = "Harpoon: next" })

-- Oil (sole file explorer; netrw is disabled in init.lua)
require("oil").setup({
	view_options = {
		show_hidden = true,
	},
})
vim.keymap.set("n", "-", require("oil").open, { desc = "Open parent directory" })
vim.keymap.set("n", "<leader>e", "<cmd>Oil<CR>", { desc = "Open file explorer (oil)" })

-- Auto-open oil at the current working directory when nvim is started with no
-- arguments (bare `nvim`). Directory arguments (`nvim .` / `nvim <dir>`) are
-- handled natively by oil via `default_file_explorer = true`, so they are
-- intentionally skipped here. The open is deferred with `vim.schedule` so it
-- runs after VimEnter completes and oil has settled; opening synchronously in
-- the VimEnter callback races with oil's startup buffer and yields an empty
-- listing.
vim.api.nvim_create_autocmd("VimEnter", {
	group = vim.api.nvim_create_augroup("OilAutoOpen", { clear = true }),
	desc = "Open oil in cwd when starting with no file/dir arguments",
	callback = function()
		if vim.fn.argc() > 0 then
			return
		end
		-- Escape hatch: set `vim.g.oil_no_auto_open = true` (e.g. from an env-
		-- specific config or before launch) to suppress the bare-`nvim` auto-open.
		if vim.g.oil_no_auto_open then
			return
		end
		local buf = vim.api.nvim_get_current_buf()
		if vim.api.nvim_buf_get_name(buf) ~= "" or vim.bo[buf].buftype ~= "" then
			return
		end
		vim.schedule(function()
			require("oil").open(vim.fn.getcwd())
		end)
	end,
})

-- Undotree
vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)
