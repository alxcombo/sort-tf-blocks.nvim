local M = {}

M.config = {
	verbosity = 0, -- 0 = no log, 1 = essential, 2 = detailed
	keymaps = {
		sort_tf_keymap = "<leader>tsb",
	},
	use_treesitter = true, --default
	block_order = {  -- Define the order of block types (lower index = higher priority)
		"terraform",  -- Configuration block
		"provider",   -- Provider configuration
		"variable",   -- Input variables
		"locals",     -- Local values
		"data",       -- Data sources
		"resource",   -- Resources
		"module",     -- Module calls
		"output",     -- Output values
		"moved",      -- Moved blocks (for refactoring)
		"check"       -- Validation checks
	}
}

function M.setup(user_config)
	print("In setup function")
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
	if M.config.keymaps.sort_tf_keymap then
		local sort_function = "sort_terraform_blocks_treesitter"
		vim.api.nvim_set_keymap(
			"n",
			M.config.keymaps.sort_tf_keymap,
			string.format(':lua require("sort-tf-blocks").%s()<CR>', sort_function),
			{ noremap = true, silent = true, desc = "Terraform Sort blocks" }
		)
	end
end

function M.send_notification(message, level, opts)
	level = level or "info"
	opts = opts or {}
	vim.notify(message, vim.log.levels[string.upper(level)] or vim.log.levels.INFO, {
		title = opts.title or "Notification",
		timeout = opts.timeout or 3000,
	})
end

local function log(message, level)
	level = level or 1
	if (M.config.verbosity or 0) >= level then
		print(message)
	end
end

function M.traverse_tree(node, blocks)
	for child in node:iter_children() do
		log("Node type: " .. child:type(), 2)
		if
			child:type() == "block"
			or child:type() == "resource"
			or child:type() == "data"
			or child:type() == "module"
			or child:type() == "variable"
			or child:type() == "output"
			or child:type() == "provider"
			or child:type() == "terraform"
			or child:type() == "locals"
			or child:type() == "moved"
			or child:type() == "check"
		then
			local start_row, _, end_row, _ = child:range()
			local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)
			-- Store the actual type for sorting purposes
			local block_type = child:type()

			-- Handle special case for data and resource blocks
			if block_type == "block" then
				-- Try to determine if it's a data or resource block from the content
				local first_line = lines[1]:gsub("^%s+", "")
				if first_line:match("^data%s+") then
					block_type = "data"
				elseif first_line:match("^resource%s+") then
					block_type = "resource"
				elseif first_line:match("^provider%s+") then
					block_type = "provider"
				elseif first_line:match("^terraform%s*{") then
					block_type = "terraform"
				elseif first_line:match("^locals%s*{") then
					block_type = "locals"
				elseif first_line:match("^moved%s*{") then
					block_type = "moved"
				elseif first_line:match("^check%s*{") then
					block_type = "check"
				end
			end

			table.insert(blocks, {
				node = child,
				content = lines,
				start_row = start_row,
				end_row = end_row,
				block_type = block_type -- Store the actual block type
			})
			log("Found block: " .. lines[1], 2)
		else
			M.traverse_tree(child, blocks)
		end
	end
end

function M.collect_standalone_comments(current_lines, blocks)
	local standalone_comments = {}
	for i, line in ipairs(current_lines) do
		local is_in_block = false
		for _, block in ipairs(blocks) do
			if i > block.start_row and i <= block.end_row + 1 then
				is_in_block = true
				break
			end
		end
		if not is_in_block then
			if line:match("^%s*#") or not line:match("^%s*$") then
				table.insert(standalone_comments, line)
			end
		end
	end
	return standalone_comments
end

function M.sort_blocks(blocks)
	-- Create a priority map from the config
	local block_type_priority = {}
	for i, block_type in ipairs(M.config.block_order) do
		block_type_priority[block_type] = i
	end

	table.sort(blocks, function(a, b)
		-- Get the actual block types
		local a_type = a.block_type or a.node:type()
		local b_type = b.block_type or b.node:type()

		-- Debug logging
		log("Comparing blocks: " .. a_type .. " vs " .. b_type, 2)

		-- If block types are different, sort by priority
		if a_type ~= b_type then
			local a_priority = block_type_priority[a_type] or 99
			local b_priority = block_type_priority[b_type] or 99
			log("  Priorities: " .. a_type .. "=" .. a_priority .. ", " .. b_type .. "=" .. b_priority, 2)
			return a_priority < b_priority
		end

		-- If block types are the same, sort alphabetically
		local a_first_line = a.content[1]:gsub("^%s+", "")
		local b_first_line = b.content[1]:gsub("^%s+", "")
		return a_first_line < b_first_line
	end)
end

function M.generate_sorted_lines(blocks, standalone_comments)
	local sorted_lines = {}
	for _, comment in ipairs(standalone_comments) do
		table.insert(sorted_lines, comment)
	end
	if #standalone_comments > 0 then
		table.insert(sorted_lines, "")
	end

	for i, block in ipairs(blocks) do
		if i > 1 then
			table.insert(sorted_lines, "")
		end
		for _, line in ipairs(block.content) do
			table.insert(sorted_lines, line)
		end
	end
	return sorted_lines
end

function M.update_buffer_if_changed(current_lines, sorted_lines)
	local has_changed = false
	if #current_lines ~= #sorted_lines then
		has_changed = true
		log("Number of lines changed", 1)
	else
		for i = 1, #current_lines do
			if current_lines[i] ~= sorted_lines[i] then
				has_changed = true
				log("Content changed at line " .. i, 2)
				break
			end
		end
	end

	if has_changed then
		if #sorted_lines > 0 then
			vim.api.nvim_buf_set_lines(0, 0, -1, false, sorted_lines)
			log("Writing " .. #sorted_lines .. " lines to buffer", 1)
			M.send_notification("Terraform blocks have been sorted.", "info")
		else
			log("No lines to write, keeping original content", 1)
			M.send_notification("Error: No sorted lines generated. Keeping original content.", "error")
		end
	else
		log("No changes detected", 1)
		M.send_notification("No changes in Terraform blocks.", "info")
	end
end

function M.sort_terraform_blocks_treesitter()
	local parser = vim.treesitter.get_parser(0, "terraform")
	if not parser then
		M.send_notification("Terraform parser not found. Is tree-sitter-terraform installed?", "error")
		return
	end

	local tree = parser:parse()[1]
	local root = tree:root()

	log("Parsing Terraform file with Treesitter", 1)

	local blocks = {}
	M.traverse_tree(root, blocks)

	local current_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local standalone_comments = M.collect_standalone_comments(current_lines, blocks)

	log("Number of blocks found: " .. #blocks, 1)
	log("Number of standalone comments and non-block lines: " .. #standalone_comments, 1)

	if #blocks == 0 then
		M.send_notification("No Terraform blocks found in the file.", "warn")
		return
	end

	M.sort_blocks(blocks)

	local sorted_lines = M.generate_sorted_lines(blocks, standalone_comments)

	log("Number of sorted lines: " .. #sorted_lines, 1)

	M.update_buffer_if_changed(current_lines, sorted_lines)
end

return M
