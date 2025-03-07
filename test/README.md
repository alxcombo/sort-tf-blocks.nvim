# Tests for sort-tf-blocks.nvim

This directory contains tests for the sort-tf-blocks.nvim plugin.

## How to run the tests

To run the tests with Busted, use the following command from the project root:

```bash
make test
```

To run the tests with more details:

```bash
make test-verbose
```

## Test structure

- `plugin_spec.lua` - Busted tests for the Terraform block sorting functionality
- `init.lua` - Test environment configuration to simulate Neovim
- `run_tests.sh` - Script to run the tests with the correct parameters
- `sample_terraform.tf` - Example file used for manual testing
- `sample_terraform_with_block.tf` - Example file with different block types for testing

## Implemented tests

1. **Terraform block sorting by type and alphabetically** - Verifies that blocks are sorted correctly according to the defined order
2. **Notifications** - Verifies that notifications are sent correctly
3. **Empty files** - Verifies handling of files without Terraform blocks
4. **Already sorted files** - Verifies that the plugin doesn't modify files that are already sorted
5. **Block type detection** - Verifies that blocks are correctly identified even when Treesitter reports them as generic blocks

## Manual testing

To manually test the plugin:

1. Open the example file: `:e test/sample_terraform.tf`
2. Run the sorting command: `:lua require('sort-tf-blocks').sort_terraform_blocks_treesitter()`
3. Verify that the blocks are sorted according to the defined block order

You can also test with a file containing different block types:

1. Open the example file: `:e test/sample_terraform_with_block.tf`
2. Run the sorting command: `:lua require('sort-tf-blocks').sort_terraform_blocks_treesitter()`
3. Verify that all block types are correctly identified and sorted
