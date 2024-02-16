local assert = require("luassert")
local util = require("tests.util")
local Occurrence = require("occurrence.Occurrence")
local Range = require("occurrence.Range")

local NS = vim.api.nvim_create_namespace("Occurrence")

describe("Occurrence", function()
  it("Finds matches", function()
    local bufnr = util.buffer("foo")

    local foo = Occurrence:new(bufnr, "foo", {})
    assert.is_true(foo:has_matches())

    local bar = Occurrence:new(bufnr, "bar", {})
    assert.is_false(bar:has_matches())
  end)

  it("iterates over matches", function()
    local bufnr = util.buffer("foo bar foo")

    local foo = Occurrence:new(bufnr, "foo", {})
    local matches = {}
    for match in foo:matches() do
      table.insert(matches, tostring(match))
    end

    assert.same({
      "Range(start: Location(0, 0), stop: Location(0, 3))",
      "Range(start: Location(0, 8), stop: Location(0, 11))",
    }, matches)
  end)

  it("iterates over matches with a custom range", function()
    local bufnr = util.buffer("foo bar foo")

    local foo = Occurrence:new(bufnr, "foo", {})
    local matches = {}
    for match in foo:matches(Range:deserialize("0:0::0:4")) do
      table.insert(matches, tostring(match))
    end

    assert.same({
      "Range(start: Location(0, 0), stop: Location(0, 3))",
    }, matches)

    matches = {}
    for match in foo:matches(Range:deserialize("0:4::1:0")) do
      table.insert(matches, tostring(match))
    end

    assert.same({
      "Range(start: Location(0, 8), stop: Location(0, 11))",
    }, matches)
  end)

  it("marks matches", function()
    local bufnr = util.buffer("foo bar foo")

    local foo = Occurrence:new(bufnr, "foo", {})
    foo:mark(Range:deserialize("0:0::1:0"))

    local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})

    assert.same({
      { 1, 0, 0 },
      { 2, 0, 8 },
    }, marks)
  end)

  it("marks matches within a range", function()
    local bufnr = util.buffer("foo bar foo")

    local foo = Occurrence:new(bufnr, "foo", {})
    foo:mark(Range:deserialize("0:0::0:4"))

    local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})

    assert.same({ { 1, 0, 0 } }, marks)
  end)

  it("iterates over marks", function()
    local bufnr = util.buffer("foo bar foo")

    local foo = Occurrence:new(bufnr, "foo", {})
    foo:mark(Range:deserialize("0:0::1:0"))

    local marked = {}
    for mark in foo:marks() do
      table.insert(marked, tostring(mark))
    end

    assert.equal(#marked, 2)

    assert.same({
      "Range(start: Location(0, 0), stop: Location(0, 3))",
      "Range(start: Location(0, 8), stop: Location(0, 11))",
    }, marked)
  end)

  it("iterates over marks within a range", function()
    local bufnr = util.buffer("foo bar foo")

    local foo = Occurrence:new(bufnr, "foo", {})
    foo:mark(Range:deserialize("0:0::1:0"))

    local marked = {}
    for mark in foo:marks({ range = Range:deserialize("0:0::0:4") }) do
      table.insert(marked, tostring(mark))
    end

    assert.same({
      "Range(start: Location(0, 0), stop: Location(0, 3))",
    }, marked)
  end)
end)
