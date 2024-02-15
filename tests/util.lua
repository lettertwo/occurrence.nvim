local M = {}

local DEFAULT_CONTENT = {
  "this is default content that has been defaultly contented",
  "to repeatedly include content by default. The content features",
  "some default occurrences of content by default.",
}
local DEFAULT_FILETYPE = "text"

-- Creates a new buffer with content for testing.
---@param content? string | string[]
---@param filetype? string
---@return number buffer
function M.buffer(content, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", filetype or DEFAULT_FILETYPE, { buf = buf })
  vim.api.nvim_command("buffer " .. buf)
  if type(content) == "string" then
    content = vim.split(content, "\n")
  else
    content = content or DEFAULT_CONTENT
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, true, content)
  return buf
end

return M
