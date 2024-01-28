local M = {}

local default_config = {
  menu_key = '<C-o>',
  hints_delay = 3000,
  instruction_delay = 2000,
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

local default_completion_prompt = [[
Context:

There is a file name `{filename}` with the following content'

]]

M.set_config = function(opts)
  opts = opts or {}

  M.config = vim.tbl_extend('keep', default_config, opts)
  M.menu_prompts = vim.tbl_extend('keep', default_menu_prompts, opts.prompts or {})
  M.hints_prompt = opts.hints_prompt or default_hints_prompt
  M.instruction_prompt = opts.instruction_prompt or default_instruction_prompt
  M.completion_prompt = opts.completion_prompt or default_completion_prompt
end

M.get_config = function()
  return M.config or {}
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
