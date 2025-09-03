local assert = require("luassert")

local Register = require("occurrence.Register")

describe("Register", function()
  before_each(function()
    -- Clear all registers before each test
    vim.fn.setreg('"', "")
    vim.fn.setreg("a", "")
    vim.fn.setreg("b", "")
    vim.fn.setreg("1", "")
  end)

  after_each(function()
    -- Clean up registers after each test
    vim.fn.setreg('"', "")
    vim.fn.setreg("a", "")
    vim.fn.setreg("b", "")
    vim.fn.setreg("1", "")
  end)

  describe("new", function()
    it("creates a register with default values", function()
      local reg = Register.new()

      assert.is_table(reg)
      assert.equals(vim.v.register, reg.register)
      assert.equals("char", reg.type)
      assert.same({}, reg.text)
    end)

    it("creates a register with specified name", function()
      local reg = Register.new("a")

      assert.equals("a", reg.register)
      assert.equals("char", reg.type)
      assert.same({}, reg.text)
    end)

    it("creates a register with specified name and type", function()
      local reg = Register.new("b", "line")

      assert.equals("b", reg.register)
      assert.equals("line", reg.type)
      assert.same({}, reg.text)
    end)

    it("handles nil register name by using vim.v.register", function()
      -- vim.v.register is read-only, so we test with the current value
      local reg = Register.new(nil, "block")

      assert.equals(vim.v.register, reg.register)
      assert.equals("block", reg.type)
    end)
  end)

  describe("add", function()
    it("adds a string to the register", function()
      local reg = Register.new("a", "char")
      reg:add("hello")
      assert.same({ "hello" }, reg.text)
    end)

    it("adds multiple strings", function()
      local reg = Register.new("a", "char")
      reg:add("first")
      reg:add("second")
      assert.same({ "first", "second" }, reg.text)
    end)

    it("adds a table of strings", function()
      local reg = Register.new("a", "char")
      reg:add({ "line1", "line2", "line3" })
      assert.same({ "line1", "line2", "line3" }, reg.text)
    end)

    it("adds both strings and tables", function()
      local reg = Register.new("a", "char")
      reg:add("single")
      reg:add({ "multi1", "multi2" })
      reg:add("another")
      assert.same({ "single", "multi1", "multi2", "another" }, reg.text)
    end)

    it("handles empty strings", function()
      local reg = Register.new("a", "char")
      reg:add("")
      reg:add("content")
      assert.same({ "", "content" }, reg.text)
    end)

    it("handles empty tables", function()
      local reg = Register.new("a", "char")
      reg:add({})
      reg:add("content")
      assert.same({ "content" }, reg.text)
    end)

    it("errors on invalid text type", function()
      local reg = Register.new("a", "char")
      assert.has_error(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        reg:add(123)
      end, "Invalid text type: number")

      assert.has_error(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        reg:add(nil)
      end, "Invalid text type: nil")

      assert.has_error(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        reg:add(true)
      end, "Invalid text type: boolean")
    end)
  end)

  describe("save", function()
    it("saves text to vim register with char type", function()
      local reg = Register.new("a", "char")
      reg:add("hello")
      reg:add("world")

      reg:save()

      local content = vim.fn.getreg("a")
      assert.equals("hello\nworld", content)

      -- Should clear internal text after saving
      assert.same({}, reg.text)
    end)

    it("saves text with line type", function()
      local reg = Register.new("a", "line")
      reg:add("line1")
      reg:add("line2")

      reg:save()

      local content = vim.fn.getreg("a")
      -- Line-wise registers include a trailing newline
      assert.equals("line1\nline2\n", content)

      -- Check that it was saved as line type
      local reg_type = vim.fn.getregtype("a")
      assert.equals("V", reg_type) -- V indicates line-wise
    end)

    it("saves text with block type", function()
      local reg = Register.new("a", "block")
      reg:add("block1")
      reg:add("block2")

      reg:save()

      local content = vim.fn.getreg("a")
      assert.equals("block1\nblock2", content)

      -- Check that it was saved as block type
      local reg_type = vim.fn.getregtype("a")
      assert.matches("^.", reg_type) -- Block type starts with Ctrl-V (represented as a number)
    end)

    it("concatenates multiline content correctly", function()
      local reg = Register.new("a", "char")
      reg:add({ "first line", "second line" })
      reg:add("third line")

      reg:save()

      local content = vim.fn.getreg("a")
      assert.equals("first line\nsecond line\nthird line", content)
    end)

    it("can save to different register names", function()
      local reg = Register.new("a", "char")
      local reg_b = Register.new("b", "char")

      reg:add("content a")
      reg_b:add("content b")

      reg:save()
      reg_b:save()

      assert.equals("content a", vim.fn.getreg("a"))
      assert.equals("content b", vim.fn.getreg("b"))
    end)

    it("can save multiple times after adding more content", function()
      local reg = Register.new("a", "char")
      reg:add("first")
      reg:save()

      assert.equals("first", vim.fn.getreg("a"))
      assert.same({}, reg.text)

      reg:add("second")
      reg:save()

      -- Should overwrite previous content
      assert.equals("second", vim.fn.getreg("a"))
    end)

    it("handles special characters in content", function()
      local reg = Register.new("a", "char")
      reg:add("hello\tworld")
      reg:add("line with\nembedded newline")

      reg:save()

      local content = vim.fn.getreg("a")
      assert.equals("hello\tworld\nline with\nembedded newline", content)
    end)

    it("works with default register", function()
      local reg = Register.new('"', "char")

      reg:add("default register content")
      reg:save()

      local content = vim.fn.getreg('"')
      assert.equals("default register content", content)
    end)

    it("preserves existing register content when not saving", function()
      vim.fn.setreg("a", "existing content")

      local reg = Register.new("a", "char")
      reg:add("new content")
      -- Don't save

      local content = vim.fn.getreg("a")
      assert.equals("existing content", content)
    end)

    it("accumulates content before saving", function()
      local reg = Register.new("a", "char")

      reg:add("part1")
      reg:add("part2")
      reg:add("part3")

      -- Register should still be empty until we save
      assert.equals("", vim.fn.getreg("a"))

      reg:save()

      assert.equals("part1\npart2\npart3", vim.fn.getreg("a"))
    end)

    it("handles very long content", function()
      local reg = Register.new("a", "char")
      local long_content = string.rep("a", 10000)

      reg:add(long_content)
      reg:save()

      local content = vim.fn.getreg("a")
      assert.equals(long_content, content)
    end)

    it("handles unicode content", function()
      local reg = Register.new("a", "char")

      reg:add("Hello 世界")
      reg:add("🚀 emoji test")

      reg:save()

      local content = vim.fn.getreg("a")
      assert.equals("Hello 世界\n🚀 emoji test", content)
    end)

    it("handles content with only newlines", function()
      local reg = Register.new("a", "char")

      reg:add("\n\n\n")
      reg:save()

      local content = vim.fn.getreg("a")
      assert.equals("\n\n\n", content)
    end)

    it("handles mixed table and string with complex structure", function()
      local reg = Register.new("a", "char")

      reg:add({ "", "non-empty" })
      reg:add("")
      reg:add({ "another", "", "line" })

      reg:save()

      local content = vim.fn.getreg("a")
      assert.equals("\nnon-empty\n\nanother\n\nline", content)
    end)

    it("properly sets vim register type for line", function()
      local reg = Register.new("a", "line")
      reg:add("line content")
      reg:save()

      local reg_type = vim.fn.getregtype("a")
      assert.equals("V", reg_type) -- line-wise
    end)

    it("properly sets vim register type for block", function()
      local reg = Register.new("a", "block")
      reg:add("block content")
      reg:save()

      local reg_type = vim.fn.getregtype("a")
      -- Block type is more complex, just check it's not char or line
      assert.is_not.equals("v", reg_type)
      assert.is_not.equals("V", reg_type)
    end)
  end)
end)
