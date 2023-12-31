local M = {}

-- PERF do not require the submodules here, since that loads the entire codebase
-- of the plugin on initialization instead of lazy-loading the parts when needed.

--------------------------------------------------------------------------------

---@return string|nil snippetDir nil when the directory does not exist
---@nodiscard
local function getSnippetDir()
	local snippetDir = require("scissors.config").config.snippetDir
	local stat = vim.loop.fs_stat(snippetDir)
	local exists = stat and stat.type == "directory"
	if exists then return snippetDir end

	require("scissors.utils").notify("Snippet directory does not exist: " .. snippetDir, "error")
	return nil
end

--------------------------------------------------------------------------------

---@param userConfig? pluginConfig
function M.setup(userConfig) require("scissors.config").setupPlugin(userConfig or {}) end

function M.editSnippet()
	local snippetDir = getSnippetDir()
	if not snippetDir then return end

	local rw = require("scissors.read-write-operations")
	local snipObj = require("scissors.snippet-object")
	local u = require("scissors.utils")

	-- get all snippets
	local allSnippets = {} ---@type SnippetObj[]
	for name, _ in vim.fs.dir(snippetDir, { depth = 3 }) do
		if name:find("%.jsonc?$") and name ~= "package.json" then
			local filepath = snippetDir .. "/" .. name
			local vscodeJson = rw.readAndParseJson(filepath) ---@cast vscodeJson VSCodeSnippetDict
			local snippetsInFileArr = snipObj.restructureVsCodeObj(vscodeJson, filepath)
			vim.list_extend(allSnippets, snippetsInFileArr)
		end
	end

	-- let user select
	vim.ui.select(allSnippets, {
		prompt = "Select snippet:",
		format_item = function(snip)
			local snipName = u.snipDisplayName(snip)
			local filename = vim.fs.basename(snip.fullPath):gsub("%.json$", "")
			return ("%s\t\t[%s]"):format(snipName, filename)
		end,
		kind = "nvim-scissors.snippetSearch",
	}, function(snip)
		if not snip then return end
		require("scissors.edit-snippet").editInPopup(snip, "update")
	end)
end

function M.addNewSnippet()
	local snippetDir = getSnippetDir()
	if not snippetDir then return end

	-- get list of all snippet JSON files
	local jsonFiles = {}
	for name, _ in vim.fs.dir(snippetDir, { depth = 3 }) do
		if name:find("%.json$") and name ~= "package.json" then table.insert(jsonFiles, name) end
	end

	-- let user select
	vim.ui.select(jsonFiles, {
		prompt = "Select file for new snippet:",
		format_item = function(item) return item:gsub("%.json$", "") end,
		kind = "nvim-scissors.fileSelect",
	}, function(file)
		if not file then return end

		---@type SnippetObj
		local snip = {
			fullPath = snippetDir .. "/" .. file,
			body = { "" },
			prefix = { "" },
		}
		require("scissors.edit-snippet").editInPopup(snip, "new")
	end)
end

--------------------------------------------------------------------------------
return M
