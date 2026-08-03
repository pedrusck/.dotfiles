-- Swift file runner.
--
-- Bound to an explicit keymap (<leader>cx, "Code: execute") rather than run on
-- every save: `swift <file>` only makes sense for standalone, runnable scripts
-- and would error or misbehave on library / SwiftPM package sources that are
-- not directly executable. The keymap is buffer-local and set on the Swift
-- filetype so it never leaks into other buffers.
local function run_current_swift_file()
	local file_name = vim.api.nvim_buf_get_name(0)
	local buf_name = "[Swift Output]"

	-- Find or create the output buffer
	local buf = vim.fn.bufnr(buf_name)
	if buf == -1 then
		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf, buf_name)
	end

	-- Ensure the buffer is visible in a split
	local win = vim.fn.bufwinid(buf)
	if win == -1 then
		vim.cmd("botright split")
		vim.api.nvim_win_set_buf(0, buf)
		vim.api.nvim_win_set_height(0, 12)
	end

	-- Clear and set initial content
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "$ swift " .. file_name, "" })

	local append = function(_, data)
		if data then
			vim.api.nvim_buf_set_lines(buf, -1, -1, false, data)
		end
	end

	vim.fn.jobstart({ "swift", file_name }, {
		stdout_buffered = true,
		on_stdout = append,
		on_stderr = append,
	})
end

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("SwiftFilesRunner", { clear = true }),
	pattern = "swift",
	desc = "Swift: buffer-local run-current-file keymap",
	callback = function(ev)
		vim.keymap.set(
			"n",
			"<leader>cx",
			run_current_swift_file,
			{ buffer = ev.buf, desc = "Code: execute (swift run current file)" }
		)
	end,
})
