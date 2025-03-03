local M = {}

M.config = {
	verbosity = 0, -- 0 = no log, 1 = essential, 2 = detailed
	keymaps = {
		sort_tf_keymap = "<leader>tsv",
	},
}

function M.setup(user_config)
	print("In setup function")
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
	if M.config.keymaps.sort_tf_keymap then
		vim.api.nvim_set_keymap(
			"n",
			M.config.keymaps.sort_tf_keymap,
			':lua require("sort-tf-vars").sort_terraform_blocks()<CR>',
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

	-- Check if there are any changes
	local has_changed = false
	if #lines ~= #sorted_lines then
		has_changed = true
	else
		for i = 1, #lines do
			if lines[i] ~= sorted_lines[i] then
				has_changed = true
				break
			end
		end
	end

	if has_changed then
		vim.api.nvim_buf_set_lines(0, 0, -1, false, sorted_lines)
		log("Writing to the buffer", 1)
		M.send_notification("Terraform blocks have been sorted.", "info")
	else
		log("No change in the buffer", 1)
		M.send_notification("No changes in Terraform blocks.", "info")
	end
end

return M
