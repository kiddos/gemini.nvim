local popup = require('plenary.popup')

local M = {}

M.borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰' }

M.open_window = function(content, options)
  options.borderchars = M.borderchars
  local win_id, result = popup.create(content, options)
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  local border = result.border
  vim.api.nvim_set_option_value('ft', 'markdown', { buf = bufnr })
  vim.api.nvim_set_option_value('wrap', true, { win = win_id })

  local close_popup = function()
    vim.api.nvim_win_close(win_id, true)
  end

  local keys = { '<C-q>', 'q' }
  for _, key in pairs(keys) do
    vim.api.nvim_buf_set_keymap(bufnr, 'n', key, '', {
      silent = true,
      callback = close_popup,
    })
  end
  return win_id, bufnr, border
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

return M
