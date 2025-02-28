# sort-tf-vars.nvim

A Neovim plugin for sorting Terraform variables in your configuration files. This plugin helps maintain a clean and organized structure in your Terraform files by automatically sorting variable declarations.

## Features

- Sorts Terraform variable blocks alphabetically.
- Notifies users when variables are sorted or if no changes are made.
- Configurable key mappings for easy access.

## Installation

You can install this plugin using `lazy.vim`. Here’s how to do it:

```lua
require('lazy').setup({
    { 'alxcombo/sort-tf-vars.nvim' }
})
```

## Usage

To sort the Terraform variables in the current buffer, use the configured key mapping. By default, it is set to `<leader>tsv`.

You can also call the sorting function directly:

```lua
:lua require("sort-tf-vars").sort_terraform_variables()
```

## Configuration

You can customize the plugin's behavior by setting options in your Neovim configuration. Here’s an example:

```lua
require("lazy").setup({
    { 'alxcombo/sort-tf-vars.nvim', config = function()
        require("sort-tf-vars").setup({
            verbosity = 1, -- 0 = no log, 1 = essential, 2 = detailed
            keymaps = {
                sort_tf_keymap = "<leader>tsv", -- Change this to your preferred key mapping
            },
        })
    end }
})
```

## Notifications

The plugin uses Neovim's native notification system to inform you about the sorting process. You will receive notifications when:

- The variables have been successfully sorted.
- No changes were detected in the buffer.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue for any bugs or feature requests.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

