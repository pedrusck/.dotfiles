local M = {}

local languages = {
	["ca-ES"] = { native = "ca", name = "Catalan" },
	["de-DE"] = { native = "de_de", name = "German" },
	["en-US"] = { native = "en_us", name = "English" },
	["es-ES"] = { native = "es_es", name = "Spanish (Spain)" },
}
local aliases = {}
for language, choice in pairs(languages) do
	aliases[choice.native] = language
end

local formats = {
	markdown = "<!-- LTeX: language=%s -->",
	tex = "%% LTeX: language=%s",
	plaintex = "%% LTeX: language=%s",
	rst = ".. LTeX: language=%s",
}

function M.supports(filetype)
	return formats[filetype] ~= nil
end

local function blank(line)
	return not line or line:match("^%s*$") ~= nil
end

-- Stored rows and byte columns are zero-based; end_col is exclusive.
-- Parsing uses one-based Lua line indices and string positions.
local function record_declaration(info, row, start_col, end_col, value)
	table.insert(info.declarations, { row = row, start_col = start_col, end_col = end_col, value = value })
	info.language = value
end

local function parse_yaml_language(info, line, row, prefix)
	local rest = line:sub(#prefix + 1)
	local quote = rest:sub(1, 1)
	local value, suffix
	local start_col = #prefix
	if quote == '"' or quote == "'" then
		value, suffix = rest:match("^" .. quote .. "([%w_-]+)" .. quote .. "(.*)$")
		start_col = start_col + 1
	else
		value, suffix = rest:match("^([%w_-]+)(.*)$")
		if value == "null" or value == "true" or value == "false" or (value and value:match("^%d")) then
			value = nil
		end
	end
	if not value or not (suffix:match("^%s*$") or suffix:match("^%s+#")) then
		info.error = "YAML lang must be a simple, single-line language code (optionally quoted)"
		return
	end
	record_declaration(info, row, start_col, start_col + #value, value)
end

local function inspect_front_matter(info, lines)
	if not (lines[1] or ""):match("^%-%-%-%s*$") then
		return 1
	end
	local closing_line
	for line_index = 2, #lines do
		if lines[line_index]:match("^%-%-%-%s*$") or lines[line_index]:match("^%.%.%.%s*$") then
			closing_line = line_index
			break
		end
	end
	if not closing_line then
		info.error = "YAML front matter has no closing delimiter"
		return #lines + 1
	end
	local seen_lang, in_lang, seen_key
	for line_index = 2, closing_line - 1 do
		local line = lines[line_index]
		if not blank(line) and not line:match("^%s*#") then
			if line:match("^%s") then
				if not seen_key then
					info.error = "YAML front matter has indented or ambiguous top-level fields"
				elseif in_lang then
					info.error = "YAML lang has a multiline or nested value"
				end
			else
				seen_key = true
				in_lang = false
				local prefix = line:match("^(lang%s*:%s+)")
					or line:match('^("lang"%s*:%s+)')
					or line:match("^('lang'%s*:%s+)")
					or line:match("^(lang%s*:)$")
				if prefix then
					if seen_lang then
						info.error = "YAML front matter contains duplicate lang fields"
					end
					seen_lang, in_lang = true, true
					parse_yaml_language(info, line, line_index - 1, prefix)
				elseif not line:match("^[%w_%-]+:%s") and not line:match("^[%w_%-]+:$") then
					-- Includes merge keys, flow mappings, explicit keys and multiline keys.
					-- Their effective top-level lang cannot be determined without a YAML parser.
					info.error = "YAML front matter uses complex keys or structure; use simple top-level fields"
				end
			end
		end
	end
	return closing_line + 1
end

-- Return a one-based, end-exclusive body range only for a standalone magic comment.
local function magic_body_range(line, filetype)
	local lower = line:lower()
	if filetype == "markdown" then
		if line:match("^    ") or line:match("^ *\t") then
			return
		end
		local body_start, body_end = lower:match("^%s*<!%-%-%s*ltex%s*:%s*().-()%s*%-%->%s*$")
		if body_start and lower:sub(body_start, body_end - 1):find("-->", 1, true) then
			return
		end
		if not body_start then
			body_start, body_end = lower:match('^%s*%[%s*comment%s*%]%s*:%s*<>%s*"%s*ltex%s*:%s*().-()%s*"%s*$')
		end
		return body_start, body_end
	elseif filetype == "rst" then
		return lower:match("^%.%.%s*ltex%s*:%s*().-()%s*$")
	else
		return lower:match("^%s*%%%s*ltex%s*:%s*().-()%s*$")
	end
end

local function inspect_magic(info, line, row, body_start, body_end)
	local body = line:sub(body_start, body_end - 1)
	local lower = body:lower()
	local search_pos = 1
	while true do
		local key_start, key_last = lower:find("language", search_pos, true)
		if not key_start then
			break
		end
		local after_key = lower:sub(key_last + 1, key_last + 1)
		if
			(key_start == 1 or lower:sub(key_start - 1, key_start - 1):match("%s"))
			and (after_key == "" or after_key:match("[%s=]"))
		then
			local value_offset = lower:sub(key_last + 1):match("^%s*=%s*()")
			if not value_offset then
				info.error = "Opening LTeX language setting is missing '='"
				return
			end
			local value_start = key_last + value_offset
			local value = body:sub(value_start):match("^([%w_#%-]+)")
			local after_value = value and body:sub(value_start + #value, value_start + #value) or ""
			if not value or (after_value ~= "" and not after_value:match("%s")) then
				info.error = "Opening LTeX language must be an unquoted language code"
				return
			end
			local start_col = body_start + value_start - 2
			record_declaration(info, row, start_col, start_col + #value, value)
			search_pos = value_start + #value
		else
			search_pos = key_last + 1
		end
	end
	table.insert(info.comments, { row = row, col = body_end - 1, space = body ~= "" })
end

--- Inspect only opening metadata/comments. Pure: no buffer or plugin access.
--- Once content starts, fences, quotations, literal blocks and later sections
--- are deliberately opaque. Multiline ordinary comments are skipped as units.
function M.inspect(lines, filetype)
	local info = { declarations = {}, comments = {}, insertion = 0 }
	if not M.supports(filetype) then
		info.error = "unsupported filetype"
		return info
	end
	local line_index = filetype == "markdown" and inspect_front_matter(info, lines) or 1
	while line_index <= #lines do
		local line = lines[line_index]
		local body_start, body_end = magic_body_range(line, filetype)
		if blank(line) then
			line_index = line_index + 1
		elseif body_start then
			inspect_magic(info, line, line_index - 1, body_start, body_end)
			line_index = line_index + 1
		elseif filetype == "markdown" and line:match("^ ? ? ?<!%-%-") then
			local closing_line = line_index
			while closing_line <= #lines and not lines[closing_line]:find("-->", 1, true) do
				closing_line = closing_line + 1
			end
			if closing_line > #lines then
				info.error = "Opening HTML comment has no closing delimiter"
				break
			end
			local tail = lines[closing_line]:match("%-%->(.*)$")
			if not blank(tail) then
				break
			end
			line_index = closing_line + 1
		elseif (filetype == "tex" or filetype == "plaintex") and line:match("^%s*%%") then
			line_index = line_index + 1
		elseif filetype == "rst" and (line == ".." or line:match("^%.%.%s+")) then
			-- Directives, targets, substitutions and footnotes are content, not comments.
			local body = line:sub(3):match("^%s*(.*)")
			if body:find("::", 1, true) or body:match("^[_|%[]") then
				break
			end
			line_index = line_index + 1
			while line_index <= #lines and (blank(lines[line_index]) or lines[line_index]:match("^%s")) do
				line_index = line_index + 1
			end
		else
			break
		end
	end
	info.insertion = line_index - 1
	return info
end

--- Plan disjoint edits in document order without changing the supplied lines.
--- Return text edits (none when values match) or one whole-line insertion, never both.
function M.plan(lines, filetype, language)
	language = aliases[language] or language
	if not languages[language] then
		return nil, "unsupported language"
	end
	local info = M.inspect(lines, filetype)
	if info.error then
		return nil, info.error
	end
	if #info.declarations > 0 then
		local edits = {}
		for _, item in ipairs(info.declarations) do
			if item.value ~= language then
				table.insert(edits, {
					row = item.row,
					start_col = item.start_col,
					end_col = item.end_col,
					text = language,
				})
			end
		end
		return edits
	end

	local comment = info.comments[#info.comments]
	if comment then
		return {
			{
				row = comment.row,
				start_col = comment.col,
				end_col = comment.col,
				text = (comment.space and " " or "") .. "language=" .. language,
			},
		}
	end

	local row = info.insertion
	local added = { formats[filetype]:format(language) }
	if not blank(lines[row]) then
		table.insert(added, 1, "")
	end
	if not blank(lines[row + 1]) then
		table.insert(added, "")
	end
	-- An empty buffer already provides the blank line below the declaration.
	if #lines == 1 and lines[1] == "" then
		row = 0
	end
	return { { row = row, lines = added } }
end

local namespace = vim.api.nvim_create_namespace("DocumentSpellView")

local function apply(buf, edits)
	if #edits == 0 then
		return
	end
	-- Track rows with extmarks, retaining the saved numeric cursor columns.
	local views = {}
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		vim.api.nvim_win_call(win, function()
			local view = vim.fn.winsaveview()
			table.insert(views, {
				win = win,
				view = view,
				cursor = vim.api.nvim_buf_set_extmark(buf, namespace, view.lnum - 1, 0, {}),
				top = vim.api.nvim_buf_set_extmark(buf, namespace, view.topline - 1, 0, {}),
			})
		end)
	end
	local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
		-- Explicitly start a fresh undo block, including when called from Lua.
		vim.cmd("let &l:undolevels = &l:undolevels")
		-- Plans are ordered and disjoint; work backwards to preserve their coordinates.
		for i = #edits, 1, -1 do
			if i < #edits then
				vim.cmd("undojoin")
			end
			local edit = edits[i]
			if edit.lines then
				vim.api.nvim_buf_set_lines(buf, edit.row, edit.row, false, edit.lines)
			else
				vim.api.nvim_buf_set_text(buf, edit.row, edit.start_col, edit.row, edit.end_col, { edit.text })
			end
		end
	end)
	for _, saved in ipairs(views) do
		if vim.api.nvim_win_is_valid(saved.win) and vim.api.nvim_win_get_buf(saved.win) == buf then
			local cursor = vim.api.nvim_buf_get_extmark_by_id(buf, namespace, saved.cursor, {})
			local top = vim.api.nvim_buf_get_extmark_by_id(buf, namespace, saved.top, {})
			saved.view.lnum, saved.view.topline = cursor[1] + 1, top[1] + 1
			vim.api.nvim_win_call(saved.win, function()
				vim.fn.winrestview(saved.view)
			end)
		end
	end
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	if not ok then
		error(err)
	end
end

function M.select(language, buf)
	buf = buf or vim.api.nvim_get_current_buf()
	language = aliases[language] or language
	local choice = languages[language]
	assert(choice, "unsupported spelling language")
	local function failed(reason)
		vim.notify("Language synchronization skipped: " .. reason, vim.log.levels.WARN)
		return false
	end
	local filetype = vim.bo[buf].filetype
	if not M.supports(filetype) then
		vim.bo[buf].spelllang = choice.native
		vim.notify(choice.name .. " selected; native spelling only (unsupported filetype)")
		return true
	end
	if vim.bo[buf].readonly or not vim.bo[buf].modifiable or vim.bo[buf].buftype ~= "" then
		return failed("buffer is read-only, unmodifiable, or not a regular document")
	end
	local edits, err = M.plan(vim.api.nvim_buf_get_lines(buf, 0, -1, false), filetype, language)
	if not edits then
		return failed(err)
	end
	local ok, reason = pcall(apply, buf, edits)
	if not ok then
		return failed(tostring(reason))
	end
	vim.bo[buf].spelllang = choice.native
	vim.notify(choice.name .. " selected; LTeX+ will recheck on save")
	return true
end

function M.initialize(buf)
	if not vim.api.nvim_buf_is_valid(buf) or not M.supports(vim.bo[buf].filetype) then
		return
	end
	local info = M.inspect(vim.api.nvim_buf_get_lines(buf, 0, -1, false), vim.bo[buf].filetype)
	-- Values are case-sensitive in LTeX+. Unknown languages (including auto/#)
	-- leave the user's native default alone instead of guessing a dictionary.
	local choice = not info.error and languages[info.language]
	if choice then
		vim.bo[buf].spelllang = choice.native
	end
end

return M
