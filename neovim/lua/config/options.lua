local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Tabs
-- Non-default: hard tabs (expandtab = false) rendered 4 wide. Chosen so the
-- indent character matches the config's own source style; filetypes that
-- require spaces are handled per-buffer via autocmds/editorconfig.
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = false
opt.shiftround = true
opt.autoindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true
opt.inccommand = "split"

-- UI
opt.cursorline = true
opt.scrolloff = 10
opt.signcolumn = "yes"
opt.showmode = false
opt.termguicolors = true
opt.breakindent = true
opt.linebreak = true
opt.showbreak = "↪ "
opt.mouse = "a"
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Files
opt.undofile = true
opt.undodir = os.getenv("HOME") .. "/.vim/undo"
opt.autoread = true
opt.confirm = true
opt.hidden = true

-- Clipboard: schedule after UiEnter to avoid startup slowdown
vim.schedule(function()
	opt.clipboard = "unnamedplus"
end)

-- Spell
opt.spell = true
opt.spelllang = "en_us"

-- Folding
-- Indent-based folds, but start fully expanded (foldlevel 99) so nothing is
-- hidden on open — folding is opt-in via zc/zM.
opt.foldmethod = "indent"
opt.foldlevel = 99

-- Performance
opt.updatetime = 250
opt.timeoutlen = 300
