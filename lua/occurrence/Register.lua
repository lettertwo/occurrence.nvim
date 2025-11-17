local log = require("occurrence.log")

---@module 'occurrence.Register'
local register = {}

---@class occurrence.Register
---@field register string The register to use for yanking or deleting text.
---@field type string The type of register, e.g., "char", "line", or "block".
---@field text string[] The text to be saved in the register.
local Register = {}

---@param register_name? string The register to use for yanking or deleting text.
---@param register_type? string The type of register, e.g., "char", "line", or "block".
---@return occurrence.Register
function register.new(register_name, register_type)
  register_name = register_name or vim.v.register
  local ok, text = pcall(vim.fn.getreg, register_name)
  if not ok or not text or text == "" then
    text = {}
  end

  if type(text) == "string" then
    -- Split into lines for distribution
    text = vim.split(text, "\n", { plain = true })
  end

  return setmetatable({
    register = register_name,
    type = register_type or "char", -- default to char motion
    text = text,
  }, { __index = Register })
end

function Register:clear()
  self.text = {}
end

---@param text string | string[] The text to add to the register.
function Register:add(text)
  if type(text) == "string" then
    table.insert(self.text, text)
  elseif type(text) == "table" then
    for _, line in ipairs(text) do
      table.insert(self.text, line)
    end
  else
    error("Invalid text type: " .. type(text))
  end
end

function Register:save()
  if #self.text > 0 then
    local content = table.concat(self.text, "\n")
    vim.fn.setreg(self.register, content, self.type == "line" and "l" or self.type == "block" and "b" or "c")
    self.text = {} -- Clear the text after saving
    log.debug("Saved text to register", self.register)
  else
    log.debug("No text to save to register", self.register)
  end
end

return register
