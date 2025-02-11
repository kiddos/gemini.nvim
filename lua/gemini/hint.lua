local config = require('gemini.config')
local util = require('gemini.util')
local api = require('gemini.api')

local M = {}

local context = {
  hint = nil,
  namespace_id = nil,
}

M.setup = function()
  if not config.get_config({ 'hints', 'enabled' }) then
    return
  end

  vim.api.nvim_create_user_command('GeminiFunctionHint', M.show_function_hints, {
    force = true,
    desc = 'Google Gemini function explaination',
  })

  context.namespace_id = vim.api.nvim_create_namespace('gemini_hints')

  vim.api.nvim_set_keymap('n', config.get_config({ 'hints', 'insert_result_key' }) or '<S-Tab>', '', {
    callback = function()
      M.insert_hint_result()
    end,
  })
end

M.show_function_hints = function()
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

M.show_quick_hints = util.debounce(function(node, bufnr)
  local mode = vim.api.nvim_get_mode()
  if mode.mode ~= 'n' then
    return
  end

  local get_prompt = config.get_config({ 'hints', 'get_prompt' })
  if not get_prompt then
    return
  end

  local win = vim.api.nvim_get_current_win()
  local row = node:range()
  local user_text = get_prompt(node, bufnr)

  local generation_config = config.get_gemini_generation_config()
  local model_id = config.get_config({ 'model', 'model_id' })
  api.gemini_generate_content(user_text, nil, model_id, generation_config, function(result)
    local json_text = result.stdout
    if json_text and #json_text > 0 then
      local model_response = vim.json.decode(json_text)
      model_response = util.table_get(model_response, { 'candidates', 1, 'content',
        'parts', 1, 'text' })
      if model_response ~= nil and #model_response > 0 then
        vim.schedule(function()
          if #model_response > 0 then
            M.show_quick_hint_text(model_response, win, { row + 1, 1 })
          end
        end)
      end
    end
  end)
end, config.get_config({ 'hints', 'hints_delay' }) or 2000)

M.show_quick_hint_text = function(content, win, pos)
  local mode = vim.api.nvim_get_mode()
  if mode.mode ~= 'n' then
    return
  end

  local row = pos[1]
  local col = pos[2]

  local current_win = vim.api.nvim_get_current_win()
  if current_win ~= win then
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
