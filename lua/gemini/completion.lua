local config = require('gemini.config')

local M = {}

local context = {
  timer = nil,
  instruction_result = nil,
  chat = {
    response_bufnr = nil,
    input_bufnr = nil,
  },
  namespace_id = nil,
  completion = nil,
}

M.setup = function(module)
  context.namespace_id = vim.api.nvim_create_namespace('gemini_completion')

  vim.api.nvim_create_autocmd('CursorMovedI', {
    callback = function()
      pcall(M.handle_cursor_insert)
    end,
  })

  module.show_completion_result = M.show_completion_result

  vim.api.nvim_set_keymap('i', config.get_config().insert_result_key, '', {
    callback = function()
      M.insert_completion_result()
    end,
  })
end

M.handle_cursor_insert = function()
  M.gemini_complete()
end

M.gemini_complete = function()
  if context.timer then
    context.timer:stop()
  end

  context.timer = vim.defer_fn(function()
    if vim.fn.mode() ~= 'i' then
      return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()
    local pos = vim.api.nvim_win_get_cursor(win)

    local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    local prompt = 'Objective: Complete Code at line %d, column %d\n'
        .. 'Context:\n\n```%s\n%s\n```\n\n'
        .. 'Question:\n\nWhat code should be place at line %d, column %d?\n\nAnswer:\n\n'
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local code = vim.fn.join(lines, '\n')
    prompt = string.format(prompt, pos[1], pos[2], filetype, code, pos[1], pos[2])

    local options = {
      win_id = win,
      bufnr = bufnr,
      pos = pos,
      callback = 'show_completion_result',
      extract_code = true,
    }
    vim.api.nvim_call_function('_gemini_api_async', { options, prompt })
  end, config.get_config().instruction_delay)
end

M.show_completion_result = function(params)
  local content = params.result
  local source_win_id = params.win_id
  local row = params.row
  local col = params.col

  local win = vim.api.nvim_get_current_win()
  local pos = vim.api.nvim_win_get_cursor(win)
  if win ~= source_win_id or pos[1] ~= row or pos[2] ~= col then
    return
  end

  if vim.fn.pumvisible() ~= 0 then
    return
  end

  if vim.fn.mode() ~= 'i' then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  local options = {
    id = 1,
    virt_text = {},
    virt_lines = {},
    hl_mode = 'combine',
    virt_text_pos = 'overlay',
  }

  for i, l in pairs(vim.split(content, '\n')) do
    if i == 1 then
      options.virt_text[1] = { l, 'Comment' }
    else
      options.virt_lines[i - 1] = { { l, 'Comment' } }
    end
  end
  local id = vim.api.nvim_buf_set_extmark(bufnr, context.namespace_id, row - 1, col, options)

  context.completion = {
    content = content,
    row = row,
    col = col,
    bufnr = bufnr,
  }

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertLeavePre' }, {
    buffer = bufnr,
    callback = function()
      context.completion = nil
      vim.api.nvim_buf_del_extmark(bufnr, context.namespace_id, id)
      vim.api.nvim_command('redraw')
    end,
    once = true,
  })
end

M.insert_completion_result = function()
  if not context.completion then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if not context.completion.bufnr == bufnr then
    return
  end

  local row = context.completion.row - 1
  local col = context.completion.col
  local first_line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
  local lines = vim.split(context.completion.content, '\n')
  lines[1] = string.sub(first_line, 1, col) .. lines[1]
  vim.api.nvim_buf_set_lines(bufnr, row, row, false, lines)
  context.completion = nil
end

return M
