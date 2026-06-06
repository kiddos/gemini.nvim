local uv = vim.loop or vim.uv
local config = require('gemini.config')

local M = {}

local API = "https://generativelanguage.googleapis.com/v1beta/models/";

local function get_api_info(callback)
  local oauth_cfg = config.get_config('oauth')
  if oauth_cfg and oauth_cfg.enabled then
    local oauth = require('gemini.oauth')
    oauth.get_token(function(token)
      if token then
        callback({
          url_params = "",
          headers = { "Authorization: Bearer " .. token }
        })
      else
        callback(nil)
      end
    end)
  else
    local api_key = os.getenv("GEMINI_API_KEY")
    if api_key then
      callback({
        url_params = "?key=" .. api_key,
        headers = {}
      })
    else
      callback(nil)
    end
  end
end

local function new_future()
  local f = {
    done = false,
    result = nil,
  }
  function f:wait(timeout)
    vim.wait(timeout or 30000, function() return f.done end)
    return f.result
  end

  return f
end

M.gemini_generate_content = function(user_text, system_text, model_name, generation_config, callback)
  local future = new_future()
  get_api_info(function(info)
    if not info then
      print("No API key or OAuth token found.")
      future.done = true
      return
    end

    local api = API .. model_name .. ':generateContent' .. info.url_params
    local contents = {
      {
        parts = {
          {
            text = user_text
          }
        }
      }
    }
    local data = {
      contents = contents,
      generationConfig = generation_config,
    }
    if system_text then
      data.systemInstruction = {
        parts = {
          {
            text = system_text,
          }
        }
      }
    end

    local json_text = vim.json.encode(data)
    local cmd = { 'curl', '--no-progress-meter', '-X', 'POST', api, '-H', 'Content-Type: application/json' }
    for _, h in ipairs(info.headers) do
      table.insert(cmd, '-H')
      table.insert(cmd, h)
    end
    table.insert(cmd, '--data-binary')
    table.insert(cmd, '@-')

    local opts = { stdin = json_text }
    local internal_callback = function(obj)
      future.result = obj
      future.done = true
      if callback then
        callback(obj)
      end
    end

    vim.system(cmd, opts, internal_callback)
  end)
  return future
end

M.gemini_generate_content_stream = function(user_text, model_name, generation_config, callback)
  if not callback then
    return
  end

  get_api_info(function(info)
    if not info then
      print("No API key or OAuth token found.")
      return
    end

    local api = API .. model_name .. ':streamGenerateContent?alt=sse' .. info.url_params:gsub("^%?", "&")
    local data = {
      contents = {
        {
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

    local args = { api, '-X', 'POST', '-s', '-H', 'Content-Type: application/json' }
    for _, h in ipairs(info.headers) do
      table.insert(args, '-H')
      table.insert(args, h)
    end
    table.insert(args, '-d')
    table.insert(args, json_text)

    local options = {
      stdio = { stdin, stdout, stderr },
      args = args
    }

    uv.spawn('curl', options, function(code, _)
      if code ~= 0 then
        print("gemini chat finished exit code", code)
      end
    end)

    local streamed_data = ''
    uv.read_start(stdout, function(err, data)
      if not err and data then
        streamed_data = streamed_data .. data

        local start_index = string.find(streamed_data, 'data:')
        local end_index = string.find(streamed_data, '\r')
        local json_text_chunk = ''
        while start_index and end_index do
          if end_index >= start_index then
            json_text_chunk = string.sub(streamed_data, start_index + 5, end_index - 1)
            callback(json_text_chunk)
          end
          streamed_data = string.sub(streamed_data, end_index + 1)
          start_index = string.find(streamed_data, 'data:')
          end_index = string.find(streamed_data, '\r')
        end
      end
    end)
  end)
end

return M
