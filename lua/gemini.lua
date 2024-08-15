local config = require('gemini.config')

local M = {}

M.setup = function(opts)
  config.set_config(opts)

  require('gemini.chat').setup()
  require('gemini.instruction').setup()
  require('gemini.hint').setup()
  require('gemini.completion').setup()
end

return M
