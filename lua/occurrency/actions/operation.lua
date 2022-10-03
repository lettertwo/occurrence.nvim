local Action = require("occurrency.Action")

local M = {}

function M.run()
  print("operation.run")
end

return Action:map(M)
