local api = require('gemini.api')
local util = require('gemini.util')
local constants = require('gemini.constants')
local config = require('gemini.config')
local oauth = require('gemini.oauth')

describe('api', function()
  local api_key = os.getenv("GEMINI_API_KEY")

  it('should send message', function()
    if not api_key then
      pending("GEMINI_API_KEY not set")
      return
    end
    local generation_config = {
      temperature = 0.9,
      top_k = 1.0,
      max_output_tokens = 2048,
      response_mime_type = 'text/plain',
    }
    local future = api.gemini_generate_content('hello there', nil, constants.MODELS.GEMINI_3_1_FLASH_LITE, generation_config, nil)
    local result = future:wait()
    local stdout = result.stdout
    assert(#stdout > 0)

    local res_tbl = vim.json.decode(stdout)
    local model_response = util.table_get(res_tbl, { 'candidates', 1, 'content',
      'parts', 1, 'text' })
    assert(#model_response > 0)
  end)

  it('should send long message', function()
    if not api_key then
      pending("GEMINI_API_KEY not set")
      return
    end
    local generation_config = {
      temperature = 0.9,
      top_k = 1.0,
      max_output_tokens = 2048,
      response_mime_type = 'text/plain',
    }
    local long_message = string.rep('this is a very very long message ', 3000)
    local future = api.gemini_generate_content(long_message, nil, constants.MODELS.GEMINI_3_1_FLASH_LITE, generation_config, nil)
    local result = future:wait()
    local stdout = result.stdout
    assert(#stdout > 0)

    local res_tbl = vim.json.decode(stdout)
    local model_response = util.table_get(res_tbl, { 'candidates', 1, 'content',
      'parts', 1, 'text' })
    assert(#model_response > 0)
  end)

  it('should use bearer token when OAuth is enabled', function()
    local orig_get_token = oauth.get_token
    local orig_system = vim.system

    config.set_config({
      oauth = {
        enabled = true,
        client_id = "test_id",
        client_secret = "test_secret"
      }
    })

    oauth.get_token = function(cb)
      cb("mock_bearer_token")
    end

    local captured_cmd = nil
    vim.system = function(cmd, opts, callback)
      captured_cmd = cmd
      callback({ code = 0, stdout = vim.json.encode({ candidates = {} }) })
      return {}
    end

    local future = api.gemini_generate_content('test prompt', nil, constants.MODELS.GEMINI_3_1_FLASH_LITE, {}, nil)
    future:wait()

    oauth.get_token = orig_get_token
    vim.system = orig_system

    assert.is_not_nil(captured_cmd)
    local has_header = false
    for i, arg in ipairs(captured_cmd) do
      if arg == "Authorization: Bearer mock_bearer_token" then
        has_header = true
      end
    end
    assert.is_true(has_header)
  end)
end)
