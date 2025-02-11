# gemini.nvim

This plugin try to interface Google's Gemini API into neovim.


## Features

- Code Complete
- Code Explain
- Unit Test Generation
- Code Review
- Hints
- Chat

### Code Complete
https://github.com/user-attachments/assets/11ae6719-4f3f-41db-8ded-56db20e6e9f4

https://github.com/user-attachments/assets/34c38078-a028-47d2-acb1-49e03d0b4330


### Code Explain
https://github.com/user-attachments/assets/6b2492ee-7c70-4bbc-937b-27bfa50f8944

### Unit Test generation
https://github.com/user-attachments/assets/0620a8a4-5ea6-431d-ba17-41c7d553f742

### Code Review
https://github.com/user-attachments/assets/9100ab70-f107-40de-96e2-fb4ea749c014

### Hints
https://github.com/user-attachments/assets/a36804e9-073f-4e3e-9178-56b139fd0c62

### Chat
https://github.com/user-attachments/assets/d3918d2a-4cf7-4639-bc21-689d4225ba6d


## Installation

- install `curl`

```
sudo apt install curl
```





```shell
export GEMINI_API_KEY="<your API key here>"
```

* [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'kiddos/gemini.nvim',
  config = function()
    require('gemini').setup()
  end
}
```


* [packer.nvim](https://github.com/wbthomason/packer.nvim)


```lua
use {
  'kiddos/gemini.nvim',
  config = function()
    require('gemini').setup()
  end,
}
```

## Settings

default setting

```lua
{
  model_config = {
    completion_delay = 1000,
    model_id = api.MODELS.GEMINI_1_5_FLASH,
    temperature = 0.01,
    top_k = 1.0,
    max_output_tokens = 8196,
    response_mime_type = 'text/plain',
  },
  chat_config = {
    enabled = true,
  },
  hints = {
    enabled = true,
    hints_delay = 2000,
    insert_result_key = '<S-Tab>',
    get_prompt = function(node, bufnr)
      local code_block = vim.treesitter.get_node_text(node, bufnr)
      local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
      local prompt = "
  Instruction: Use 1 or 2 sentences to describe what the following {filetype} function does:
  
  ```{filetype}
  {code_block}
  ```",
      prompt = prompt:gsub('{filetype}', filetype)
      prompt = prompt:gsub('{code_block}', code_block)
      return prompt
    end
  }
  completion = {
    enabled = true,
    insert_result_key = '<S-Tab>',
    get_prompt = function(bufnr, pos)
      local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
      local prompt = 'Below is a %s file:\n'
          .. '```%s\n%s\n```\n\n'
          .. 'Instruction:\nWhat code should be place at <insert_here></insert_here>?\n'
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local line = pos[1]
      local col = pos[2]
      local target_line = lines[line]
      if target_line then
        lines[line] = target_line:sub(1, col) .. '<insert_here></insert_here>' .. target_line:sub(col + 1)
      else
        return nil
      end
      local code = vim.fn.join(lines, '\n')
      prompt = string.format(prompt, filetype, filetype, code)
      return prompt
    end
  },
  instruction = {
    enabled = true,
    menu_key = '<C-o>',
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
    },
  },
}
```

