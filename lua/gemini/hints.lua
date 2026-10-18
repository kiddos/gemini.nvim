local config = require('gemini.config')
local util = require('gemini.util')
local api = require('gemini.api')

local M = {}

M.setup = function()
  local hints_cfg = config.get_config('hints')
  if not hints_cfg or not hints_cfg.enabled then
    return
  end

  vim.api.nvim_create_user_command('GeminiFunctionHint', function()
    M.get_function_hint()
  end, {
    force = true,
    desc = 'Get Gemini function hint',
  })
end

M.get_function_hint = function()
  local bufnr = vim.api.nvim_get_current_buf()
  if not util.treesitter_has_lang(bufnr) then
    vim.notify('Treesitter language parser not available for this buffer', vim.log.levels.WARN)
    return
  end

  local node = util.find_node_by_type('function')
  if not node then
    vim.notify('No function node found at cursor position', vim.log.levels.WARN)
    return
  end

  local get_prompt = config.get_config({ 'hints', 'get_prompt' })
  if not get_prompt then
    vim.notify('Prompt function for hints is not configured', vim.log.levels.WARN)
    return
  end

  local prompt = get_prompt(node, bufnr)
  if not prompt then
    return
  end

  local generation_config = config.get_gemini_generation_config('hints')
  local model_id = config.get_config({ 'hints', 'model', 'model_id' }) or config.get_config({ 'completion', 'model', 'model_id' })

  api.gemini_generate_content(prompt, nil, model_id, generation_config, function(result)
    if not result or not result.stdout then
      return
    end

    local ok, model_response = pcall(vim.json.decode, result.stdout)
    if not ok or not model_response then
      return
    end

    local text = util.table_get(model_response, { 'candidates', 1, 'content', 'parts', 1, 'text' })
    if text and #text > 0 then
      vim.schedule(function()
        util.open_window(vim.split(text, '\n'), {
          line = 1,
          col = 1,
          minwidth = 60,
          minheight = 5,
        })
      end)
    end
  end)
end

return M
