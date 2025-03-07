# sort-tf-blocks.nvim

A Neovim plugin to sort Terraform blocks in a logical order.

## Features

- Sort Terraform blocks by type and then alphabetically
- Preserve standalone comments
- Customizable block order
- Uses Treesitter for accurate parsing

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'alexandre/sort-tf-blocks.nvim',
  config = function()
    require('sort-tf-blocks').setup({
      -- Optional configuration
    })
  end
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'alexandre/sort-tf-blocks.nvim',
  config = function()
    require('sort-tf-blocks').setup({
      -- Optional configuration
    })
  end
}
```

## Configuration

```lua
require('sort-tf-blocks').setup({
  verbosity = 0, -- 0 = no log, 1 = essential, 2 = detailed
  keymaps = {
    sort_tf_keymap = "<leader>tsb", -- Keymap to sort Terraform blocks
  },
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
})
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
