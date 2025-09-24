---@param buffer? integer
---@param validate? boolean
local function resolve_buffer(buffer, validate)
  local resolved = buffer
  if resolved == nil or resolved == 0 then
    resolved = vim.api.nvim_get_current_buf()
  end
  if validate then
    assert(vim.api.nvim_buf_is_valid(resolved), "Invalid buffer: " .. tostring(buffer or resolved))
  end
  return resolved
end

return resolve_buffer
