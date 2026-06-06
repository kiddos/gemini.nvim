local config = require('gemini.config')
local constants = require('gemini.constants')

describe('config', function()
  before_each(function()
    config.set_config({})
  end)

  it('should have default values', function()
    local chat_config = config.get_config('chat')
    assert.are.equal(constants.MODELS.GEMINI_2_5_FLASH, chat_config.model.model_id)
    assert.are.equal(0.06, chat_config.model.temperature)
  end)

  it('should override values with set_config', function()
    config.set_config({
      chat_config = {
        model = {
          temperature = 0.5
        }
      }
    })
    assert.are.equal(0.5, config.get_config({ 'chat', 'model', 'temperature' }))
    -- Ensure other defaults are preserved
    assert.are.equal(constants.MODELS.GEMINI_2_5_FLASH, config.get_config({ 'chat', 'model', 'model_id' }))
  end)

  it('should get generation config', function()
    local gen_cfg = config.get_gemini_generation_config('chat')
    assert.are.equal(0.06, gen_cfg.temperature)
    assert.are.equal(64, gen_cfg.topK)
    assert.are.equal('text/plain', gen_cfg.response_mime_type)
  end)

  it('should handle oauth config', function()
    config.set_config({
      oauth = {
        enabled = true,
        client_id = "test_id"
      }
    })
    local oauth_cfg = config.get_config('oauth')
    assert.is_true(oauth_cfg.enabled)
    assert.are.equal("test_id", oauth_cfg.client_id)
    assert.are.equal("", oauth_cfg.client_secret)
  end)
end)
