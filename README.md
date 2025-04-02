# sort-tf-blocks.nvim

A Neovim plugin to sort Terraform blocks in a logical order.

## Features

- Sort Terraform blocks by type and then alphabetically
- Preserve standalone comments
- Customizable block order
- Uses Treesitter for accurate parsing

## Installation and configuration

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  {
    "alxcombo/sort-tf-blocks.nvim",
    config = function()
      require("sort-tf-blocks").setup({
        verbosity = 0,
        keymaps = {
          sort_tf_keymap = "<leader>tsb", -- Change this to your preferred key mapping
        },
        block_order = {
          "terraform",
          "provider",
          "variable",
          "locals",
          "data",
          "resource",
          "module",
          "output",
          "moved",
          "check",
        },
      })
    end,
  },
}
```

## Usage

1. Open a Terraform file
2. Press `<leader>tsb` (or your configured keymap) to sort the blocks
3. The blocks will be sorted by type according to the defined order, and then alphabetically within each type

## Supported Block Types

The plugin supports the following Terraform block types:

- `terraform` - Terraform configuration blocks
- `provider` - Provider configuration blocks
- `variable` - Input variable blocks
- `locals` - Local value blocks
- `data` - Data source blocks
- `resource` - Resource blocks
- `module` - Module call blocks
- `output` - Output value blocks
- `moved` - Moved blocks (for refactoring)
- `check` - Validation check blocks

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

## License

MIT
