local hints = require('gemini.hints')
local config = require('gemini.config')

describe('hints', function()
  before_each(function()
    config.set_config({
      hints = {
        enabled = true
      }
    })
  end)

  it('should setup user command when enabled', function()
    local user_commands = {}
    local orig_create = vim.api.nvim_create_user_command
    vim.api.nvim_create_user_command = function(name, command, opts)
      user_commands[name] = { command = command, opts = opts }
    end

    hints.setup()

    vim.api.nvim_create_user_command = orig_create
    assert.is_not_nil(user_commands['GeminiFunctionHint'])
  end)

  it('should not setup user command when disabled', function()
    config.set_config({
      hints = {
        enabled = false
      }
    })

    local user_commands = {}
    local orig_create = vim.api.nvim_create_user_command
    vim.api.nvim_create_user_command = function(name, command, opts)
      user_commands[name] = { command = command, opts = opts }
    end

    hints.setup()

    vim.api.nvim_create_user_command = orig_create
    assert.is_nil(user_commands['GeminiFunctionHint'])
  end)
end)
