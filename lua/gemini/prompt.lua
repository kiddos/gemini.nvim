local config = require('gemini.config')
local util = require('gemini.util')

local M = {}

M.setup = function()
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

  local modes = { 'n' }
  for _, mode in pairs(modes) do
    register_keymap(mode, config.get_config().menu_key)
  end
end

M.prepare_code_prompt = function(prompt, bufnr)
  local wrap_code = function(code)
    local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    local code_markdown = '```' .. filetype .. '\n' .. code .. '\n```'
    return prompt .. '\n\n' .. code_markdown
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local code = vim.fn.join(lines, '\n')
  return wrap_code(code)
end

M.show_stream_response = function(name, system_prompt)
  local current = vim.api.nvim_get_current_buf()
  local padding = { 10, 3 }
  local width = vim.api.nvim_win_get_width(0) - padding[1] * 2
  local height = vim.api.nvim_win_get_height(0) - padding[2] * 2
  local win_id, bufnr = util.open_window({}, {
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

return M
