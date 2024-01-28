local popup = require('plenary.popup')
local config = require('gemini.config')

local M = {}

local context = {
  timer = nil,
  opened_win = nil,
  border_win = nil,
  content_bufnr = nil,
  border_bufnr = nil,
  instruction_result = nil,
}

local borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰' }

M.setup = function(opts)
  config.set_config(opts)

  local register_menu = function(name, command_name, menu, system_prompt)
    local gemini = function()
      M.show_stream_response(name, system_prompt)
    end

    vim.api.nvim_create_user_command(command_name, gemini, {
      force = true,
      desc = 'Google Gemini',
    })

    vim.api.nvim_command('nnoremenu Gemini.' .. menu:gsub(' ', '\\ ') .. ' :' .. command_name .. '<CR>')
  end

  for _, item in pairs(config.get_menu_prompts()) do
    register_menu(item.name, item.command_name, item.menu, item.prompt)
  end

  local register_keymap = function(mode, keymap)
    vim.api.nvim_set_keymap(mode, keymap, '', {
      expr = true,
      noremap = true,
      silent = true,
      callback = function()
        if vim.fn.pumvisible() == 0 then
          vim.api.nvim_command('popup Gemini')
        end
      end
    })
  end

  local modes = { 'i', 'n', 'v' }
  for _, mode in pairs(modes) do
    register_keymap(mode, config.get_config().menu_key)
  end

  vim.api.nvim_create_autocmd('CursorMoved', {
    callback = function()
      M.close_existing()
      pcall(M.handle_cursor_normal)
    end,
  })

  vim.api.nvim_create_autocmd('CursorMovedI', {
    callback = function()
      M.close_existing()
      pcall(M.handle_cursor_insert)
    end,
  })

  vim.api.nvim_set_keymap('n', '<S-Tab>', '', {
    callback = function()
      M.insert_instruction_result()
    end,
  })
end

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

M.prepare_code_prompt = function(prompt, bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local code = vim.fn.join(lines, '\n')
  local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
  local code_markdown = '```' .. filetype .. '\n' .. code .. '\n```'
  return prompt .. '\n\n' .. code_markdown
end

M.show_stream_response = function(name, system_prompt)
  local current = vim.api.nvim_get_current_buf()
  local padding = { 10, 3 }
  local width = vim.api.nvim_win_get_width(0) - padding[1] * 2
  local height = vim.api.nvim_win_get_height(0) - padding[2] * 2
  local win_id, bufnr = M.open_window({}, {
    title = 'Gemini - ' .. name,
    minwidth = width,
    minheight = height
  })
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = bufnr })

  local prompt = M.prepare_code_prompt(system_prompt, current)
  vim.defer_fn(function()
    vim.api.nvim_call_function('_gemini_api_stream_async', { bufnr, win_id, prompt })
  end, 0)
end

M.open_window = function(content, options)
  options.borderchars = borderchars
  local win_id, result = popup.create(content, options)
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  local border = result.border
  vim.api.nvim_set_option_value('ft', 'markdown', { buf = bufnr })
  vim.api.nvim_set_option_value('wrap', true, { win = win_id })

  local close_popup = function()
    vim.api.nvim_win_hide(win_id)
    vim.api.nvim_win_close(win_id, true)
  end

  vim.api.nvim_buf_set_keymap(bufnr, 'n', '<C-q>', '', {
    silent = true,
    callback = close_popup,
  })
  return win_id, bufnr, border
end

M.close_existing = function()
  if context.timer then
    context.timer:stop()
    context.timer = nil
  end

  if context.content_bufnr then
    vim.api.nvim_buf_delete(context.content_bufnr, { force = true })
    context.content_bufnr = nil
  end

  if context.border_bufnr then
    vim.api.nvim_buf_delete(context.border_bufnr, { force = true })
    context.border_bufnr = nil
  end
end

M.treesitter_has_lang = function(bufnr)
  local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
  local lang = vim.treesitter.language.get_lang(filetype)
  return lang ~= nil
end

M.find_node_by_type = function(node_type)
  local node = vim.treesitter.get_node()
  while node do
    local type = node:type()
    if string.find(type, node_type) then
      return node
    end

    local parent = node:parent()
    if parent == node then
      break
    end
    node = parent
  end
  return nil
end

M.handle_cursor_normal = function()
  local bufnr = vim.api.nvim_get_current_buf()
  if not M.treesitter_has_lang(bufnr) then
    return
  end

  local node = M.find_node_by_type('function')
  local disabled = os.getenv('DISABLE_GEMINI_INLINE')
  if node and not disabled then
    M.show_quick_hints(node, bufnr)
    return
  end

  node = M.find_node_by_type('comment')
  if node then
    M.show_instruction_result(node, bufnr)
    return
  end
end

