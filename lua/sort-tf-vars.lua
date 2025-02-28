local M = {}

M.config = {
	verbosity = 0, -- 0 = no log, 1 = essential, 2 = detailed
	keymaps = {
		sort_tf_keymap = "<leader>tsv",
	},
}

function M.setup(user_config)
	print("In setup function")
	-- Merge user options with default values
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
	-- Apply keymaps if they are enabled
	if M.config.keymaps.sort_tf_keymap then
		vim.api.nvim_set_keymap(
			"n",
			M.config.keymaps.sort_tf_keymap,
			':lua require("sort-tf-vars").sort_terraform_variables()<CR>',
			{ noremap = true, silent = true, desc = "Terraform Sort variables" }
		)
	end
end

function M.send_notification(message, level, opts)
	level = level or "info"
	opts = opts or {}

	-- Use Neovim's native notification
	vim.notify(message, vim.log.levels[string.upper(level)] or vim.log.levels.INFO, {
		title = opts.title or "Notification",
		timeout = opts.timeout or 3000,
	})
end

local function log(message, level)
	level = level or 1 -- Default level = 1
	if (M.config.verbosity or 0) >= level then -- Avoid comparison with nil
		print(message)
	end
end

function M.sort_terraform_variables()
	log("Starting to sort Terraform variables", 1)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local blocks = {}
	local current_block = {}
	local inside_block = false

	for _, line in ipairs(lines) do
		if line:match('^variable%s+".+"%s*{') then
			inside_block = true
			current_block = { line }
		elseif inside_block then
			table.insert(current_block, line)
			if line:match("^}%s*$") then
				inside_block = false
				table.insert(blocks, current_block)
				current_block = {}
			end
		elseif line:match("^%s*$") then
		-- Ignore unnecessary empty lines
		else
			table.insert(blocks, { line }) -- Keep lines outside blocks (e.g., comments)
		end
	end

	-- Sort the blocks only if they are variables, with strict ASCII sorting
	table.sort(blocks, function(a, b)
		local name_a = a[1]:match('^variable%s+"([^"]+)"%s*{')
		local name_b = b[1]:match('^variable%s+"([^"]+)"%s*{')
		return name_a and name_b and name_a:lower() < name_b:lower()
	end)

	-- Flatten the blocks into lines while removing unnecessary empty spaces
	local sorted_lines = {}
	for _, block in ipairs(blocks) do
		for _, line in ipairs(block) do
			table.insert(sorted_lines, line)
		end
		table.insert(sorted_lines, "") -- Add an empty line between blocks for readability
	end

	-- Remove the last unnecessary empty line
	if sorted_lines[#sorted_lines] == "" then
		table.remove(sorted_lines)
	end

	-- Replace the buffer with the new sorted lines
	local has_changed = #lines ~= #sorted_lines

	if has_changed then
		vim.api.nvim_buf_set_lines(0, 0, -1, false, sorted_lines)
		log("Writing to the buffer", 1)
		M.send_notification("Terraform variables have been sorted.", "info")
	else
		log("No change in the buffer", 1)
		M.send_notification("No changes in Terraform variables.", "info")
	end
end

return M
