local log = require("occurrence.log")

---@class OccurrenceRegister
---@field protected register string The register to use for yanking or deleting text.
---@field protected type string The type of register, e.g., "char", "line", or "block".
---@field protected text string[] The text to be saved in the register.
local Register = {}

---@param register? string The register to use for yanking or deleting text.
---@param type? string The type of register, e.g., "char", "line", or "block".
function Register.new(register, type)
  local self = setmetatable({}, { __index = Register })
  self.register = register or vim.v.register
  self.type = type or "char" -- default to char motion
  self.text = {}
  return self
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
    log.debug("Saved to register", self.register, ":", content)
  else
    log.debug("No text to save to register", self.register)
  end
end

return Register
