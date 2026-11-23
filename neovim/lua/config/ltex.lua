local M = {}
local aliases = { es = "es-ES" }
local patched = setmetatable({}, { __mode = "k" })

-- 18.7.0 accepts es-ES declarations but LanguageTool emits/reads the es key.
-- Persist canonical filenames and send both settings keys for compatibility.
function M.canonical_files()
	local commands = require("ltex_extra.commands-lsp")
	if patched[commands] then
		return
	end
	patched[commands] = true
	local fs = require("ltex_extra.utils.fs")
	local join_path, update = fs.joinPath, commands.updateConfig
	fs.joinPath = function(kind, language)
		return join_path(kind, aliases[language] or language)
	end
	commands.updateConfig = function(kind, language)
		language = aliases[language] or language
		update(kind, language)
		if language == "es-ES" then
			update(kind, "es")
		end
	end
end

return M
