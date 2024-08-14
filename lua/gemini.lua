local config = require('gemini.config')

local M = {}

M.setup = function(opts)
  config.set_config(opts)

  -- local prompt = require('gemini.prompt')
  -- local chat = require('gemini.chat')
  -- prompt.setup()
  -- chat.setup()
  require('gemini.hint').setup()
  require('gemini.completion').setup()
end

return M
