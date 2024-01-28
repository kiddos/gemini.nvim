# gemini.nvim

This plugin try to interface Google's Gemini API into neovim.


## Installation

```shell
export GEMINI_API_KEY="<your API key here>"
```

if working with code with proprietary license, might want to turn function hints off

```shell
export DISABLE_GEMINI_INLINE=1
```

* [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'kiddos/gemini.nvim',
  build = { 'pip install -r requirements.txt', ':UpdateRemotePlugins' },
  config = function()
    require('gemini').setup()
  end
}
```


* [packer.nvim](https://github.com/wbthomason/packer.nvim)


```lua
use {
  'kiddos/gemini.nvim',
  run = { 'pip install -r requirements.txt', ':UpdateRemotePlugins' },
  config = function()
    require('gemini').setup()
  end,
}
```

## Settings

- default setting

```lua
require('gemini').setup({
  menu_key = '<C-o>',
  hints_delay = 3000,
  instruction_delay = 2000,
  menu_prompts = {
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
  },
  hints_prompt = [[
Instruction: Use 1 or 2 sentences to describe what the following {filetype} function does:

\`\`\`{filetype}
{code_block}
\`\`\`
  ]],
  instruction_prompt = [[
Context: filename: \`{filename}\`

Instruction: ***{instruction}***

  ]],
})
```
