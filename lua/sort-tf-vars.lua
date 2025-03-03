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
	if (M.config.verbosity or 0) >= level then
		print(message)
	end
end

function M.sort_terraform_variables()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	log("Starting to sort Terraform variables", 1)

	local blocks = {}
	local current_block = {}
	local inside_block = false

	for _, line in ipairs(lines) do
		if line:match('^variable%s+"[^"]+"%s*{') then
			if inside_block then
				table.insert(blocks, current_block)
			end
			inside_block = true
			current_block = { line }
		elseif inside_block then
			table.insert(current_block, line)
			if line:match("^}%s*$") then
				inside_block = false
				table.insert(blocks, current_block)
				current_block = {}
			end
		end
	end

	if inside_block then
		table.insert(blocks, current_block)
	end

	-- Sort the blocks
	table.sort(blocks, function(a, b)
		local name_a = a[1]:match('^variable%s+"([^"]+)"%s*{') or ""
		local name_b = b[1]:match('^variable%s+"([^"]+)"%s*{') or ""
		return name_a:lower() < name_b:lower()
	end)

	-- Flatten the blocks into lines
	local sorted_lines = {}
	for i, block in ipairs(blocks) do
		for _, line in ipairs(block) do
			table.insert(sorted_lines, line)
		end
		if i < #blocks then
			table.insert(sorted_lines, "") -- Add an empty line between blocks
		end
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
		M.send_notification("Terraform variables have been sorted.", "info")
	else
		log("No change in the buffer", 1)
		M.send_notification("No changes in Terraform variables.", "info")
	end
end

return M
