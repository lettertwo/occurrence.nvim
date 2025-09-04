local assert = require("luassert")
local util = require("tests.util")

describe("tests.util.buffer", function()
  local bufnr

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    bufnr = nil
  end)

  it("creates a new buffer", function()
    bufnr = util.buffer()
    assert.is_number(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    assert.equal(#lines, 3)
    assert.truthy(lines[1]:find("default content"))
    assert.equal(vim.api.nvim_get_option_value("filetype", { buf = bufnr }), "text")
  end)

  it("creates a new buffer with content", function()
    bufnr = util.buffer("hello world")
    assert.is_number(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    assert.equal(#lines, 1)
    assert.equal(lines[1], "hello world")
    assert.equal(vim.api.nvim_get_option_value("filetype", { buf = bufnr }), "text")
  end)

  it("creates a new buffer with content and filetype", function()
    bufnr = util.buffer('print("hello world")', "lua")
    assert.is_number(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    assert.equal(#lines, 1)
    assert.truthy(lines[1]:find("hello world"))
    assert.equal(vim.api.nvim_get_option_value("filetype", { buf = bufnr }), "lua")
  end)
end)
