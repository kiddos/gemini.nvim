local config = require('gemini.config')

local M = {}

M.setup = function(opts)
  config.set_config(opts)

  -- local prompt = require('gemini.prompt')
  require('gemini.chat').setup()
  -- prompt.setup()
  -- chat.setup()
  require('gemini.hint').setup()
  require('gemini.completion').setup()
end

return M
