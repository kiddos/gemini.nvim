local config = require('gemini.config')
local api = require('gemini.api')
local util = require('gemini.util')

local M = {}

M.setup = function()
  if not config.get_config({ 'task', 'enabled' }) then
    return
  end

  vim.api.nvim_create_user_command('GeminiTask', M.run_task, {
    force = true,
    desc = 'Google Gemini',
    nargs = 1,
  })

  vim.api.nvim_create_user_command('GeminiApply', M.apply_patch, {
    force = true,
    desc = 'Apply patch',
  })
end

local get_prompt_text = function(bufnr, user_prompt)
  local get_prompt = config.get_config({ 'task', 'get_prompt' })
  if not get_prompt then
    vim.notify('prompt function is not found', vim.log.levels.WARN)
    return nil
  end
  return get_prompt(bufnr, user_prompt)
end

M.run_task = function(context)
  local bufnr = vim.api.nvim_get_current_buf()
  local user_prompt = context.args
  local prompt = get_prompt_text(bufnr, user_prompt)

  local system_text = nil
  local get_system_text = config.get_config({ 'task', 'get_system_text' })
  if get_system_text then
    system_text = get_system_text()
  end

  local generation_config = config.get_gemini_generation_config()
  local model_id = config.get_config({ 'model', 'model_id' })
  api.gemini_generate_content(prompt, system_text, model_id, generation_config, function(result)
    local json_text = result.stdout
    if json_text and #json_text > 0 then
      local model_response = vim.json.decode(json_text)
      model_response = util.table_get(model_response, { 'candidates', 1, 'content', 'parts', 1, 'text' })
      if model_response ~= nil and #model_response > 0 then
        model_response = util.strip_code(model_response)
        vim.schedule(function()
          local diff = vim.fn.join(model_response, '\n')
          local lines = vim.split(diff, '\n')
          vim.cmd("topleft new")
          local split_bufnr = vim.api.nvim_get_current_buf()
          vim.api.nvim_set_option_value('filetype', 'diff', { buf = split_bufnr })
          vim.api.nvim_buf_set_lines(split_bufnr, 0, -1, false, lines)
        end)
      end
    end
  end)
end

M.apply_patch = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
  if filetype ~= 'diff' then
    return
  end

  vim.cmd('silent w /tmp/gemini.patch')
  vim.cmd('silent !git apply /tmp/gemini.patch')
  vim.cmd('silent !rm /tmp/gemini.patch')
  vim.cmd('silent bd')
end

return M
