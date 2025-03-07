-- Setup test environment for Neovim plugins
local function setup_test_env()
  -- Add the plugin directory to the Lua path
  package.path = package.path .. ";../lua/?.lua;../lua/?/init.lua"

  -- Mock vim global
  _G.vim = {
    api = {
      nvim_buf_get_lines = function() return {} end,
      nvim_buf_set_lines = function() end,
      nvim_set_keymap = function() end
    },
    notify = function() end,
    log = {
      levels = {
        INFO = 2,
        WARN = 3,
        ERROR = 4
      }
    },
    tbl_map = function(fn, t)
      local result = {}
      for k, v in pairs(t) do
        result[k] = fn(v)
      end
      return result
    end,
    tbl_deep_extend = function(behavior, t1, t2)
      local result = {}
      for k, v in pairs(t1) do
        result[k] = v
      end
      for k, v in pairs(t2) do
        if type(v) == "table" and type(result[k]) == "table" then
          result[k] = vim.tbl_deep_extend(behavior, result[k], v)
        else
          result[k] = v
        end
      end
      return result
    end,
    treesitter = {
      get_parser = function() end
    }
  }

  -- Return the mocked vim object for further customization
  return _G.vim
end

-- Setup the test environment
setup_test_env()
