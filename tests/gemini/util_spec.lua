local util = require('gemini.util')

describe('util', function()
  describe('table_get', function()
    it('should get nested values', function()
      local t = { a = { b = { c = 1 } } }
      assert.are.equal(1, util.table_get(t, { 'a', 'b', 'c' }))
    end)

    it('should return nil for missing keys', function()
      local t = { a = { b = {} } }
      assert.is_nil(util.table_get(t, { 'a', 'b', 'c' }))
    end)

    it('should return nil for non-table keys', function()
      local t = { a = 1 }
      assert.is_nil(util.table_get(t, { 'a', 'b' }))
    end)

    it('should handle single key as string', function()
      local t = { a = 1 }
      assert.are.equal(1, util.table_get(t, 'a'))
    end)
  end)

  describe('is_blacklisted', function()
    it('should return true if filetype is in blacklist', function()
      local blacklist = { 'help', 'netrw' }
      assert.is_true(util.is_blacklisted(blacklist, 'help'))
    end)

    it('should return true if filetype matches pattern in blacklist', function()
      local blacklist = { 'git' }
      assert.is_true(util.is_blacklisted(blacklist, 'gitcommit'))
    end)

    it('should return false if filetype is not in blacklist', function()
      local blacklist = { 'help', 'netrw' }
      assert.is_false(util.is_blacklisted(blacklist, 'lua'))
    end)
  end)

  describe('strip_code', function()
    it('should extract multiple code blocks', function()
      local text = "Here is some code:\n```lua\nprint('hello')\n```\nAnd another one:\n```python\nprint('world')\n```"
      local expected = { "print('hello')", "print('world')" }
      local result = util.strip_code(text)
      assert.are.same(expected, result)
    end)

    it('should return the whole text if no code blocks found', function()
      local text = "Just some plain text."
      local expected = { "Just some plain text." }
      local result = util.strip_code(text)
      assert.are.same(expected, result)
    end)

    it('should handle nil input', function()
      local result = util.strip_code(nil)
      assert.are.same({}, result)
    end)
  end)
end)
