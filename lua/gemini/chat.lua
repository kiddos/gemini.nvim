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

local chat_winnr = nil
local chat_number = 0

local function get_bufnr(user_text)
  local conf = config.get_config({ 'chat' })
  local bufnr = nil
  if not chat_winnr or not vim.api.nvim_win_is_valid(chat_winnr) or conf.window.position == 'new_tab' then
    if conf.window.position == 'tab' or conf.window.position == 'new_tab' then
      vim.api.nvim_command('tabnew')
    elseif conf.window.position == 'left' then
      vim.api.nvim_command('vertical topleft split new')
      vim.api.nvim_win_set_width(0, conf.window.width or 80)
    elseif conf.window.position == 'right' then
      vim.api.nvim_command('rightbelow vnew')
      vim.api.nvim_win_set_width(0, conf.window.width or 80)
    end
    chat_winnr = vim.api.nvim_tabpage_get_win(0)
    bufnr = vim.api.nvim_win_get_buf(0)
  end
  vim.api.nvim_set_current_win(chat_winnr)
  bufnr = bufnr or vim.api.nvim_win_get_buf(0)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('ft', 'markdown', { buf = bufnr })
  vim.api.nvim_buf_set_name(bufnr, 'Chat' .. chat_number .. ': ' .. user_text)

  return vim.api.nvim_win_get_buf(0)
end

M.start_chat = function(context)
  local user_text = context.args
  chat_number = chat_number + 1
  local bufnr = get_bufnr(user_text)
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
