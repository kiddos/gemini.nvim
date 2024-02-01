# gemini.nvim

This plugin try to interface Google's Gemini API into neovim.


It does take some practice to prompt this thing, default press `<S-Tab>` to select the result

https://github.com/kiddos/gemini.nvim/assets/9444583/14c09cc3-81b5-480a-9121-51a35fd0e492


popup menu

https://github.com/kiddos/gemini.nvim/assets/9444583/8fd25a4d-03c9-45aa-9c0f-5db7b65cf810


https://github.com/kiddos/gemini.nvim/assets/9444583/0b05f86e-feca-49d0-937c-59f6992d87f4


function hints

https://github.com/kiddos/gemini.nvim/assets/9444583/d6d0e384-4926-4ffd-856d-a1cb15323449

It sort of works for flutter widget too?

https://github.com/kiddos/gemini.nvim/assets/9444583/303fddce-dd5c-418d-a7d9-e2a099c5a066


and rust?

https://github.com/kiddos/gemini.nvim/assets/9444583/e4f5ad4c-cc40-4890-8151-696f1e0b0e77


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

To install manually

```shell
pip install pynvim google-generativeai
```

and run `:UpdateRemotePlugins`

## Settings

- default setting

```lua
require('gemini').setup({
  menu_key = '<C-o>',
  insert_result_key = '<S-Tab>',
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

## TODO

- [ ] 
