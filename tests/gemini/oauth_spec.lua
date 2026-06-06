local oauth = require('gemini.oauth')
local config = require('gemini.config')

describe('oauth', function()
  local original_system = vim.system
  local original_schedule = vim.schedule

  before_each(function()
    config.set_config({
      oauth = {
        enabled = true,
        client_id = "test_client_id",
        client_secret = "test_client_secret"
      }
    })
    -- Mock vim.schedule to run immediately
    vim.schedule = function(f) f() end
  end)

  after_each(function()
    vim.system = original_system
    vim.schedule = original_schedule
  end)

  it('should refresh token', function()
    local tokens = {
      refresh_token = "old_refresh_token",
      access_token = "old_access_token",
      expires_at = os.time() - 100
    }

    vim.system = function(cmd, opts, callback)
      -- Verify curl command
      assert.are.equal('curl', cmd[1])
      assert.are.equal('https://oauth2.googleapis.com/token', cmd[5])
      
      -- Simulate successful response
      callback({
        code = 0,
        stdout = vim.json.encode({
          access_token = "new_access_token",
          expires_in = 3600
        })
      })
      return {}
    end

    local called = false
    oauth.refresh_token(tokens, function(new_access_token)
      assert.are.equal("new_access_token", new_access_token)
      assert.are.equal("new_access_token", tokens.access_token)
      called = true
    end)

    assert.is_true(called)
  end)

  it('should handle refresh token error', function()
    local tokens = {
      refresh_token = "old_refresh_token",
      access_token = "old_access_token",
      expires_at = os.time() - 100
    }

    vim.system = function(cmd, opts, callback)
      callback({
        code = 1,
        stderr = "curl error"
      })
      return {}
    end

    local called = false
    oauth.refresh_token(tokens, function(new_access_token)
      assert.is_nil(new_access_token)
      called = true
    end)

    assert.is_true(called)
  end)
end)
