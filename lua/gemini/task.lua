local config = require('gemini.config')
local api = require('gemini.api')
local util = require('gemini.util')

local M = {}

local context = {
  bufnr = nil,
  model_response = nil,
  tmpfile = nil,
}

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

local function diff_with_current_file(bufnr, new_content)
  local tmpfile = vim.fn.tempname()

  -- Write to the temp file
  local f = io.open(tmpfile, "w")
  if f then
    f:write(new_content)
    f:close()
  end

  vim.api.nvim_set_current_buf(bufnr)

  vim.cmd("vsplit " .. vim.fn.fnameescape(tmpfile))
  vim.cmd("wincmd l")
  vim.cmd("diffthis")
  vim.cmd("wincmd h")
  vim.cmd("diffthis")
  return tmpfile
end

M.run_task = function(ctx)
  local bufnr = vim.api.nvim_get_current_buf()
  local user_prompt = ctx.args
  local prompt = get_prompt_text(bufnr, user_prompt)

  local system_text = nil
  local get_system_text = config.get_config({ 'task', 'get_system_text' })
  if get_system_text then
    system_text = get_system_text()
  end

  print('-- running Gemini Task...')
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
          model_response = vim.fn.join(model_response, '\n')
          if #model_response then
            context.bufnr = bufnr
            context.model_response = model_response
            context.tmpfile = diff_with_current_file(bufnr, model_response)
          end
        end)
      end
    end
  end)
end

local function close_split_by_filename(tmpfile)
  -- Get the buffer number for the temp file
  local bufnr = vim.fn.bufnr(tmpfile)
  if bufnr == -1 then
    print("No buffer found for file: " .. tmpfile)
    return
  end

  -- Find the window displaying this buffer
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      vim.api.nvim_win_close(win, true)  -- force close the window
      vim.api.nvim_buf_delete(bufnr, { force = true, unload = true })
      return
    end
  end
  print("No window found showing the buffer for file: " .. tmpfile)
end

M.apply_patch = function()
  if context.bufnr and context.model_response then
    print('-- apply changes from Gemini')
    local lines = vim.split(context.model_response, '\n')
    vim.api.nvim_buf_set_lines(context.bufnr, 0, -1, false, lines)

    if context.tmpfile then
      close_split_by_filename(context.tmpfile)
    end

    context.bufnr = nil
    context.model_response = nil
    context.tmpfile = nil
  end
end

return M
