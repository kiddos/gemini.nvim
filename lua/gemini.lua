local config = require('gemini.config')

local M = {}

M.setup = function(opts)
  if not vim.fn.executable('curl') then
    vim.notify('curl is not found', vim.log.levels.WARN)
    return
  end

  config.set_config(opts)

  require('gemini.chat').setup()
  require('gemini.instruction').setup()
  require('gemini.hint').setup()
  require('gemini.completion').setup()
end

return M
