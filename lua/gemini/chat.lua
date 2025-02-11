local config = require('gemini.config')
local util = require('gemini.util')
local api = require('gemini.api')

local M = {}

M.setup = function()
  if not config.get_config({ 'chat', 'enabled' }) then
    return
  end

  vim.api.nvim_create_user_command('GeminiChat', M.start_chat, {
    force = true,
    desc = 'Google Gemini',
    nargs = 1,
  })
end

M.start_chat = function(context)
  vim.api.nvim_command('tabnew')
  local user_text = context.args
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_set_option_value('ft', 'markdown', { buf = bufnr })
  local lines = { 'Generating response...' }
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  local generation_config = config.get_gemini_generation_config()
  local text = ''
  local model_id = config.get_config({ 'model', 'model_id' })
  api.gemini_generate_content_stream(user_text, model_id, generation_config, function(json_text)
    local model_response = vim.json.decode(json_text)
    model_response = util.table_get(model_response, { 'candidates', 1, 'content', 'parts', 1, 'text' })
    if not model_response then
      return
    end

    text = text .. model_response
    vim.schedule(function()
      lines = vim.split(text, '\n')
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end)
  end)
end

return M
