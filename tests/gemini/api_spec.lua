local api = require('gemini.api')
local util = require('gemini.util')

describe('api', function()
  it('should send message', function()
    local generation_config = {
      temperature = 0.9,
      top_k = 1.0,
      max_output_tokens = 2048,
      response_mime_type = 'text/plain',
    }
    local future = api.gemini_generate_content('hello there', api.MODELS.GEMINI_1_0_PRO, generation_config, nil)
    local result = future:wait()
    local stdout = result.stdout
    assert(#stdout > 0)

    local result = vim.json.decode(stdout)
    local model_response = util.table_get(result, { 'candidates', 1, 'content',
      'parts', 1, 'text' })
    assert(#model_response > 0)
  end)
end)
