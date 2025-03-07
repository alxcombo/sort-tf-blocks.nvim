describe("sort-tf-blocks", function()
	local sort_tf
	local mock = {
		lines = {},
		notifications = {},
	}

	-- Setup function to run before each test
	before_each(function()
		-- Load the module
		sort_tf = require("sort-tf-blocks")

		-- Configure the plugin
		sort_tf.setup({
			verbosity = 2, -- Verbose for testing
			block_order = { -- Define the order of block types
				"variable",
				"data",
				"resource",
				"module",
				"output",
			},
		})

		-- Save original functions
		mock.original_nvim_buf_get_lines = vim.api.nvim_buf_get_lines
		mock.original_nvim_buf_set_lines = vim.api.nvim_buf_set_lines
		mock.original_notify = vim.notify

		-- Mock buffer lines
		vim.api.nvim_buf_get_lines = function(_, start, end_, _)
			if end_ == -1 then
				return vim.tbl_map(function(v)
					return v
				end, mock.lines)
			else
				local result = {}
				for i = start + 1, end_ do
					table.insert(result, mock.lines[i])
				end
				return result
			end
		end

		-- Mock setting buffer lines
		vim.api.nvim_buf_set_lines = function(_, start, end_, _, lines)
			if start == 0 and end_ == -1 then
				mock.lines = vim.tbl_map(function(v)
					return v
				end, lines)
			end
		end

		-- Mock notifications
		vim.notify = function(msg, level, opts)
			table.insert(mock.notifications, {
				message = msg,
				level = level,
				opts = opts,
			})
		end

		-- Reset mocks
		mock.lines = {
			"# Terraform configuration",
			"",
			'resource "aws_s3_bucket" "example" {',
			'  bucket = "my-bucket"',
			"}",
			"",
			'variable "region" {',
			'  default = "us-west-2"',
			"}",
			"",
			"# Standalone comment",
			"",
			'module "vpc" {',
			'  source = "terraform-aws-modules/vpc/aws"',
			"}",
		}
		mock.notifications = {}
	end)

	-- Teardown function to run after each test
	after_each(function()
		-- Restore original functions
		vim.api.nvim_buf_get_lines = mock.original_nvim_buf_get_lines
		vim.api.nvim_buf_set_lines = mock.original_nvim_buf_set_lines
		vim.notify = mock.original_notify
	end)

	-- Helper function to mock treesitter parser
	local function mock_treesitter(blocks)
		-- Create a mock tree structure
		local nodes = {}

		for i, block_data in ipairs(blocks) do
			local node = {
				type = function()
					return block_data.type
				end,
				range = function()
					return block_data.start_row, 0, block_data.end_row, 0
				end,
				iter_children = function(self)
					local idx = 0
					return function()
						idx = idx + 1
						return nil -- No children for leaf nodes in this simple test
					end
				end,
			}
			nodes[i] = node
		end

		-- Root node that contains all blocks
		local root = {
			type = function()
				return "module"
			end,
			iter_children = function(self)
				local idx = 0
				return function()
					idx = idx + 1
					return nodes[idx]
				end
			end,
		}

		-- Mock parser
		vim.treesitter.get_parser = function()
			return {
				parse = function()
					return {
						{
							root = function()
								return root
							end,
						},
					}
				end,
			}
		end
	end

	describe("sort_terraform_blocks_treesitter", function()
		it("should sort terraform blocks by type and then alphabetically", function()
			-- Mock treesitter parser with blocks in the same order as in the file
			mock_treesitter({
				{
					type = "resource",
					start_row = 2,
					end_row = 4,
				},
				{
					type = "variable",
					start_row = 6,
					end_row = 8,
				},
				{
					type = "module",
					start_row = 12,
					end_row = 14,
				},
			})

			-- Run the sort function
			sort_tf.sort_terraform_blocks_treesitter()

			-- Expected order after sorting: variable (priority 1), resource (priority 3), module (priority 4)
			local expected_lines = {
				"# Terraform configuration",
				"# Standalone comment",
				"",
				'variable "region" {',
				'  default = "us-west-2"',
				"}",
				"",
				'resource "aws_s3_bucket" "example" {',
				'  bucket = "my-bucket"',
				"}",
				"",
				'module "vpc" {',
				'  source = "terraform-aws-modules/vpc/aws"',
				"}",
			}

			-- Check if the lines were sorted correctly
			assert.are.same(expected_lines, mock.lines)
		end)

		it("should send a notification when blocks are sorted", function()
			-- Mock treesitter parser
			mock_treesitter({
				{
					type = "resource",
					start_row = 2,
					end_row = 4,
				},
				{
					type = "variable",
					start_row = 6,
					end_row = 8,
				},
				{
					type = "module",
					start_row = 12,
					end_row = 14,
				},
			})

			-- Run the sort function
			sort_tf.sort_terraform_blocks_treesitter()

			-- Check if notification was sent
			assert.are.equal(1, #mock.notifications)
			assert.are.equal("Terraform blocks have been sorted.", mock.notifications[1].message)
		end)

		it("should handle empty files", function()
			-- Empty file
			mock.lines = {}

			-- Mock treesitter parser with no blocks
			mock_treesitter({})

			-- Run the sort function
			sort_tf.sort_terraform_blocks_treesitter()

			-- Check if notification was sent
			assert.are.equal(1, #mock.notifications)
			assert.are.equal("No Terraform blocks found in the file.", mock.notifications[1].message)
		end)

		it("should not change the file if blocks are already sorted", function()
			-- Already sorted blocks by type priority
			mock.lines = {
				'variable "region" {',
				'  default = "us-west-2"',
				"}",
				"",
				'resource "aws_s3_bucket" "example" {',
				'  bucket = "my-bucket"',
				"}",
				"",
				'module "vpc" {',
				'  source = "terraform-aws-modules/vpc/aws"',
				"}",
			}

			-- Mock treesitter parser with blocks in sorted order
			mock_treesitter({
				{
					type = "variable",
					start_row = 0,
					end_row = 2,
				},
				{
					type = "resource",
					start_row = 4,
					end_row = 6,
				},
				{
					type = "module",
					start_row = 8,
					end_row = 10,
				},
			})

			-- Store original lines
			local original_lines = vim.tbl_map(function(v)
				return v
			end, mock.lines)

			-- Run the sort function
			sort_tf.sort_terraform_blocks_treesitter()

			-- Check if the lines were not changed
			assert.are.same(original_lines, mock.lines)

			-- Check if notification was sent
			assert.are.equal(1, #mock.notifications)
			assert.are.equal("No changes in Terraform blocks.", mock.notifications[1].message)
		end)

		it("should handle block type correctly for data and resource blocks", function()
			-- Set up mock lines with data, module and resource blocks
			mock.lines = {
				'data "aws_iam_policy_document" "rds_enhanced_monitoring" {',
				"  statement {",
				"    actions = [",
				'      "sts:AssumeRole",',
				"    ]",
				'    effect = "Allow"',
				"    principals {",
				'      type        = "Service"',
				'      identifiers = ["monitoring.rds.amazonaws.com"]',
				"    }",
				"  }",
				"}",
				"",
				'module "rds" {',
				'  source = "terraform-aws-modules/rds/aws"',
				'  version = "6.10.0"',
				"}",
				"",
				'resource "aws_iam_role" "rds_enhanced_monitoring" {',
				"  assume_role_policy = data.aws_iam_policy_document.rds_enhanced_monitoring.json",
				'  name_prefix        = "${var.naming_prefix}-monitoring-"',
				"}",
			}

			-- Mock treesitter parser with blocks
			mock_treesitter({
				{
					type = "block", -- data block is detected as "block" type
					start_row = 0,
					end_row = 11,
				},
				{
					type = "module",
					start_row = 13,
					end_row = 16,
				},
				{
					type = "resource",
					start_row = 18,
					end_row = 21,
				},
			})

			-- Run the sort function
			sort_tf.sort_terraform_blocks_treesitter()

			-- Expected order: data, resource, module (according to block_order)
			local expected_lines = {
				'data "aws_iam_policy_document" "rds_enhanced_monitoring" {',
				"  statement {",
				"    actions = [",
				'      "sts:AssumeRole",',
				"    ]",
				'    effect = "Allow"',
				"    principals {",
				'      type        = "Service"',
				'      identifiers = ["monitoring.rds.amazonaws.com"]',
				"    }",
				"  }",
				"}",
				"",
				'resource "aws_iam_role" "rds_enhanced_monitoring" {',
				"  assume_role_policy = data.aws_iam_policy_document.rds_enhanced_monitoring.json",
				'  name_prefix        = "${var.naming_prefix}-monitoring-"',
				"}",
				"",
				'module "rds" {',
				'  source = "terraform-aws-modules/rds/aws"',
				'  version = "6.10.0"',
				"}",
			}

			-- Check if the lines were sorted correctly
			assert.are.same(expected_lines, mock.lines)
		end)
	end)
end)
