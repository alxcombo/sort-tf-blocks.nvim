# sort-tf-blocks.nvim

[![GitHub](https://img.shields.io/badge/GitHub-alxcombo/sort--tf--blocks--nvim-blue?logo=github)](https://github.com/alxcombo/sort-tf-blocks.nvim)

A Neovim plugin to sort Terraform blocks in a logical, consistent order.

## Why this plugin?

Keeping Terraform files clean and consistent manually is tedious.  
This plugin automates the process by sorting your blocks by type (based on a custom order) and alphabetically within each type — using Treesitter for accurate parsing.  
It's fast, idempotent, and easily configurable.

## Features

- ✅ Sort Terraform blocks by type and then alphabetically
- ✅ Customizable block order
- ✅ Preserve standalone comments
- ✅ Idempotent: no changes if the file is already sorted
- ✅ Uses Treesitter for accurate block detection
- ✅ Configurable keybinding

## Installation and configuration

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  {
    "alxcombo/sort-tf-blocks.nvim",
    config = function()
      require("sort-tf-blocks").setup({
        verbosity = 0, -- 0 = no log, 1 = essential, 2 = detailed
        keymaps = {
          sort_tf_keymap = "<leader>tsb", -- Change this to your preferred key mapping
        },
        block_order = { -- Define the order of block types
          "terraform",   -- Configuration block
          "provider",    -- Provider configuration
          "variable",    -- Input variables
          "locals",      -- Local values
          "data",        -- Data sources
          "resource",    -- Resources
          "module",      -- Module calls
          "output",      -- Output values
          "moved",       -- Moved blocks (for refactoring)
          "check",       -- Validation checks
        },
      })
    end,
  },
}
```

## Usage

1. Open a `.tf` file in Neovim
2. Press `<leader>tsb` (or your configured keymap) to sort the blocks
3. The plugin will:
   - Sort block types based on the `block_order`
   - Sort blocks alphabetically within each type
   - Preserve comments
   - Show a notification if no change is necessary

### Idempotent behavior

If your Terraform blocks are already sorted, triggering the plugin again will result in **no changes** — ensuring a clean and predictable workflow.

## Supported Block Types

The plugin supports the following Terraform block types:

- `terraform` – Terraform configuration blocks
- `provider` – Provider configuration blocks
- `variable` – Input variable blocks
- `locals` – Local value blocks
- `data` – Data source blocks
- `resource` – Resource blocks
- `module` – Module call blocks
- `output` – Output value blocks
- `moved` – Moved blocks (for refactoring)
- `check` – Validation check blocks

## Example

Before:

```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345"
  instance_type = "t2.micro"
}

variable "region" {
  default = "us-west-2"
}

data "aws_ami" "ubuntu" {
  most_recent = true
}
```

After:

```hcl
variable "region" {
  default = "us-west-2"
}

data "aws_ami" "ubuntu" {
  most_recent = true
}

resource "aws_instance" "web" {
  ami           = "ami-12345"
  instance_type = "t2.micro"
}
```

In this example, the blocks are sorted according to the block_order:

- variable blocks come first
- followed by data blocks
- then resource blocks

Within each type, blocks are also sorted alphabetically by their identifier.

## License

MIT