M.show_quick_hints = function(node, bufnr)
  local win = vim.api.nvim_get_current_win()
  local pos = vim.api.nvim_win_get_cursor(win)
  local row = node:range()
  if pos[1] ~= row + 1 then
    return
  end

  local mode = vim.api.nvim_get_mode()
  if mode.mode ~= 'n' then
    return
  end

  context.timer = vim.defer_fn(function()
    local code_block = vim.treesitter.get_node_text(node, bufnr)
    local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    local prompt = config.get_hints_prompt()
    prompt = prompt:gsub('{filetype}', filetype)
    prompt = prompt:gsub('{code_block}', code_block)

    local options = {
      win_id = win,
      pos = pos,
      callback = 'open_quick_hint_window',
    }
    vim.api.nvim_call_function('_gemini_api_async', { options, prompt })
  end, config.get_config().hints_delay)
end

M.open_quick_hint_window = function(params)
  local mode = vim.api.nvim_get_mode()
  if mode.mode ~= 'n' then
    return
  end

  local content = params.result
  local source_win_id = params.win_id
  local row = params.row
  local col = params.col

  local win = vim.api.nvim_get_current_win()
  local pos = vim.api.nvim_win_get_cursor(win)
  if win ~= source_win_id or pos[1] ~= row or pos[2] ~= col then
    return
  end

  local current_mode = vim.api.nvim_get_mode()
  if current_mode.mode ~= 'n' then
    return
  end

  local response_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(response_bufnr, 0, -1, false, vim.split(content, '\n'))

  local options = {
    minwidth = 40,
    minheight = 6,
    line = 'cursor-7',
    col = 'cursor+3',
    pos = 'topleft',
    enter = false,
    borderchars = borderchars,
  }
  if row <= 8 then
    options.line = 'cursor+1'
    options.pos = 'botleft'
  end
  local win_id, result = popup.create(response_bufnr, options)
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  local border = result.border
  vim.api.nvim_set_option_value('ft', 'markdown', { buf = bufnr })
  vim.api.nvim_set_option_value('wrap', true, { win = win_id })

  context.opened_win = win_id
  context.content_bufnr = response_bufnr
  context.border_win = border.win_id
  context.border_bufnr = border.bufnr
end

M.handle_cursor_insert = function()
  local bufnr = vim.api.nvim_get_current_buf()
  if not M.treesitter_has_lang(bufnr) then
    return
  end

  local node = M.find_node_by_type('comment')
  if node then
    M.show_instruction_result(node, bufnr)
    return
  end
end

M.show_instruction_result = function(node, bufnr)
  context.timer = vim.defer_fn(function()
    local win = vim.api.nvim_get_current_win()
    local pos = vim.api.nvim_win_get_cursor(win)
    local instruction = vim.treesitter.get_node_text(node, bufnr)
    local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    local prompt = config.get_instruction_prompt()
    local filename = vim.fn.expand('%')
    prompt = prompt:gsub('{filetype}', filetype)
    prompt = prompt:gsub('{instruction}', instruction)
    prompt = prompt:gsub('{filename}', filename)

    local options = {
      win_id = win,
      pos = pos,
      callback = 'open_instruction_result',
      extract_code = true,
    }
    print('instructing gemini...')
    vim.api.nvim_call_function('_gemini_api_async', { options, prompt })
  end, config.get_config().instruction_delay)
end

M.open_instruction_result = function(params)
  local content = params.result
  local source_win_id = params.win_id
  local row = params.row
  local col = params.col

  local win = vim.api.nvim_get_current_win()
  local pos = vim.api.nvim_win_get_cursor(win)
  if win ~= source_win_id or pos[1] ~= row or pos[2] ~= col then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
  local response_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('ft', filetype, { buf = response_bufnr })
  vim.api.nvim_buf_set_lines(response_bufnr, 0, -1, false, vim.split(content, '\n'))

  local max_height = vim.fn.winheight(win) - vim.fn.winline()
  if max_height <= 0 then
    return
  end

  local options = {
    minwidth = 60,
    minheight = 6,
    maxheight = max_height,
    line = 'cursor+1',
    col = 'cursor-' .. tostring(pos[2]),
    enter = false,
  }
  local win_id = popup.create(response_bufnr, options)
  context.opened_win = win_id
  context.content_bufnr = vim.api.nvim_win_get_buf(win_id)

  context.instruction_result = {
    bufnr = bufnr,
    row = pos[1] - 1,
    content = content
  }
end

M.insert_instruction_result = function()
  if not context.instruction_result then
    return
  end

  local row = context.instruction_result.row
  local bufnr = context.instruction_result.bufnr
  local content = context.instruction_result.content
  vim.api.nvim_buf_set_lines(bufnr, row, row+1, false, vim.split(content, '\n'))

  M.close_existing()
  context.instruction_result = nil
end

return M
