local M = {}

M.config = {
	verbosity = 0, -- 0 = aucun log, 1 = essentiel, 2 = détaillé
	keymaps = {
		sort_tf_keymap = "<leader>tsv",
	},
}

function M.setup(user_config)
	print("Dans fonction setup")
	-- Fusionner les options utilisateur avec les valeurs par défaut
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
	-- Appliquer les keymaps si elles sont activées
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

	-- Utilisation de la notification native de Neovim
	vim.notify(message, vim.log.levels[string.upper(level)] or vim.log.levels.INFO, {
		title = opts.title or "Notification",
		timeout = opts.timeout or 3000,
	})
end

local function log(message, level)
	level = level or 1 -- Niveau par défaut = 1
	if (M.config.verbosity or 0) >= level then -- Évite la comparaison avec nil
		print(message)
	end
end

function M.sort_terraform_variables()
	print("Début du tri des variables Terraform")
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
		-- Ignorer les lignes vides inutiles
		else
			table.insert(blocks, { line }) -- Garde les lignes hors bloc (ex: commentaires)
		end
	end

	-- Trier les blocs uniquement si ce sont des variables, avec un tri strict ASCII
	table.sort(blocks, function(a, b)
		local name_a = a[1]:match('^variable%s+"([^"]+)"%s*{')
		local name_b = b[1]:match('^variable%s+"([^"]+)"%s*{')
		return name_a and name_b and name_a:lower() < name_b:lower()
	end)

	-- Aplatir les blocs en lignes tout en supprimant les espaces vides inutiles
	local sorted_lines = {}
	for _, block in ipairs(blocks) do
		for _, line in ipairs(block) do
			table.insert(sorted_lines, line)
		end
		table.insert(sorted_lines, "") -- Ajouter une ligne vide entre les blocs pour la lisibilité
	end

	-- Supprimer la dernière ligne vide inutile
	if sorted_lines[#sorted_lines] == "" then
		table.remove(sorted_lines)
	end

	-- Remplace le buffer avec les nouvelles lignes triées
	vim.api.nvim_buf_set_lines(0, 0, -1, false, sorted_lines)
end

return M
