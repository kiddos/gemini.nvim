local config = require('gemini.config')
local prompt = require('gemini.prompt')
local completion = require('gemini.completion')
local chat = require('gemini.chat')
local hint = require('gemini.hint')

local M = {}

M.setup = function(opts)
  config.set_config(opts)

  prompt.setup()
  chat.setup()
  hint.setup(M)
  completion.setup(M)
end

-- this function is called from python
M.handle_async_callback = function(params)
  local callback = params.callback
  if not callback then
    return
  end

  local callback_fn = M[callback]
  if not callback_fn then
    return
  end

  callback_fn(params)
end

return M
