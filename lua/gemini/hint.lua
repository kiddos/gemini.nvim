local config = require('gemini.config')
local util = require('gemini.util')
local popup = require('plenary.popup')

local M = {}

local context = {
  timer = nil,
  hint = nil,
  namespace_id = nil,
}

M.setup = function(module)
  vim.api.nvim_create_user_command('GeminiFunctionHint', M.show_function_hints, {
    force = true,
    desc = 'Google Gemini function explaination',
  })

  context.namespace_id = vim.api.nvim_create_namespace('gemini_hints')
  module.show_quick_hint_text = M.show_quick_hint_text

  vim.api.nvim_set_keymap('n', config.get_config().insert_result_key, '', {
    callback = function()
      M.insert_hint_result()
    end,
  })
end

M.show_function_hints = function()
  local disabled = os.getenv('DISABLE_GEMINI_INLINE')
  if disabled then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if not util.treesitter_has_lang(bufnr) then
    return
  end

  local node = util.find_node_by_type('function')
  if node then
    M.show_quick_hints(node, bufnr)
    return
  end
end

M.show_quick_hints = function(node, bufnr)
  local win = vim.api.nvim_get_current_win()
  local row = node:range()

  local mode = vim.api.nvim_get_mode()
  if mode.mode ~= 'n' then
    return
  end

  if context.timer then
    context.timer:stop()
  end

  context.timer = vim.defer_fn(function()
    local code_block = vim.treesitter.get_node_text(node, bufnr)
    local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    local prompt = config.get_hints_prompt()
    prompt = prompt:gsub('{filetype}', filetype)
    prompt = prompt:gsub('{code_block}', code_block)

    local options = {
      win_id = win,
      pos = { row + 1, 1 },
      callback = 'show_quick_hint_text',
    }
    vim.api.nvim_call_function('_gemini_api_async', { options, prompt })
  end, config.get_config().hints_delay)
end

M.show_quick_hint_text = function(params)
  local mode = vim.api.nvim_get_mode()
  if mode.mode ~= 'n' then
    return
  end

  local content = params.result
  local source_win_id = params.win_id
  local row = params.row
  local col = params.col

  local win = vim.api.nvim_get_current_win()
  if win ~= source_win_id then
    return
  end

  local options = {
    id = 2,
    virt_lines = {},
    hl_mode = 'combine',
    virt_text_pos = 'overlay',
    virt_lines_above = true,
  }

  for i, l in pairs(vim.split(content, '\n')) do
    options.virt_lines[i] = { { l, 'Comment' } }
  end

  local id = vim.api.nvim_buf_set_extmark(0, context.namespace_id, row - 1, col - 1, options)

  local bufnr = vim.api.nvim_get_current_buf()
  context.hints = {
    content = content,
    row = row,
    col = col,
    bufnr = bufnr,
  }

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertLeavePre' }, {
    buffer = bufnr,
    callback = function()
      context.hints = nil
      vim.api.nvim_buf_del_extmark(bufnr, context.namespace_id, id)
      vim.api.nvim_command('redraw')
    end,
    once = true,
  })
end

M.insert_hint_result = function()
  if not context.hints then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if not context.hints.bufnr == bufnr then
    return
  end

  local row = context.hints.row - 1
  local lines = vim.split(context.hints.content, '\n')
  vim.api.nvim_buf_set_lines(bufnr, row, row, false, lines)
  context.hints = nil
end

return M
