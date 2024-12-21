local uv = vim.loop or vim.uv

local M = {}

local API = "https://generativelanguage.googleapis.com/v1beta/models/";

M.MODELS = {
  GEMINI_1_5_FLASH = 'gemini-1.5-flash',
  GEMINI_1_5_FLASH_8B = 'gemini-1.5-flash-8b',
  GEMINI_2_0_FLASH_EXP = 'gemini-2.0-flash-exp',
  GEMINI_2_0_FLASH_THINKING_EXP = 'gemini-2.0-flash-thinking-exp-1219',
  GEMINI_1_0_PRO = 'gemini-1.0-pro',
  GEMINI_1_5_PRO = 'gemini-1.5-pro',
}

M.gemini_generate_content = function(user_text, model_name, generation_config, callback)
  local api_key = os.getenv("GEMINI_API_KEY")
  if not api_key then
    return ''
  end

  local api = API .. model_name .. ':generateContent?key=' .. api_key
  local data = {
    contents = {
      {
        role = 'user',
        parts = {
          {
            text = user_text
          }
        }
      }
    },
    generationConfig = generation_config,
  }
  local json_text = vim.json.encode(data)
  local cmd = { 'curl', api, '-X', 'POST', '-s', '-H', 'Content-Type: application/json', '-d', json_text }
  local opts = { text = true }
  if callback then
    return vim.system(cmd, opts, callback)
  else
    return vim.system(cmd, opts)
  end
end

M.gemini_generate_content_stream = function(user_text, model_name, generation_config, callback)
  local api_key = os.getenv("GEMINI_API_KEY")
  if not api_key then
    return
  end

  if not callback then
    return
  end

  local api = API .. model_name .. ':streamGenerateContent?alt=sse&key=' .. api_key
  local data = {
    contents = {
      {
        role = 'user',
        parts = {
          {
            text = user_text
          }
        }
      }
    },
    generationConfig = generation_config,
  }
  local json_text = vim.json.encode(data)

  local stdin = uv.new_pipe()
  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()
  local options = {
    stdio = { stdin, stdout, stderr },
    args = { api, '-X', 'POST', '-s', '-H', 'Content-Type: application/json', '-d', json_text }
  }

  uv.spawn('curl', options, function(code, _)
    print("gemini chat finished exit code", code)
  end)

  local streamed_data = ''
  uv.read_start(stdout, function(err, data)
    if not err and data then
      streamed_data = streamed_data .. data

      local start_index = string.find(streamed_data, 'data:')
      local end_index = string.find(streamed_data, '\r')
      local json_text = ''
      while start_index and end_index do
        if end_index >= start_index then
          json_text = string.sub(streamed_data, start_index + 5, end_index - 1)
          callback(json_text)
        end
        streamed_data = string.sub(streamed_data, end_index + 1)
        start_index = string.find(streamed_data, 'data:')
        end_index = string.find(streamed_data, '\r')
      end
    end
  end)
end

return M
