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
  local model_id = config.get_config({ 'model', 'model_id' })

  api.gemini_generate_content(user_text, nil, model_id, generation_config, function(obj)
    if obj.code ~= 0 then
      vim.notify("Gemini API Error: " .. vim.inspect(obj), vim.log.levels.ERROR)
      return
    end

    local data = obj.stdout
    if data == "" or data == nil then
      vim.notify("Gemini API returned empty response.", vim.log.levels.ERROR)
      return
    end

    local response_data = vim.json.decode(data)
    if not response_data then
      vim.notify("Failed to decode Gemini API response: " .. data, vim.log.levels.ERROR)
      return
    end

    local model_response = util.table_get(response_data, { 'candidates', 1, 'content', 'parts', 1, 'text' })
    if not model_response then
      vim.notify("Unexpected API response structure: " .. data, vim.log.levels.ERROR)
      return
    end

    vim.schedule(function()
      lines = vim.split(model_response, '\n')
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end)
  end)
end


return M
