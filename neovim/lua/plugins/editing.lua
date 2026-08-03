-- mini.nvim is added once here; submodules are set up here (ai, surround) and
-- in ui.lua (icons, statusline). mini.icons is set up here (early, before
-- navigation/statusline render icons) and mocks nvim-web-devicons.
vim.pack.add({ "https://github.com/nvim-mini/mini.nvim" })

-- Icons (must be available before telescope/oil/statusline render)
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()

-- Better Around/Inside textobjects
require("mini.ai").setup({ n_lines = 500 })

-- Add/delete/replace surroundings (brackets, quotes, etc.)
require("mini.surround").setup()
