local assert = require("luassert")
local spy = require("luassert.spy")
local match = require("luassert.match")
local Action = require("occurrence.Action")

describe("action", function()
  describe(".is_action", function()
    it("returns true for an action", function()
      local action = Action.new(function() end)
      assert.is_true(Action.is_action(action))
    end)

    it("returns true for an occurrence action", function()
      local action = Action.new(function() end)
      ---@diagnostic disable-next-line: missing-fields
      assert.is_true(Action.is_action(action:with({})))
    end)

    it("returns false for a non-action", function()
      assert.is_false(Action.is_action({}))
      assert.is_false(Action.is_action(nil))
    end)
  end)

  describe(".new", function()
    it("errors without a callable callback", function()
      assert.error(function()
        Action.new() ---@diagnostic disable-line: missing-parameter
      end, "Action must have a callback")

      assert.error(function()
        Action.new({}) ---@diagnostic disable-line: missing-fields
      end, "callback must be callable")
    end)

    it("accepts a function callback", function()
      local action = Action.new(function() end)
      assert.is_table(action)
      assert.is_true(action:is_action())
    end)

    it("accepts a callable callback", function()
      local cb = {}
      setmetatable(cb, { __call = function() end })
      local action = Action.new(cb)
      assert.is_table(action)
      assert.is_true(action:is_action())
    end)

    it("accepts another action", function()
      local action = Action.new(function() end)
      local action2 = Action.new(action)
      assert.is_table(action2)
      assert.is_true(action2:is_action())
    end)

    it("extends an instance", function()
      local action = Action.new(function() end)
      local subaction = Action.new(action)
      assert.is_table(subaction)
      assert.is_true(subaction:is_action())
    end)
  end)
end)

