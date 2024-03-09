local util = require('gemini.util')

local M = {}

M.setup = function()
  vim.api.nvim_create_user_command('GeminiChat', M.start_chat, {
    force = true,
    desc = 'Google Gemini',
  })
end

M.start_chat = function()
  local padding = { 10, 6 }
  local width = vim.api.nvim_win_get_width(0) - padding[1] * 2
  local height = vim.api.nvim_win_get_height(0) - padding[2] * 2
  local response_win_id, response_bufnr = util.open_window({}, {
    title = 'Gemini Chat',
    minwidth = width,
    minheight = height
  })

  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = response_bufnr })
  vim.api.nvim_set_option_value('readonly', true, { buf = response_bufnr })

  local input_win_id, input_bufnr = util.open_window({}, {
    minwidth = width,
    minheight = 3,
    line = height + padding[2] + 4,
  })

  local modes = { 'i', 'n' }
  for _, mode in pairs(modes) do
    vim.api.nvim_buf_set_keymap(input_bufnr, mode, '<CR>', '', {
      callback = function()
        local lines = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)
        local all_inputs = vim.fn.join(lines, '\n')
        local context = {
          win_id = response_win_id,
          bufnr = response_bufnr,
        }
        vim.api.nvim_call_function('_generative_ai_chat', { context, all_inputs })
        vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, false, {})
      end
    })
  end

  local bufs = { input_bufnr, response_bufnr }

  local close_bufs = function()
    pcall(function()
      vim.api.nvim_buf_delete(input_bufnr, { force = true })
      vim.api.nvim_buf_delete(response_bufnr, { force = true })
    end)
  end

  for _, bufnr in pairs(bufs) do
    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<C-q>', '', {
      callback = function()
        close_bufs()
      end
    })

    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<C-u>', '', {
      callback = function()
        vim.api.nvim_set_current_win(response_win_id)
      end
    })

    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<C-d>', '', {
      callback = function()
        vim.api.nvim_set_current_win(input_win_id)
      end
    })
  end

  for _, bufnr in pairs(bufs) do
    vim.api.nvim_create_autocmd('WinLeave', {
      buffer = bufnr,
      callback = function()
        vim.defer_fn(function()
          local current = vim.api.nvim_get_current_buf()
          if current ~= response_bufnr and current ~= input_bufnr then
            close_bufs()
          end
        end, 0)
      end
    })
  end
end

return M
