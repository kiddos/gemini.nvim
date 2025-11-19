local config = require('gemini.config')
local util = require('gemini.util')
local api = require('gemini.api')

local M = {}

M.setup = function()
  local model = config.get_config({ 'instruction', 'model' })
  if not model or not model.model_id then
    return
  end

  local register_menu = function(prompt_item)
    local get_prompt = prompt_item.get_prompt
    if not get_prompt then
      return
    end

    local command_name = prompt_item.command_name
    if not command_name then
      return
    end

    local gemini_generate = function(context)
      local bufnr = vim.api.nvim_get_current_buf()
      local lines
      if not context.line1 or not context.line2 or context.line1 == context.line2 then
        lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      else
        lines = vim.api.nvim_buf_get_lines(bufnr, context.line1 - 1, context.line2 - 1, false)
      end
      local user_text = get_prompt(lines, bufnr)

      local generation_config = config.get_gemini_generation_config('instruction')

      vim.api.nvim_command('tabnew')
      local new_buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_set_option_value('filetype', 'markdown', { buf = new_buf })
      local model_id = config.get_config({ 'instruction', 'model', 'model_id' })
      local text = ''
      api.gemini_generate_content_stream(user_text, model_id, generation_config, function(json_text)
        local model_response = vim.json.decode(json_text)
        model_response = util.table_get(model_response, { 'candidates', 1, 'content', 'parts', 1, 'text' })
        text = text .. model_response
        vim.schedule(function()
          lines = vim.split(text, '\n')
          vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, lines)
        end)
      end)
    end

    vim.api.nvim_create_user_command(command_name, gemini_generate, {
      range = true,
    })

    local menu = prompt_item.menu
    if menu then
      menu = menu:gsub(' ', '\\ ')
      vim.api.nvim_command('nnoremenu Gemini.' .. menu .. ' :' .. command_name .. '<CR>')
    end
  end

  for _, item in pairs(config.get_config({ 'instruction', 'prompts' }) or {}) do
    register_menu(item)
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
    register_keymap(mode, config.get_config({ 'instruction', 'menu_key' }) or '<Leader><Leader><Leader>g')
  end
end

return M
