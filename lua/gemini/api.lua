local M = {}

local API = "https://generativelanguage.googleapis.com/v1beta/models/";

M.MODELS = {
  GEMINI_1_0_PRO = 'gemini-1.0-pro',
  GEMINI_1_5_PRO = 'gemini-1.5-pro',
  GEMINI_1_5_FLASH = 'gemini-1.5-flash',
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
  local cmd = {'curl', api, '-X', 'POST', '-s', '-H', 'Content-Type: application/json', '-d', json_text}
  local opts = { text = true }
  if callback then
    return vim.system(cmd, opts, callback)
  else
    return vim.system(cmd, opts)
  end
end

return M
