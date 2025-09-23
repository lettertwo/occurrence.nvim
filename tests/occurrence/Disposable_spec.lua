local Disposable = require("occurrence.Disposable")
local assert = require("luassert")
local spy = require("luassert.spy")

describe("Disposable", function()
  describe("create_disposable", function()
    it("creates a new Disposable", function()
      local d = Disposable.new()
      assert.is_not_nil(d)
      assert.is_function(d.dispose)
      assert.is_function(d.add)
      assert.is_function(d.is_disposed)
      assert.is_false(d:is_disposed())
    end)

    it("accepts an optional dispose function", function()
      local called = false
      local d = Disposable.new(function()
        called = true
      end)
      assert.is_false(called)
      d:dispose()
      assert.is_true(called)
    end)
  end)

  describe(":dispose", function()
    it("calls the dispose functions in reverse order", function()
      local call_order = {}
      local d = Disposable.new()
      d:add(function()
        table.insert(call_order, 1)
      end)
      d:add(function()
        table.insert(call_order, 2)
      end)
      d:add(function()
        table.insert(call_order, 3)
      end)

      d:dispose()
      assert.are.same({ 3, 2, 1 }, call_order)
    end)

    it("disposes nested Disposables", function()
      local nested_disposed = false
      local nested = Disposable.new(function()
        nested_disposed = true
      end)

      local d = Disposable.new()
      d:add(nested)

      assert.is_false(nested_disposed)
      d:dispose()
      assert.is_true(nested_disposed)
    end)

    it("is idempotent", function()
      local call_count = 0
      local d = Disposable.new(function()
        call_count = call_count + 1
      end)

      d:dispose()
      d:dispose()
      assert.are.equal(1, call_count)
    end)

    it("clears the dispose stack after disposing", function()
      local d = Disposable.new(function() end)
      d:dispose()
      ---@diagnostic disable-next-line: invisible
      assert.are.equal(0, #d._dispose_stack)
    end)

    it("marks itself as disposed", function()
      local d = Disposable.new(function() end)
      assert.is_false(d:is_disposed())
      d:dispose()
      assert.is_true(d:is_disposed())
    end)
  end)

  describe(":add", function()
    it("adds a dispose function to the stack", function()
      local d = Disposable.new()
      local cb1 = function() end
      local cb2 = function() end
      d:add(cb1)
      d:add(cb2)

      ---@diagnostic disable-next-line: invisible
      assert.is_same({ cb1, cb2 }, d._dispose_stack)

      d:dispose()
      ---@diagnostic disable-next-line: invisible
      assert.is_same({}, d._dispose_stack)
    end)

    it("adds a nested Disposable to the stack", function()
      local nested_disposed = false
      local nested = Disposable.new(function()
        nested_disposed = true
      end)

      local d = Disposable.new()
      d:add(nested)

      ---@diagnostic disable-next-line: invisible
      assert.is_same({ nested }, d._dispose_stack)
      assert.is_false(nested_disposed)
      d:dispose()
      ---@diagnostic disable-next-line: invisible
      assert.is_same({}, d._dispose_stack)
      assert.is_true(nested_disposed)
    end)

    it("throws an error if adding to a disposed Disposable", function()
      local d = Disposable.new()
      d:dispose()
      assert.has_error(function()
        d:add(function() end)
      end, "Cannot add to a disposed Disposable")
    end)

    it("throws an error if argument is not a function or Disposable", function()
      local d = Disposable.new()
      assert.has_error(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        d:add(42)
      end, "Argument must be a Disposable or function")
      assert.has_error(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        d:add("not a function")
      end, "Argument must be a Disposable or function")
      assert.has_error(function()
        ---@diagnostic disable-next-line: missing-fields
        d:add({})
      end, "Argument must be a Disposable or function")
    end)

    it("returns self for chaining", function()
      local d = Disposable.new()
      local result = d:add(function() end)
      assert.are.equal(d, result)
    end)
  end)

  describe(":is_disposed", function()
    it("returns true if disposed, false otherwise", function()
      local d = Disposable.new()
      assert.is_false(d:is_disposed())
      d:dispose()
      assert.is_true(d:is_disposed())
    end)
  end)
end)
