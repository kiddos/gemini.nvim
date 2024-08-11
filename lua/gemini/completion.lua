local uv = vim.loop or vim.uv

local config = require('gemini.config')
local util = require('gemini.util')

local M = {}

local context = {
  namespace_id = nil,
  completion = nil,
  pipe = uv.pipe({ noneblock = true }, { noneblock = true })
}

M.setup = function()
  context.namespace_id = vim.api.nvim_create_namespace('gemini_completion')

  vim.api.nvim_create_autocmd('CursorMovedI', {
    callback = function()
      M.gemini_complete()
    end,
  })

  vim.api.nvim_set_keymap('i', config.get_config({ 'completion', 'insert_result_key' }) or '<S-Tab>', '', {
    callback = function()
      M.insert_completion_result()
    end,
  })
end

M.strip_code = function(text)
  local code_blocks = {}
  local pattern = "```(%w+)%s*(.-)%s*```"
  for _, code_block in text:gmatch(pattern) do
    table.insert(code_blocks, code_block)
  end
  return code_blocks
end

M.gemini_complete = util.debounce(function()
  if vim.fn.mode() ~= 'i' then
    return
  end

  local get_prompt = config.get_config({ 'completion', 'get_prompt' })
  if not get_prompt then
    return
  end

  local win = vim.api.nvim_get_current_win()
  local pos = vim.api.nvim_win_get_cursor(win)
  local prompt = get_prompt()

  -- prepare pipes
  local write_pipe = uv.new_pipe()
  write_pipe:open(context.pipe.write)
  local read_pipe = uv.new_pipe()
  read_pipe:open(context.pipe.read)

  uv.new_thread(function(prompt, write_pipe)
    local api = require('gemini.api')
    local model_response = api.gemini_generate_content(prompt, api.MODELS.GEMINI_1_0_PRO)
    write_pipe:write(model_response)
  end, prompt, write_pipe)

  read_pipe:read_start(function(err, chunk)
    if not err then
      vim.schedule(function()
        local code_blocks = M.strip_code(chunk)
        local single_code_block = vim.fn.join(code_blocks, '\n')
        M.show_completion_result(single_code_block, win, pos)
      end)
    end
  end)
end, config.get_config({ 'completion', 'completion_delay' }) or 1000)

M.show_completion_result = function(result, win_id, pos)
  local win = vim.api.nvim_get_current_win()
  if win ~= win_id then
    return
  end

  local current_pos = vim.api.nvim_win_get_cursor(win)
  if current_pos[1] ~= pos[1] or current_pos[2] ~= pos[2] then
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

  local content = result
  for i, l in pairs(vim.split(content, '\n')) do
    if i == 1 then
      options.virt_text[1] = { l, 'Comment' }
    else
      options.virt_lines[i - 1] = { { l, 'Comment' } }
    end
  end
  local row = pos[1]
  local col = pos[2]
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
