local api = require('gemini.api')
local util = require('gemini.util')

local M = {}

local default_config = {
  menu_key = '<C-o>',
  insert_result_key = '<S-Tab>',
  instruction_delay = 1000,
}

local default_model_config = {
  completion_delay = 500,
  model_id = api.MODELS.GEMINI_1_0_PRO,
  temperature = 0.9,
  top_k = 1.0,
  max_output_tokens = 2048,
  response_mime_type = 'text/plain',
}

local default_chat_config = {
  enabled = true,
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
  insert_result_key = '<S-Tab>',
  get_prompt = function(bufnr, pos)
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


local default_instruction_prompt = [[
Context: filename: `{filename}`

Instruction: ***{instruction}***

]]


M.set_config = function(opts)
  opts = opts or {}

  M.config = {
    model = vim.tbl_extend('force', default_model_config, opts.model_config or {}),
    chat = vim.tbl_extend('force', default_chat_config, opts.chat_config or {}),
    hints = vim.tbl_extend('force', default_hints_config, opts.hints or {}),
    completion = vim.tbl_extend('force', default_completion_config, opts.completion or {}),
  }
  -- M.config = vim.tbl_extend('force', default_config, opts)
  -- M.menu_prompts = vim.tbl_extend('force', default_menu_prompts, opts.prompts or {})
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
