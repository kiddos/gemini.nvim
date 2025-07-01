local config = require('gemini.config')

local M = {}

local function is_nvim_version_ge(major, minor, patch)
  local v = vim.version()
  if v.major > major then
    return true
  elseif v.major == major then
    if v.minor > minor then
      return true
    elseif v.minor == minor and v.patch >= patch then
      return true
    end
  end
  return false
end

M.setup = function(opts)
  if not vim.fn.executable('curl') then
    vim.notify('curl is not found', vim.log.levels.WARN)
    return
  end

  if not is_nvim_version_ge(0, 10, 0) then
    vim.notify('neovim version too old', vim.log.levels.WARN)
    return
  end

  config.set_config(opts)

  require('gemini.chat').setup()
  require('gemini.instruction').setup()
  require('gemini.hint').setup()
  require('gemini.completion').setup()
  require('gemini.task').setup()
end

return M
