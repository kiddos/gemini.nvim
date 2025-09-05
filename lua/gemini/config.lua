local api = require('gemini.api')
local util = require('gemini.util')

local M = {}

local default_model_config = {
  model_id = api.MODELS.GEMINI_2_5_FLASH_LITE,
  temperature = 0.10,
  top_k = 128,
  response_mime_type = 'text/plain',
}

local default_chat_config = {
  enabled = true,
  window = {
    position = "new_tab",     -- left, right, new_tab, tab
    width = 80,               -- number of columns of the left/right window
  }
}

local default_instruction_config = {
  enabled = true,
  menu_key = '<Leader><Leader><Leader>g',
  prompts = {
    {
      name = 'Unit Test',
      command_name = 'GeminiUnitTest',
      menu = 'Unit Test 🚀',
      get_prompt = function(lines, bufnr)
        local code = vim.fn.join(lines, '\n')
        local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
        local prompt = 'Context:\n\n```%s\n%s\n```\n\n'
            .. 'Objective: Write unit test for the above snippet of code\n'
        return string.format(prompt, filetype, code)
      end,
    },
    {
      name = 'Code Review',
      command_name = 'GeminiCodeReview',
      menu = 'Code Review 📜',
      get_prompt = function(lines, bufnr)
        local code = vim.fn.join(lines, '\n')
        local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
        local prompt = 'Context:\n\n```%s\n%s\n```\n\n'
            .. 'Objective: Do a thorough code review for the following code.\n'
            .. 'Provide detail explaination and sincere comments.\n'
        return string.format(prompt, filetype, code)
      end,
    },
    {
      name = 'Code Explain',
      command_name = 'GeminiCodeExplain',
      menu = 'Code Explain',
      get_prompt = function(lines, bufnr)
        local code = vim.fn.join(lines, '\n')
        local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
        local prompt = 'Context:\n\n```%s\n%s\n```\n\n'
            .. 'Objective: Explain the following code.\n'
            .. 'Provide detail explaination and sincere comments.\n'
        return string.format(prompt, filetype, code)
      end,
    },
  }
}

local default_hints_config = {
  enabled = true,
  hints_delay = 2000,
  insert_result_key = '<S-Tab>',
  get_prompt = function(node, bufnr)
    local code_block = vim.treesitter.get_node_text(node, bufnr)
    local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    local prompt = [[
Instruction: Use 1 or 2 sentences to describe what the following {filetype} function does:

```{filetype}
{code_block}
```
]]
    prompt = prompt:gsub('{filetype}', filetype)
    prompt = prompt:gsub('{code_block}', code_block)
    return prompt
  end
}

local default_completion_config = {
  enabled = true,
  blacklist_filetypes = { 'help', 'qf', 'json', 'yaml', 'toml', 'xml' },
  blacklist_filenames = { '.env' },
  completion_delay = 800,
  insert_result_key = '<S-Tab>',
  move_cursor_end = true,
  can_complete = function()
    return vim.fn.pumvisible() ~= 1
  end,
  get_system_text = function()
    return "You are a coding AI assistant that autocomplete user's code."
      .. "\n* Your task is to provide code suggestion at the cursor location marked by <cursor></cursor>."
      .. '\n* Your response does not need to contain explaination.'
  end,
  get_prompt = function(bufnr, pos)
    local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    local prompt = 'Below is the content of a %s file `%s`:\n'
        .. '```%s\n%s\n```\n\n'
        .. 'Suggest the most likely code at <cursor></cursor>.\n'
        .. 'Wrap your response in ``` ```\n'
        .. 'eg.\n```\n```\n\n'
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local line = pos[1]
    local col = pos[2]
    local target_line = lines[line]
    if target_line then
      lines[line] = target_line:sub(1, col) .. '<cursor></cursor>' .. target_line:sub(col + 1)
    else
      return nil
    end
    local code = vim.fn.join(lines, '\n')
    local abs_path = vim.api.nvim_buf_get_name(bufnr)
    local filename = vim.fn.fnamemodify(abs_path, ':.')
    prompt = string.format(prompt, filetype, filename, filetype, code)
    return prompt
  end
}

local default_task_config = {
  enabled = true,
  get_system_text = function()
    return 'You are an AI assistant that helps user write code.'
      .. '\n* You should output the new content for the Current Opened File'
  end,
  get_prompt = function(bufnr, user_prompt)
    local buffers = vim.api.nvim_list_bufs()
    local file_contents = {}

    for _, b in ipairs(buffers) do
      if vim.api.nvim_buf_is_loaded(b) then -- Only get content from loaded buffers
        local lines = vim.api.nvim_buf_get_lines(b, 0, -1, false)
        local abs_path = vim.api.nvim_buf_get_name(b)
        local filename = vim.fn.fnamemodify(abs_path, ':.')
        local filetype = vim.api.nvim_get_option_value('filetype', { buf = b })
        local file_content = table.concat(lines, "\n")
        file_content = string.format("`%s`:\n\n```%s\n%s\n```\n\n", filename, filetype, file_content)
        table.insert(file_contents, file_content)
      end
    end

    local current_filepath = vim.api.nvim_buf_get_name(bufnr)
    current_filepath = vim.fn.fnamemodify(current_filepath, ":.")

    local context = table.concat(file_contents, "\n\n")
    return string.format('%s\n\nCurrent Opened File: %s\n\nTask: %s',
      context, current_filepath, user_prompt)
  end
}

M.set_config = function(opts)
  opts = opts or {}

  M.config = {
    model = vim.tbl_deep_extend('force', {}, default_model_config, opts.model_config or {}),
    chat = vim.tbl_deep_extend('force', {}, default_chat_config, opts.chat_config or {}),
    hints = vim.tbl_deep_extend('force', {}, default_hints_config, opts.hints or {}),
    completion = vim.tbl_deep_extend('force', {}, default_completion_config, opts.completion or {}),
    instruction = vim.tbl_deep_extend('force', {}, default_instruction_config, opts.instruction or {}),
    task = vim.tbl_deep_extend('force', {}, default_task_config, opts.task or {})
  }
end

M.get_config = function(keys)
  return util.table_get(M.config, keys)
end

M.get_gemini_generation_config = function()
  return {
    temperature = M.get_config({ 'model', 'temperature' }) or default_model_config.temperature,
    topK = M.get_config({ 'model', 'top_k' }) or default_model_config.top_k,
    response_mime_type = M.get_config({ 'model', 'response_mime_type' }) or 'text/plain',
  }
end

return M
