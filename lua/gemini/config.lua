local api = require('gemini.api')
local util = require('gemini.util')

local M = {}

local default_config = {
  menu_key = '<C-o>',
  insert_result_key = '<S-Tab>',
  hints_delay = 3000,
  instruction_delay = 1000,
}

local default_completion_config = {
  completion_delay = 500,
  model_id = api.MODELS.GEMINI_1_0_PRO,
  temperature = 0.9,
  top_k = 1.0,
  max_output_tokens = 2048,
  response_mime_type = 'text/plain',
  insert_result_key = '<S-Tab>',
  get_prompt = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()
    local pos = vim.api.nvim_win_get_cursor(win)

    local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    local prompt = 'Objective: Complete Code at line %d, column %d\n'
        .. 'Context:\n\n```%s\n%s\n```\n\n'
        .. 'Question:\n\nWhat code should be place at line %d, column %d?\n\nAnswer:\n\n'
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local code = vim.fn.join(lines, '\n')
    prompt = string.format(prompt, pos[1], pos[2], filetype, code, pos[1], pos[2])
    return prompt
  end
}

local default_menu_prompts = {
  {
    name = 'Unit Test Generation',
    command_name = 'GeminiUnitTest',
    menu = 'Unit Test 🚀',
    prompt = 'Write unit tests for the following code\n',
  },
  {
    name = 'Code Review',
    command_name = 'GeminiCodeReview',
    menu = 'Code Review 📜',
    prompt = 'Do a thorough code review for the following code.\nProvide detail explaination and sincere comments.\n',
  },
  {
    name = 'Code Explain',
    command_name = 'GeminiCodeExplain',
    menu = 'Code Explain 👻',
    prompt = 'Explain the following code\nprovide the answer in Markdown\n',
  },
}

local default_hints_prompt = [[
Instruction: Use 1 or 2 sentences to describe what the following {filetype} function does:

```{filetype}
{code_block}
```

]]

local default_instruction_prompt = [[
Context: filename: `{filename}`

Instruction: ***{instruction}***

]]


M.set_config = function(opts)
  opts = opts or {}

  M.config = {
    completion = vim.tbl_extend('force', default_completion_config, opts.completion or {})
  }
  -- M.config = vim.tbl_extend('force', default_config, opts)
  -- M.menu_prompts = vim.tbl_extend('force', default_menu_prompts, opts.prompts or {})
  -- M.hints_prompt = opts.hints_prompt or default_hints_prompt
  -- M.instruction_prompt = opts.instruction_prompt or default_instruction_prompt
end

M.get_config = function(keys)
  return util.table_get(M.config, keys)
end

M.get_menu_prompts = function()
  return M.menu_prompts or {}
end

M.get_hints_prompt = function()
  return M.hints_prompt
end

M.get_instruction_prompt = function()
  return M.instruction_prompt
end

M.get_completion_prompt = function()
  return M.instruction_prompt
end

return M
