local M = {}

M.config = {
	verbosity = 0, -- 0 = no log, 1 = essential, 2 = detailed
	keymaps = {
		sort_tf_keymap = "<leader>tsb",
	},
	use_treesitter = true,
}

function M.setup(user_config)
	print("In setup function")
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
	if M.config.keymaps.sort_tf_keymap then
		local sort_function = M.config.use_treesitter and "sort_terraform_blocks_treesitter" or "sort_terraform_blocks"
		vim.api.nvim_set_keymap(
			"n",
			M.config.keymaps.sort_tf_keymap,
			string.format(':lua require("sort-tf-vars").%s()<CR>', sort_function),
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

local function get_block_type(line)
	if line:match("^terraform%s*{") then
		return "terraform"
	elseif line:match("^variable%s+") then
		return "variable"
	elseif line:match("^data%s+") then
		return "data"
	elseif line:match("^module%s+") then
		return "module"
	elseif line:match("^resource%s+") then
		return "resource"
	elseif line:match("^output%s+") then
		return "output"
	else
		return "other"
	end
end

---@class TerraformBlock
---@field type string
---@field content string[]
function M.sort_terraform_blocks()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	log("Starting to sort Terraform blocks", 1)

	-- Trim trailing empty lines from the original content
	while #lines > 0 and lines[#lines]:match("^%s*$") do
		table.remove(lines)
	end

	local blocks = {}
	local current_block = {}
	local inside_block = false
	local block_type = "other"
	---@type TerraformBlock|nil
	local terraform_block = nil

	for _, line in ipairs(lines) do
		local new_block_type = get_block_type(line)
		if new_block_type == "terraform" then
			terraform_block = { type = "terraform", content = { line } }
			inside_block = true
			block_type = "terraform"
			current_block = { line }
		elseif new_block_type ~= "other" then
			if inside_block then
				if block_type == "terraform" then
					terraform_block.content = current_block
				else
					table.insert(blocks, { type = block_type, content = current_block })
				end
			end
			inside_block = true
			block_type = new_block_type
			current_block = { line }
		elseif inside_block then
			table.insert(current_block, line)
			if line:match("^}%s*$") then
				if block_type == "terraform" then
					terraform_block.content = current_block
				else
					table.insert(blocks, { type = block_type, content = current_block })
				end
				inside_block = false
				current_block = {}
			end
		elseif not line:match("^%s*$") then
			table.insert(blocks, { type = "other", content = { line } })
		end
	end

	if inside_block then
		if block_type == "terraform" then
			terraform_block.content = current_block
		else
			table.insert(blocks, { type = block_type, content = current_block })
		end
	end

	-- Sort the blocks (excluding terraform block)
	table.sort(blocks, function(a, b)
		if a.type ~= b.type then
			local type_order = { variable = 1, data = 2, resource = 3, module = 4, output = 5, other = 6 }
			return type_order[a.type] < type_order[b.type]
		else
			local resource_type_a, name_a = a.content[1]:match('^resource%s+"([^"]+)"%s+"([^"]+)"')
			local resource_type_b, name_b = b.content[1]:match('^resource%s+"([^"]+)"%s+"([^"]+)"')

			if resource_type_a and resource_type_b then
				if resource_type_a ~= resource_type_b then
					return resource_type_a < resource_type_b
				else
					return name_a < name_b
				end
			else
				local name_a = a.content[1]:match('^[^%s"]+%s+"?([^"]+)"?') or ""
				local name_b = b.content[1]:match('^[^%s"]+%s+"?([^"]+)"?') or ""
				return name_a:lower() < name_b:lower()
			end
		end
	end)

	-- Flatten the blocks into lines
	local sorted_lines = {}
	if terraform_block and terraform_block.content then
		for _, line in ipairs(terraform_block.content) do
			table.insert(sorted_lines, line)
		end
		table.insert(sorted_lines, "")
	end

	local prev_block_type = nil
	for i, block in ipairs(blocks) do
		if prev_block_type then
			table.insert(sorted_lines, "")
		end

		for _, line in ipairs(block.content) do
			table.insert(sorted_lines, line)
		end

		prev_block_type = block.type
	end

	-- Remove trailing empty lines
	while #sorted_lines > 0 and sorted_lines[#sorted_lines]:match("^%s*$") do
		table.remove(sorted_lines)
	end

	M.update_buffer_if_changed(lines, sorted_lines)
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
		then
			local start_row, _, end_row, _ = child:range()
			local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)
			table.insert(blocks, { node = child, content = lines, start_row = start_row, end_row = end_row })
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
	table.sort(blocks, function(a, b)
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