describe("Action", function()
  describe(":is_action", function()
    it("returns true for an action instance", function()
      local action = Action.new(function() end)
      assert.is_true(action:is_action())
    end)

    it("returns true for an occurrence action instance", function()
      local action = Action.new(function() end)
      ---@diagnostic disable-next-line: missing-fields
      assert.is_true(action:with({}):is_action())
    end)
  end)

  describe(":with", function()
    it("binds an action to an occurrence", function()
      local cb = spy.new(function() end)
      local action = Action.new(cb)
      local occurrence = {}
      action:with(occurrence)()
      assert.spy(cb).was_called_with(match.is_ref(occurrence))
    end)

    it("rebinds when chained", function()
      local cb = spy.new(function() end)
      local action = Action.new(cb)
      local occurrence1 = {}
      local occurrence2 = {}
      action:with(occurrence1):with(occurrence2)()
      assert.spy(cb).was_not_called_with(match.is_ref(occurrence1))
      assert.spy(cb).was_called_with(match.is_ref(occurrence2))
    end)

    it("applies additional arguments", function()
      local cb = spy.new(function() end)
      local occurrence = {}
      local a = Action.new(cb):with(occurrence)
      a(1, 2, 3)
      assert.spy(cb).was_called_with(match.is_ref(occurrence), 1, 2, 3)
    end)
  end)

  describe(":bind", function()
    it("binds an action to additional arguments", function()
      local cb = spy.new(function() end)
      local action = Action.new(cb)
      local occurrence = {}
      action:bind(1, 2, 3)(occurrence)
      assert.spy(cb).was_called_with(match.is_ref(occurrence), 1, 2, 3)
    end)

    it("can be chained", function()
      local cb = spy.new(function() end)
      local action = Action.new(cb)
      local occurrence = {}
      action:bind(1, 2):bind(3)(occurrence)
      assert.spy(cb).was_called_with(match.is_ref(occurrence), 1, 2, 3)
    end)

    it("appends additional call arguments", function()
      local cb = spy.new(function() end)
      local action = Action.new(cb)
      local occurrence = {}
      action:bind(1, 2):bind(3)(occurrence, 4, 5)
      assert.spy(cb).was_called_with(match.is_ref(occurrence), 1, 2, 3, 4, 5)
    end)

    it("binds an occurrence action to additional arguments", function()
      local cb = spy.new(function() end)
      local occurrence = {}
      local action = Action.new(cb):with(occurrence):bind(1, 2, 3)
      action()
      assert.spy(cb).was_called_with(match.is_ref(occurrence), 1, 2, 3)
    end)

    it("can chain bindings for an occurrence action", function()
      local cb = spy.new(function() end)
      local occurrence = {}
      local action = Action.new(cb):with(occurrence):bind(1):bind(2)
      action(3)
      assert.spy(cb).was_called_with(match.is_ref(occurrence), 1, 2, 3)
    end)

    it("can be converted to an occurrence action", function()
      local cb = spy.new(function() end)
      local occurrence = {}
      local action = Action.new(cb):bind(1, 2, 3):with(occurrence)
      action()
      assert.spy(cb).was_called_with(match.is_ref(occurrence), 1, 2, 3)
    end)
  end)

  describe(":add", function()
    it("errors if the other operand is not callable", function()
      assert.error(function()
        return Action.new(function() end) + {}
      end, "When combining actions, the other must be a callable or action")
    end)

    it("combines an action with a callback", function()
      local occurrence = {}
      local action = Action.new(function()
        return 0
      end) + function(o, r)
        return o, r, 1
      end
      local results = { action(occurrence) }
      assert.equal(results[1], occurrence)
      assert.same(results, { occurrence, 0, 1 })
    end)

    it("combines an action with a callable", function()
      local occurrence = {}
      local cb = {}
      setmetatable(cb, {
        __call = function(_, o, r)
          return o, r, 1
        end,
      })
      local action = Action.new(function()
        return 0
      end) + cb
      local results = { action(occurrence) }
      assert.equal(results[1], occurrence)
      assert.same(results, { occurrence, 0, 1 })
    end)

    it("combines actions", function()
      local cb1 = spy.new(function()
        return 0
      end)
      local cb2 = spy.new(function()
        return 1
      end)
      local action = Action.new(cb1) + Action.new(cb2)
      local occurrence = {}
      assert.equal(action(occurrence), 1)
      assert.spy(cb1).was_called_with(match.is_ref(occurrence))
      assert.spy(cb2).was_called_with(match.is_ref(occurrence), 0)
    end)

    it("combines an action with an occurrence action", function()
      local cb1 = spy.new(function()
        return 0
      end)
      local cb2 = spy.new(function()
        return 1
      end)
      local occurrence = {}
      local action = Action.new(cb1) + Action.new(cb2):with(occurrence)
      assert.equal(action(), 1)
      assert.spy(cb1).was_not_called_with(match.is_ref(occurrence))
      assert.spy(cb2).was_called_with(match.is_ref(occurrence), 0)
    end)

    it("combines an occurrence action with an action", function()
      local cb1 = spy.new(function()
        return 0
      end)
      local cb2 = spy.new(function()
        return 1
      end)
      local occurrence = {}
      local action = Action.new(cb1):with(occurrence) + Action.new(cb2)
      assert.equal(action(), 1)
      assert.spy(cb1).was_called_with(match.is_ref(occurrence))
      assert.spy(cb2).was_called_with(match.is_ref(occurrence), 0)
    end)

    it("combines occurrence actions", function()
      local cb1 = spy.new(function()
        return 0
      end)
      local cb2 = spy.new(function()
        return 1
      end)
      local o1 = {}
      local o2 = {}
      local action = Action.new(cb1):with(o1) + Action.new(cb2):with(o2)
      assert.equal(1, action())
      assert.spy(cb1).was_called_with(match.is_ref(o1))
      assert.spy(cb2).was_called_with(match.is_ref(o2), 0)
    end)

    it("combines a bound action with a callback", function()
      local occurrence = {}
      local action = Action.new(function(_, a)
        return a
      end):bind(0) + function(o, r)
        return o, r, 1
      end
      local results = { action(occurrence) }
      assert.equal(results[1], occurrence)
      assert.same(results, { occurrence, 0, 1 })
    end)

    it("combines a bound action with a callable", function()
      local occurrence = {}
      local cb = {}
      setmetatable(cb, {
        __call = function(_, o, r)
          return o, r, 1
        end,
      })
      local action = Action.new(function(_, a)
        return a
      end):bind(0) + cb
      local results = { action(occurrence) }
      assert.equal(results[1], occurrence)
      assert.same(results, { occurrence, 0, 1 })
    end)

    it("combines a bound action with an action", function()
      local cb1 = spy.new(function(_, a)
        return a
      end)
      local cb2 = spy.new(function()
        return 1
      end)
      local occurrence = {}

      local action = Action.new(cb1):bind(0) + Action.new(cb2)
      assert.equal(action(occurrence), 1)
      assert.spy(cb1).was_called_with(match.is_ref(occurrence), 0)
      assert.spy(cb2).was_called_with(match.is_ref(occurrence), 0)
    end)

    it("combines an action with a bound action", function()
      local cb1 = spy.new(function()
        return 0
      end)
      local cb2 = spy.new(function(_, b)
        return b
      end)
      local occurrence = {}

      local action = Action.new(cb1) + Action.new(cb2):bind(1)
      assert.equal(action(occurrence), 1)
      assert.spy(cb1).was_called_with(match.is_ref(occurrence))
      assert.spy(cb2).was_called_with(match.is_ref(occurrence), 1, 0)
    end)

    it("combines bound actions", function()
      local cb1 = spy.new(function(_, a)
        return a
      end)
      local cb2 = spy.new(function(_, b)
        return b
      end)
      local occurrence = {}

      local action = Action.new(cb1):bind(0) + Action.new(cb2):bind(1)
      assert.equal(action(occurrence), 1)
      assert.spy(cb1).was_called_with(match.is_ref(occurrence), 0)
      assert.spy(cb2).was_called_with(match.is_ref(occurrence), 1, 0)
    end)

    it("combines an occurrence action with a bound action", function()
      local cb1 = spy.new(function()
        return 0
      end)
      local cb2 = spy.new(function(_, b)
        return b
      end)
      local occurrence = {}
      local action = Action.new(cb1):with(occurrence) + Action.new(cb2):bind(1)
      assert.equal(action(), 1)
      assert.spy(cb1).was_called_with(match.is_ref(occurrence))
      assert.spy(cb2).was_called_with(match.is_ref(occurrence), 1, 0)
    end)

    it("combines a bound action with an occurrence action", function()
      local cb1 = spy.new(function(_, a)
        return a
      end)
      local cb2 = spy.new(function()
        return 1
      end)
      local o1 = {}
      local o2 = {}
      local action = Action.new(cb1):bind(0) + Action.new(cb2):with(o2)
      assert.equal(action(o1), 1)
      assert.spy(cb1).was_called_with(match.is_ref(o1), 0)
      assert.spy(cb2).was_called_with(match.is_ref(o2), 0)
    end)

    it("combines a bound occurrence action with an action", function()
      local cb1 = spy.new(function(_, a)
        return a
      end)
      local cb2 = spy.new(function()
        return 1
      end)
      local occurrence = {}
      local action = Action.new(cb1):bind(0):with(occurrence) + Action.new(cb2)
      assert.equal(action(), 1)
      assert.spy(cb1).was_called_with(match.is_ref(occurrence), 0)
      assert.spy(cb2).was_called_with(match.is_ref(occurrence), 0)
    end)

    it("combines an action with a bound occurrence action", function()
      local cb1 = spy.new(function()
        return 0
      end)
      local cb2 = spy.new(function(_, b)
        return b
      end)
      local o1 = {}
      local o2 = {}
      local action = Action.new(cb1) + Action.new(cb2):bind(1):with(o2)
      assert.equal(action(o1), 1)
      assert.spy(cb1).was_called_with(match.is_ref(o1))
      assert.spy(cb2).was_called_with(match.is_ref(o2), 1, 0)
    end)

    it("combines bound occurrence actions", function()
      local cb1 = spy.new(function()
        return 5
      end)
      local cb2 = spy.new(function()
        return 6
      end)
      local o1 = {}
      local o2 = {}
      local a1 = Action.new(cb1):with(o1):bind(1)
      local a2 = Action.new(cb2):with(o1):bind(2, 3):with(o2)
      local action = a1 + a2
      assert.equal(action(4), 6)
      assert.spy(cb1).was_called_with(match.is_ref(o1), 1, 4)
      assert.spy(cb2).was_called_with(match.is_ref(o2), 2, 3, 5)
    end)
  end)

  describe(":call", function()
    it("calls the action callback with arguments", function()
      local cb = spy.new(function() end)
      local action = Action.new(cb)
      local occurrence = {}
      action(occurrence)
      assert.spy(cb).was_called_with(match.is_ref(occurrence))
      action(occurrence, 1, 2, 3)
      assert.spy(cb).was_called_with(match.is_ref(occurrence), 1, 2, 3)
    end)

    it("inserts a new occurrence when not provided", function()
      local cb = spy.new(function() end)
      local action = Action.new(cb)
      action()
      assert.spy(cb).was_called_with(match.is_table())
      action(nil)
      assert.spy(cb).was_called_with(match.is_table())
      action(nil, 1, 2, 3)
      assert.spy(cb).was_called_with(match.is_table(), 1, 2, 3)
    end)
  end)
end)
