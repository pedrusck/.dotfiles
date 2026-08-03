local map = vim.keymap.set

-- Clear search highlights
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Move visual block up/down
map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")

-- Move line up/down in normal mode (<leader>m* = move group; visual J/K kept)
map("n", "<leader>mj", ":m .+1<CR>==", { desc = "Move: line down" })
map("n", "<leader>mk", ":m .-2<CR>==", { desc = "Move: line up" })

-- Scroll centered
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")

-- Search centered
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Paste without yanking
map("x", "<leader>p", '"_dP')

-- Window focus (Ctrl + h/j/k/l = window motion, all four directions)
map("n", "<C-h>", "<C-w><C-h>", { desc = "Focus window left" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "Focus window down" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "Focus window up" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "Focus window right" })

-- Open URL in browser
map("n", "gx", '<Cmd>call jobstart(["open", expand("<cfile>")], {"detach": v:true})<CR>')

-- Buffer navigation (<leader>b* = buffer group)
map("n", "<leader>bp", ":bprev<CR>", { silent = true, desc = "Buffer: previous" })
map("n", "<leader>bn", ":bnext<CR>", { silent = true, desc = "Buffer: next" })
map("n", "<leader>bf", ":bfirst<CR>", { silent = true, desc = "Buffer: first" })
map("n", "<leader>bl", ":blast<CR>", { silent = true, desc = "Buffer: last" })
map("n", "<leader>bd", ":bdelete<CR>", { silent = true, desc = "Buffer: delete" })

-- Buffer cycle (overrides Vim's tab-page default; tabs still via :tabnext/:tabprev)
map("n", "gt", ":bnext<CR>", { silent = true, desc = "Buffer: next (cycle)" })
map("n", "gT", ":bprev<CR>", { silent = true, desc = "Buffer: previous (cycle)" })

-- Spell switching (<leader>s* = spell group)
map("n", "<leader>sd", ":setlocal spelllang=de_de<CR>", { silent = true, desc = "Spell: German" })
map("n", "<leader>se", ":setlocal spelllang=en_us<CR>", { silent = true, desc = "Spell: English" })

-- Exit terminal mode
map("t", "<Esc><Esc>", "<C-\\><C-n>")
