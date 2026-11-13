local pack = require("config.pack")

-- Table editing (commands and mappings only; not needed at startup)
pack.later(
	"vim-table-mode setup",
	function()
		vim.pack.add {
			-- Default branch: latest release (v4.8.1) is from 2023
			"https://github.com/dhruvasagar/vim-table-mode"
		}

		-- Its markdown/rst ftplugins missed buffers whose filetype was set before loading
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			local ft = vim.bo[buf].filetype
			if ft == "markdown" or ft == "rst" then
				vim.api.nvim_buf_call(
					buf,
					function()
						vim.cmd.runtime { "ftplugin/" .. ft .. "_tablemode.vim", bang = true }
					end
				)
			end
		end
	end
)
