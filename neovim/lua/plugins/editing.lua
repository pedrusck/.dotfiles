-- mini.nvim is shared with ui.lua (statusline); both add it with the same spec.
-- mini.icons is set up here, early, so telescope/oil/statusline render icons, and
-- mocks nvim-web-devicons. Icons are optional for those consumers.
local specs = require("plugins.specs")

vim.pack.add { specs.mini }

-- Icons (must be available before telescope/oil/statusline render)
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()

-- Better Around/Inside textobjects
require("mini.ai").setup { n_lines = 500 }

-- Add/delete/replace surroundings (brackets, quotes, etc.)
require("mini.surround").setup()
