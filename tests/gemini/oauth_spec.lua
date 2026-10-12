local oauth = require('gemini.oauth')
local config = require('gemini.config')

describe('oauth', function()
  local original_system = vim.system
  local original_schedule = vim.schedule
  local original_notify = vim.notify
  local original_load_tokens = oauth.load_tokens
  local original_save_tokens = oauth.save_tokens

  local notified_messages = {}

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

    notified_messages = {}
    vim.notify = function(msg, level)
      table.insert(notified_messages, { msg = msg, level = level })
    end

    oauth.save_tokens = function(tokens) end
  end)

  after_each(function()
    vim.system = original_system
    vim.schedule = original_schedule
    vim.notify = original_notify
    oauth.load_tokens = original_load_tokens
    oauth.save_tokens = original_save_tokens
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

  it('should handle refresh token error and notify user', function()
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
    assert.are.equal(1, #notified_messages)
    assert.is_not_nil(string.match(notified_messages[1].msg, "OAuth Refresh Curl Error"))
  end)

  it('should handle API error in refresh token response and notify user', function()
    local tokens = {
      refresh_token = "old_refresh_token",
      access_token = "old_access_token",
      expires_at = os.time() - 100
    }

    vim.system = function(cmd, opts, callback)
      callback({
        code = 0,
        stdout = vim.json.encode({
          error = "invalid_grant",
          error_description = "Token has been revoked."
        })
      })
      return {}
    end

    local called = false
    oauth.refresh_token(tokens, function(new_access_token)
      assert.is_nil(new_access_token)
      called = true
    end)

    assert.is_true(called)
    assert.are.equal(1, #notified_messages)
    assert.is_not_nil(string.match(notified_messages[1].msg, "Token has been revoked"))
  end)

  it('should notify user when refresh token is missing in refresh_token call', function()
    local tokens = {
      access_token = "old_access_token",
      expires_at = os.time() - 100
    }

    local called = false
    oauth.refresh_token(tokens, function(new_access_token)
      assert.is_nil(new_access_token)
      called = true
    end)

    assert.is_true(called)
    assert.are.equal(1, #notified_messages)
    assert.is_not_nil(string.match(notified_messages[1].msg, "No refresh token available"))
  end)

  it('get_token should return valid token without refreshing', function()
    local tokens = {
      access_token = "valid_access_token",
      refresh_token = "refresh_token",
      expires_at = os.time() + 3600
    }

    oauth.load_tokens = function() return tokens end

    local called = false
    oauth.get_token(function(token)
      assert.are.equal("valid_access_token", token)
      called = true
    end)

    assert.is_true(called)
    assert.are.equal(0, #notified_messages)
  end)

  it('get_token should automatically refresh token when expired', function()
    local tokens = {
      access_token = "expired_access_token",
      refresh_token = "refresh_token",
      expires_at = os.time() - 10
    }

    oauth.load_tokens = function() return tokens end

    vim.system = function(cmd, opts, callback)
      callback({
        code = 0,
        stdout = vim.json.encode({
          access_token = "refreshed_access_token",
          expires_in = 3600
        })
      })
      return {}
    end

    local called = false
    oauth.get_token(function(token)
      assert.are.equal("refreshed_access_token", token)
      called = true
    end)

    assert.is_true(called)
  end)

  it('get_token should automatically refresh token when close to expiry', function()
    local tokens = {
      access_token = "about_to_expire_access_token",
      refresh_token = "refresh_token",
      expires_at = os.time() + 30
    }

    oauth.load_tokens = function() return tokens end

    vim.system = function(cmd, opts, callback)
      callback({
        code = 0,
        stdout = vim.json.encode({
          access_token = "refreshed_access_token_near_expiry",
          expires_in = 3600
        })
      })
      return {}
    end

    local called = false
    oauth.get_token(function(token)
      assert.are.equal("refreshed_access_token_near_expiry", token)
      called = true
    end)

    assert.is_true(called)
  end)

  it('get_token should notify user when no tokens exist', function()
    oauth.load_tokens = function() return nil end

    local called = false
    oauth.get_token(function(token)
      assert.is_nil(token)
      called = true
    end)

    assert.is_true(called)
    assert.are.equal(1, #notified_messages)
    assert.is_not_nil(string.match(notified_messages[1].msg, "No OAuth tokens found"))
  end)
end)
