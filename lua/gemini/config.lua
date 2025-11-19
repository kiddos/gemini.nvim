local api = require('gemini.api')
local util = require('gemini.util')

local M = {}

local default_temperature = 0.06
local default_top_k = 64

local default_chat_config = {
  model = {
    model_id = api.MODELS.GEMINI_2_5_PRO,
    temperature = default_temperature,
    top_k = default_top_k,
  },
  window = {
    position = "new_tab",     -- left, right, new_tab, tab
    width = 80,               -- number of columns of the left/right window
  }
}

local default_instruction_config = {
  model = {
    model_id = api.MODELS.GEMINI_2_5_FLASH,
    temperature = default_temperature,
    top_k = default_top_k,
  },
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

local default_completion_config = {
  model = {
    model_id = api.MODELS.GEMINI_2_5_FLASH_LITE,
    temperature = default_temperature,
    top_k = default_top_k,
  },
  blacklist_filetypes = { 'help', 'qf', 'json', 'yaml', 'toml', 'xml', 'ini' },
  blacklist_filenames = { '.env' },
  completion_delay = 800,
  insert_result_key = '<S-Tab>',
  move_cursor_end = true,
  can_complete = function()
    return vim.fn.pumvisible() ~= 1
  end,
  get_system_text = function()
    return "You are an **Expert Code Completion Assistant**, a highly skilled, concise, and language-agnostic programmer.\n"
      .. "Your primary function is to generate code based on the user's current context (prefix, suffix, and surrounding files).\n"
      .. "The following special tokens are used to manage infilling:\n"
      .. "* **Prefix:** `<|fim_prefix|>` (Code before the cursor)\n"
      .. "* **Suffix:** `<|fim_suffix|>` (Code after the cursor)\n"
      .. "* **Infill Start:** `<|fim_middle|>` (Start generating the middle part)"
  end,
  get_prompt = function(bufnr, pos)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local row = pos[1]
    local col = pos[2]
    local prompt = '<|fim_prefix|>'
    for i, line in ipairs(lines) do
      if i == row then
        local prefix = line:sub(1, col)
        local suffix = line:sub(col + 1)
        prompt = prompt .. prefix .. ' <|fim_suffix|>\n' .. suffix .. '\n'
      else
        prompt = prompt .. line .. '\n'
      end
    end
    prompt = prompt .. '<|fim_middle|>'
    return prompt
  end
}

local default_task_config = {
  model = {
    model_id = api.MODELS.GEMINI_2_5_FLASH,
    temperature = default_temperature,
    top_k = default_top_k,
  },
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
    chat = vim.tbl_deep_extend('force', {}, default_chat_config, opts.chat_config or {}),
    completion = vim.tbl_deep_extend('force', {}, default_completion_config, opts.completion or {}),
    instruction = vim.tbl_deep_extend('force', {}, default_instruction_config, opts.instruction or {}),
    task = vim.tbl_deep_extend('force', {}, default_task_config, opts.task or {})
  }
end

M.get_config = function(keys)
  return util.table_get(M.config, keys)
end

M.get_gemini_generation_config = function(space)
  return {
    temperature = M.get_config({ space, 'model', 'temperature' }) or default_temperature,
    topK = M.get_config({ space, 'model', 'top_k' }) or default_top_k,
    response_mime_type = 'text/plain',
  }
end

return M
