local api = require('gemini.api')
local util = require('gemini.util')

describe('api', function()
  it('should send message', function()
    local completed = false
    local result_table

    local generation_config = {
      temperature = 0.9,
      top_k = 1.0,
      max_output_tokens = 2048,
      response_mime_type = 'text/plain',
    }

    api.gemini_generate_content('hello there', nil, api.MODELS.GEMINI_2_0_FLASH, generation_config, function(result)
      result_table = result
      completed = true
    end)

    vim.wait(5000, function() return completed end)

    assert.is_not_nil(result_table)
    assert.is_equal(result_table.code, 0)
    assert.is_not_nil(result_table.stdout)
    assert(#result_table.stdout > 0)

    local result = vim.json.decode(result_table.stdout)
    local model_response = util.table_get(result, { 'candidates', 1, 'content',
      'parts', 1, 'text' })
    assert(#model_response > 0)
  end)

  it('should send long message', function()
    local completed = false
    local result_table

    local generation_config = {
      temperature = 0.9,
      top_k = 1.0,
      max_output_tokens = 2048,
      response_mime_type = 'text/plain',
    }
    local long_message = string.rep('this is a very very long message ', 3000)

    api.gemini_generate_content(long_message, nil, api.MODELS.GEMINI_2_0_FLASH, generation_config, function(result)
      result_table = result
      completed = true
    end)

    vim.wait(20000, function() return completed end)

    assert.is_not_nil(result_table)
    assert.is_equal(result_table.code, 0)
    assert.is_not_nil(result_table.stdout)
    assert(#result_table.stdout > 0)

    local result = vim.json.decode(result_table.stdout)
    local model_response = util.table_get(result, { 'candidates', 1, 'content',
      'parts', 1, 'text' })
    assert(#model_response > 0)
  end)
end)
